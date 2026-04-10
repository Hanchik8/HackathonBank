package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.ai.AiCapabilityService;
import com.example.hackathonbank.controller.dto.DailySavingsPreviewResponse;
import com.example.hackathonbank.controller.dto.DemoSimulateDayResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.model.UserSettings;
import com.example.hackathonbank.repository.AccountRepository;
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
    private static final BigDecimal OVERDRAFT_GUARD = new BigDecimal("100.00");
    private static final BigDecimal SAVE_RATIO = new BigDecimal("0.05");
    private static final BigDecimal GUARDED_RESERVE = new BigDecimal("100.00");
    private static final BigDecimal DISCRETIONARY_BUFFER_FACTOR = new BigDecimal("0.85");
    private static final BigDecimal BASE_BUFFER_MULTIPLIER = new BigDecimal("1.10");

    private final UserContextService userContextService;
    private final UserSettingsRepository userSettingsRepository;
    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;
    private final TransferService transferService;
    private final AiCapabilityService aiCapabilityService;
    private final ChatClient aiChatClient;
    private final AiCallExecutor aiCallExecutor;
    private final ObjectMapper objectMapper;
    private final IncomeCalendarService incomeCalendarService;
    private final CashFlowProjectionService cashFlowProjectionService;

    public DailySavingsService(UserContextService userContextService,
                               UserSettingsRepository userSettingsRepository,
                               AccountRepository accountRepository,
                               TransactionRepository transactionRepository,
                               TransferService transferService,
                               AiCapabilityService aiCapabilityService,
                               ChatClient aiChatClient,
                               AiCallExecutor aiCallExecutor,
                               ObjectMapper objectMapper,
                               IncomeCalendarService incomeCalendarService,
                               CashFlowProjectionService cashFlowProjectionService) {
        this.userContextService = userContextService;
        this.userSettingsRepository = userSettingsRepository;
        this.accountRepository = accountRepository;
        this.transactionRepository = transactionRepository;
        this.transferService = transferService;
        this.aiCapabilityService = aiCapabilityService;
        this.aiChatClient = aiChatClient;
        this.aiCallExecutor = aiCallExecutor;
        this.objectMapper = objectMapper;
        this.incomeCalendarService = incomeCalendarService;
        this.cashFlowProjectionService = cashFlowProjectionService;
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
            return new DailySavingsExecution(BigDecimal.ZERO, false, "Автонакопление Safe-to-Save выключено.");
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

        if (balances.main().getBalance().compareTo(MINIMUM_MAIN_BALANCE) < 0) {
            return blockedCalculation(
                    settings.isAutoDailySaveEnabled(),
                    currentDate,
                    currentDate.plusDays(14),
                    balances.main().getBalance(),
                    "Баланс основного счета ниже защитного порога 1000 KGS."
            );
        }

        IncomeCalendarService.IncomeCalendar incomeCalendar = incomeCalendarService.buildCalendar(user.getId(), currentDate);
        LocalDate incomeHorizonEnd = incomeCalendar.rangeEnd().isAfter(currentDate)
                ? incomeCalendar.rangeEnd()
                : incomeCalendar.nextExpectedDate();
        int daysToNextIncome = Math.max(0, (int) ChronoUnit.DAYS.between(currentDate, incomeCalendar.nextExpectedDate()));

        CashFlowProjectionService.CashFlowProjection projection = cashFlowProjectionService.buildProjection(
                user.getId(),
                currentDate,
                incomeHorizonEnd,
                BigDecimal.ZERO
        );

        BigDecimal essentialBuffer = projection.days().stream()
                .skip(1)
                .map(CashFlowProjectionService.ProjectedCashFlowDay::essentialSpend)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal discretionaryBuffer = projection.days().stream()
                .skip(1)
                .map(CashFlowProjectionService.ProjectedCashFlowDay::discretionarySpend)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal behaviorAdjustedSpend = essentialBuffer.add(
                discretionaryBuffer.multiply(DISCRETIONARY_BUFFER_FACTOR).setScale(2, RoundingMode.HALF_UP)
        );
        BigDecimal bufferMultiplier = BASE_BUFFER_MULTIPLIER
                .add(volatilityReserve(projection))
                .add(incomeConfidenceReserve(incomeCalendar));
        BigDecimal lifeBuffer = behaviorAdjustedSpend.multiply(bufferMultiplier).setScale(2, RoundingMode.HALF_UP);
        BigDecimal requiredPayments = projection.confirmedOutflowsTotal()
                .add(projection.inferredOutflowsTotal())
                .setScale(2, RoundingMode.HALF_UP);

        BigDecimal safeBalance = balances.main().getBalance()
                .subtract(requiredPayments)
                .subtract(lifeBuffer)
                .subtract(GUARDED_RESERVE)
                .setScale(2, RoundingMode.HALF_UP);

        BigDecimal suggestedAmount = safeBalance.compareTo(BigDecimal.ZERO) > 0
                ? safeBalance.multiply(SAVE_RATIO).setScale(2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

        boolean overdraftGuardTriggered = false;
        BigDecimal projectedMinimumBalanceAfterTransfer = projection.minimumBalance();
        if (suggestedAmount.compareTo(BigDecimal.ZERO) > 0) {
            CashFlowProjectionService.CashFlowProjection postTransferProjection = cashFlowProjectionService.buildProjection(
                    user.getId(),
                    currentDate,
                    incomeHorizonEnd,
                    suggestedAmount
            );
            projectedMinimumBalanceAfterTransfer = postTransferProjection.minimumBalance();
            if (projectedMinimumBalanceAfterTransfer.compareTo(OVERDRAFT_GUARD) < 0) {
                overdraftGuardTriggered = true;
                suggestedAmount = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
            }
        }

        String status = buildStatus(
                suggestedAmount,
                incomeCalendar,
                projectedMinimumBalanceAfterTransfer,
                overdraftGuardTriggered
        );

        return new DailySavingsCalculation(
                settings.isAutoDailySaveEnabled(),
                currentDate,
                incomeCalendar.nextExpectedDate(),
                daysToNextIncome,
                incomeCalendar.confidencePercent(),
                incomeCalendar.nextIncomeForecast().incomeType().name(),
                incomeCalendar.nextIncomeForecast().expectedAmount(),
                balances.main().getBalance(),
                requiredPayments,
                lifeBuffer,
                safeBalance,
                suggestedAmount,
                GUARDED_RESERVE,
                projectedMinimumBalanceAfterTransfer,
                overdraftGuardTriggered,
                status
        );
    }

    private DailySavingsCalculation blockedCalculation(boolean enabled,
                                                      LocalDate currentDate,
                                                      LocalDate nextIncomeDate,
                                                      BigDecimal currentBalance,
                                                      String status) {
        return new DailySavingsCalculation(
                enabled,
                currentDate,
                nextIncomeDate,
                Math.max(0, (int) ChronoUnit.DAYS.between(currentDate, nextIncomeDate)),
                0,
                IncomeType.OTHER.name(),
                BigDecimal.ZERO,
                currentBalance,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                GUARDED_RESERVE,
                currentBalance,
                false,
                status
        );
    }

    private BigDecimal volatilityReserve(CashFlowProjectionService.CashFlowProjection projection) {
        BigDecimal adjustment = projection.spendProfile().volatility().multiply(new BigDecimal("0.35"));
        BigDecimal cap = new BigDecimal("0.35");
        return adjustment.compareTo(cap) > 0 ? cap : adjustment;
    }

    private BigDecimal incomeConfidenceReserve(IncomeCalendarService.IncomeCalendar incomeCalendar) {
        int confidence = incomeCalendar.confidencePercent();
        if (confidence >= 80) {
            return BigDecimal.ZERO;
        }
        if (confidence >= 60) {
            return new BigDecimal("0.10");
        }
        return new BigDecimal("0.20");
    }

    private String buildStatus(BigDecimal suggestedAmount,
                               IncomeCalendarService.IncomeCalendar incomeCalendar,
                               BigDecimal projectedMinimumBalanceAfterTransfer,
                               boolean overdraftGuardTriggered) {
        if (overdraftGuardTriggered) {
            return "Overdraft Guard заблокировал автонакопление: прогнозный минимум после перевода опустится ниже 100 KGS.";
        }
        if (suggestedAmount.compareTo(BigDecimal.ZERO) <= 0) {
            return "До следующего ожидаемого дохода безопасного свободного остатка для перевода нет.";
        }
        return "Safe-to-Save может перевести %s до окна следующего дохода %s около %s с уверенностью %d%%. Прогнозный минимум после перевода останется на уровне %s."
                .formatted(
                        money(suggestedAmount),
                        incomeTypeLabel(incomeCalendar.nextIncomeForecast().incomeType()),
                        incomeCalendar.nextExpectedDate(),
                        incomeCalendar.confidencePercent(),
                        money(projectedMinimumBalanceAfterTransfer)
                );
    }

    private AccountBalances loadBalances(Long userId) {
        Account main = accountRepository.findByUserIdAndType(userId, AccountType.MAIN)
                .orElseThrow(() -> new IllegalStateException("Main account not found."));
        Account savings = accountRepository.findByUserIdAndType(userId, AccountType.SAVINGS)
                .orElseThrow(() -> new IllegalStateException("Savings account not found."));
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
                calculation.status(),
                calculation.guardReserve(),
                calculation.projectedMinimumBalanceAfterTransfer(),
                calculation.overdraftGuardTriggered(),
                calculation.incomeConfidence(),
                calculation.expectedIncomeAmount(),
                calculation.expectedIncomeType()
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
                        Ты банковский ассистент.
                        Верни только короткое русскоязычное уведомление в 1-2 предложениях без markdown.
                        Сообщение должно звучать как персональное уведомление о безопасном ежедневном переводе в накопления.
                        """)
                .user("""
                        Safe-to-Save перевел %s в накопительный депозит.
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

        return "Safe-to-Save перевел %s в накопительный депозит. Несмотря на недавние траты в категории \"%s\", резерв вырос до %s."
                .formatted(money(savedAmount), topCategory, money(savingsBalance));
    }

    private String money(BigDecimal amount) {
        return amount.setScale(2, RoundingMode.HALF_UP).toPlainString() + " KGS";
    }

    private String incomeTypeLabel(IncomeType incomeType) {
        return switch (incomeType) {
            case SALARY -> "зарплаты";
            case FREELANCE -> "регулярного дохода";
            case TOPUP -> "пополнения";
            case REFUND -> "возврата";
            case OTHER -> "дохода";
        };
    }

    private record DailySavingsCalculation(
            boolean enabled,
            LocalDate currentDate,
            LocalDate nextIncomeDate,
            int daysToNextIncome,
            int incomeConfidence,
            String expectedIncomeType,
            BigDecimal expectedIncomeAmount,
            BigDecimal currentBalance,
            BigDecimal requiredPayments,
            BigDecimal lifeBuffer,
            BigDecimal safeBalance,
            BigDecimal suggestedAmount,
            BigDecimal guardReserve,
            BigDecimal projectedMinimumBalanceAfterTransfer,
            boolean overdraftGuardTriggered,
            String status
    ) {
    }

    public record DailySavingsExecution(BigDecimal savedAmount, boolean executed, String notification) {
    }

    private record AccountBalances(Account main, Account savings) {
    }

    private record NotificationTransaction(String title, String category, BigDecimal amount, String occurredAt) {
    }
}
