package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.ai.AiCapabilityService;
import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.controller.dto.DailySavingsPreviewResponse;
import com.example.hackathonbank.controller.dto.DemoSimulateDayResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.model.UserSettings;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import com.example.hackathonbank.repository.UserSettingsRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class DailySavingsService {

    private static final Logger log = LoggerFactory.getLogger(DailySavingsService.class);
    private static final BigDecimal MINIMUM_MAIN_BALANCE = new BigDecimal("1000.00");
    private static final BigDecimal SAVE_RATIO = new BigDecimal("0.05");
    private static final BigDecimal LIFE_BUFFER_MULTIPLIER = new BigDecimal("1.20");
    private final UserContextService userContextService;
    private final UserSettingsRepository userSettingsRepository;
    private final AccountRepository accountRepository;
    private final ScheduledPaymentRepository scheduledPaymentRepository;
    private final TransactionRepository transactionRepository;
    private final TransferService transferService;
    private final AiCapabilityService aiCapabilityService;
    private final ChatClient aiChatClient;
    private final AiCallExecutor aiCallExecutor;
    private final ObjectMapper objectMapper;
    private final IncomeCalendarService incomeCalendarService;
    private final SpendProfileService spendProfileService;

    public DailySavingsService(UserContextService userContextService,
                               UserSettingsRepository userSettingsRepository,
                               AccountRepository accountRepository,
                               ScheduledPaymentRepository scheduledPaymentRepository,
                               TransactionRepository transactionRepository,
                               TransferService transferService,
                               AiCapabilityService aiCapabilityService,
                               ChatClient aiChatClient,
                               AiCallExecutor aiCallExecutor,
                               ObjectMapper objectMapper,
                               IncomeCalendarService incomeCalendarService,
                               SpendProfileService spendProfileService) {
        this.userContextService = userContextService;
        this.userSettingsRepository = userSettingsRepository;
        this.accountRepository = accountRepository;
        this.scheduledPaymentRepository = scheduledPaymentRepository;
        this.transactionRepository = transactionRepository;
        this.transferService = transferService;
        this.aiCapabilityService = aiCapabilityService;
        this.aiChatClient = aiChatClient;
        this.aiCallExecutor = aiCallExecutor;
        this.objectMapper = objectMapper;
        this.incomeCalendarService = incomeCalendarService;
        this.spendProfileService = spendProfileService;
    }

    @Transactional(readOnly = true)
    public DailySavingsPreviewResponse previewForCurrentUser() {
        User user = userContextService.getCurrentUser();
        return toPreview(calculate(user, getOrCreateSettings(user)));
    }

    @Transactional
    public DemoSimulateDayResponse simulateNextDayForCurrentUser() {
        User user = userContextService.getCurrentUser();
        UserSettings settings = getOrCreateSettings(user);
        LocalDate nextDate = resolveCurrentDate(settings).plusDays(1);
        settings.setAdminModeEnabled(true);
        settings.setEffectiveDate(nextDate);
        userSettingsRepository.save(settings);

        DailySavingsExecution execution = processDailyAutoSave(user, settings);
        AccountBalances balances = loadBalances(user.getId());
        return new DemoSimulateDayResponse(
                nextDate,
                balances.main().getBalance(),
                balances.savings().getBalance(),
                execution.savedAmount(),
                execution.executed(),
                execution.notification()
        );
    }

    @Transactional
    public void runDailyAutoSaveForAllEnabledUsers() {
        for (UserSettings settings : userSettingsRepository.findByAutoDailySaveEnabledTrue()) {
            DailySavingsExecution execution = processDailyAutoSave(settings.getUser(), settings);
            if (execution.executed()) {
                log.info("Safe-to-Save executed for user {}: {}", settings.getUser().getId(), execution.notification());
            }
        }
    }

    private DailySavingsExecution processDailyAutoSave(User user, UserSettings settings) {
        DailySavingsCalculation calculation = calculate(user, settings);
        if (!settings.isAutoDailySaveEnabled()) {
            return new DailySavingsExecution(BigDecimal.ZERO, false, "Safe-to-Save выключен.");
        }
        if (calculation.suggestedAmount().compareTo(BigDecimal.ZERO) <= 0) {
            return new DailySavingsExecution(BigDecimal.ZERO, false, calculation.status());
        }

        ActionExecutionResult transferResult = transferService.autoSaveToSavings(
                user,
                calculation.suggestedAmount(),
                calculation.currentDate()
        );
        String notification = buildPersonalizedNotification(
                user.getId(),
                calculation.currentDate(),
                calculation.suggestedAmount(),
                transferResult.currentBalance(),
                transferResult.savingsBalance()
        );
        return new DailySavingsExecution(calculation.suggestedAmount(), true, notification);
    }

    private DailySavingsCalculation calculate(User user, UserSettings settings) {
        AccountBalances balances = loadBalances(user.getId());
        LocalDate currentDate = resolveCurrentDate(settings);
        IncomeCalendarService.IncomeCalendar incomeCalendar = incomeCalendarService.buildCalendar(user.getId(), currentDate);
        LocalDate nextIncomeDate = incomeCalendar.nextExpectedDate();
        int daysToNextIncome = Math.max(0, (int) ChronoUnit.DAYS.between(currentDate, nextIncomeDate));

        if (balances.main().getBalance().compareTo(MINIMUM_MAIN_BALANCE) < 0) {
            return new DailySavingsCalculation(
                    settings.isAutoDailySaveEnabled(),
                    currentDate,
                    nextIncomeDate,
                    daysToNextIncome,
                    balances.main().getBalance(),
                    BigDecimal.ZERO,
                    BigDecimal.ZERO,
                    BigDecimal.ZERO,
                    BigDecimal.ZERO,
                    "Баланс расчетного счета ниже защитного порога 1000 KGS."
            );
        }

        BigDecimal requiredPayments = scheduledPaymentRepository
                .findByUserIdAndStatusInOrderByDueDateAsc(user.getId(), List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED))
                .stream()
                .filter(payment -> payment.getAccount().getType() == AccountType.MAIN)
                .filter(payment -> !payment.getDueDate().isBefore(currentDate))
                .filter(payment -> !payment.getDueDate().isAfter(nextIncomeDate))
                .map(ScheduledPayment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        SpendProfileService.SpendProfile spendProfile = spendProfileService.buildProfile(user.getId(), currentDate);
        BigDecimal projectedSpendBeforeIncome = projectedSpendUntilIncome(spendProfile, currentDate, daysToNextIncome);
        BigDecimal lifeBufferMultiplier = LIFE_BUFFER_MULTIPLIER.add(volatilityReserve(spendProfile));
        BigDecimal lifeBuffer = projectedSpendBeforeIncome
                .multiply(lifeBufferMultiplier)
                .setScale(2, RoundingMode.HALF_UP);

        BigDecimal safeBalance = balances.main().getBalance()
                .subtract(requiredPayments)
                .subtract(lifeBuffer)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal suggestedAmount = safeBalance.compareTo(BigDecimal.ZERO) > 0
                ? safeBalance.multiply(SAVE_RATIO).setScale(2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

        String status = suggestedAmount.compareTo(BigDecimal.ZERO) > 0
                ? "Алгоритм может безопасно перевести %s сегодня.".formatted(money(suggestedAmount))
                : "Сегодня свободного остатка для Safe-to-Save нет.";

        return new DailySavingsCalculation(
                settings.isAutoDailySaveEnabled(),
                currentDate,
                nextIncomeDate,
                daysToNextIncome,
                balances.main().getBalance(),
                requiredPayments,
                lifeBuffer,
                safeBalance,
                suggestedAmount,
                status
        );
    }

    private AccountBalances loadBalances(Long userId) {
        Account main = accountRepository.findByUserIdAndType(userId, AccountType.MAIN)
                .orElseThrow(() -> new IllegalStateException("Основной счет не найден."));
        Account savings = accountRepository.findByUserIdAndType(userId, AccountType.SAVINGS)
                .orElseThrow(() -> new IllegalStateException("Накопительный депозит не найден."));
        return new AccountBalances(main, savings);
    }

    private UserSettings getOrCreateSettings(User user) {
        return userSettingsRepository.findByUserId(user.getId())
                .orElseGet(() -> userSettingsRepository.save(new UserSettings(user, true, false, false, LocalDate.now())));
    }

    private LocalDate resolveCurrentDate(UserSettings settings) {
        return settings.isAdminModeEnabled() ? settings.getEffectiveDate() : LocalDate.now();
    }

    private DailySavingsPreviewResponse toPreview(DailySavingsCalculation calculation) {
        return new DailySavingsPreviewResponse(
                calculation.enabled(),
                calculation.suggestedAmount(),
                calculation.safeBalance(),
                calculation.currentBalance(),
                calculation.requiredPayments(),
                calculation.lifeBuffer(),
                calculation.nextIncomeDate(),
                calculation.daysToNextIncome(),
                calculation.status()
        );
    }

    private List<Transaction> completedTransactionsInWindow(Long userId,
                                                            LocalDateTime windowStart,
                                                            LocalDateTime windowEnd) {
        return transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                userId,
                TransactionStatus.COMPLETED,
                windowStart,
                windowEnd
        );
    }

    private String buildPersonalizedNotification(Long userId,
                                                 LocalDate currentDate,
                                                 BigDecimal savedAmount,
                                                 BigDecimal mainBalance,
                                                 BigDecimal savingsBalance) {
        List<Transaction> recentTransactions = recentTransactions(userId, currentDate);
        if (aiCapabilityService.isLiveAiEnabled()) {
            try {
                String liveMessage = aiCallExecutor.execute(
                        () -> liveNotification(savedAmount, recentTransactions, mainBalance, savingsBalance)
                );
                if (liveMessage != null && !liveMessage.isBlank()) {
                    return liveMessage.trim();
                }
            } catch (Exception exception) {
                log.warn("Safe-to-Save AI notification failed, using fallback mode: {}", exception.getMessage());
            }
        }
        return fallbackNotification(savedAmount, recentTransactions, savingsBalance);
    }

    private List<Transaction> recentTransactions(Long userId, LocalDate currentDate) {
        return transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                userId,
                TransactionStatus.COMPLETED,
                currentDate.minusDays(2).atStartOfDay(),
                currentDate.atTime(23, 59, 59)
        );
    }

    private String liveNotification(BigDecimal savedAmount,
                                    List<Transaction> recentTransactions,
                                    BigDecimal mainBalance,
                                    BigDecimal savingsBalance) throws JsonProcessingException {
        String payload = objectMapper.writeValueAsString(
                recentTransactions.stream()
                        .map(transaction -> new NotificationTransaction(
                                transaction.getTitle(),
                                transaction.getCategory(),
                                transaction.getAmount(),
                                transaction.getOccurredAt().toString()
                        ))
                        .toList()
        );

        String response = aiChatClient.prompt()
                .system("""
                        Ты банковый ассистент.
                        Верни только короткое русскоязычное уведомление в 1-2 предложениях, без markdown и без списков.
                        Сообщение должно звучать как персональное уведомление о безопасном ежедневном переводе в накопления.
                        """)
                .user("""
                        Safe-to-Save сегодня перевел %s в накопительный депозит.
                        Текущий баланс основного счета: %s.
                        Баланс накопительного депозита: %s.
                        Транзакции пользователя за последние 3 дня в JSON: %s
                        """.formatted(money(savedAmount), money(mainBalance), money(savingsBalance), payload))
                .call()
                .content();
        return response == null ? "" : response.trim();
    }

    private String fallbackNotification(BigDecimal savedAmount,
                                        List<Transaction> recentTransactions,
                                        BigDecimal savingsBalance) {
        String topCategory = recentTransactions.stream()
                .filter(transaction -> transaction.getAmount().compareTo(BigDecimal.ZERO) < 0)
                .collect(java.util.stream.Collectors.groupingBy(
                        Transaction::getCategory,
                        LinkedHashMap::new,
                        java.util.stream.Collectors.reducing(
                                BigDecimal.ZERO,
                                transaction -> transaction.getAmount().abs(),
                                BigDecimal::add
                        )
                ))
                .entrySet().stream()
                .max(Map.Entry.comparingByValue())
                .map(Map.Entry::getKey)
                .orElse("повседневные расходы");

        return "Safe-to-Save перевел %s в накопительный депозит. Несмотря на траты по категории \"%s\", резерв вырос до %s."
                .formatted(money(savedAmount), topCategory, money(savingsBalance));
    }

    private String money(BigDecimal amount) {
        return amount.setScale(2, RoundingMode.HALF_UP).toPlainString() + " KGS";
    }

    private BigDecimal projectedSpendUntilIncome(SpendProfileService.SpendProfile spendProfile,
                                                 LocalDate currentDate,
                                                 int daysToNextIncome) {
        BigDecimal total = BigDecimal.ZERO;
        for (int day = 0; day < daysToNextIncome; day++) {
            total = total.add(spendProfile.projectedSpend(currentDate.plusDays(day).getDayOfWeek()));
        }
        return total.setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal volatilityReserve(SpendProfileService.SpendProfile spendProfile) {
        BigDecimal adjustment = spendProfile.volatility().multiply(new BigDecimal("0.25"));
        BigDecimal cap = new BigDecimal("0.25");
        return adjustment.compareTo(cap) > 0 ? cap : adjustment;
    }

    private record DailySavingsCalculation(
            boolean enabled,
            LocalDate currentDate,
            LocalDate nextIncomeDate,
            int daysToNextIncome,
            BigDecimal currentBalance,
            BigDecimal requiredPayments,
            BigDecimal lifeBuffer,
            BigDecimal safeBalance,
            BigDecimal suggestedAmount,
            String status
    ) {
    }

    public record DailySavingsExecution(
            BigDecimal savedAmount,
            boolean executed,
            String notification
    ) {
    }

    private record AccountBalances(Account main, Account savings) {
    }

    private record NotificationTransaction(
            String title,
            String category,
            BigDecimal amount,
            String occurredAt
    ) {
    }

}
