package com.example.hackathonbank.service;

import com.example.hackathonbank.controller.dto.AccountResponse;
import com.example.hackathonbank.controller.dto.DailySavingsPreviewResponse;
import com.example.hackathonbank.controller.dto.SmartCategoryResponse;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.User;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@Transactional(readOnly = true)
public class AiChatContextBuilder {

    private final UserContextService userContextService;
    private final UserSettingsService userSettingsService;
    private final AccountService accountService;
    private final TransactionService transactionService;
    private final ScheduledPaymentService scheduledPaymentService;
    private final DailySavingsService dailySavingsService;
    private final SmartCategoryService smartCategoryService;
    private final IncomeCalendarService incomeCalendarService;
    private final SpendProfileService spendProfileService;
    private final ForecastService forecastService;
    private final ObjectMapper objectMapper;

    public AiChatContextBuilder(UserContextService userContextService,
                                UserSettingsService userSettingsService,
                                AccountService accountService,
                                TransactionService transactionService,
                                ScheduledPaymentService scheduledPaymentService,
                                DailySavingsService dailySavingsService,
                                SmartCategoryService smartCategoryService,
                                IncomeCalendarService incomeCalendarService,
                                SpendProfileService spendProfileService,
                                ForecastService forecastService,
                                ObjectMapper objectMapper) {
        this.userContextService = userContextService;
        this.userSettingsService = userSettingsService;
        this.accountService = accountService;
        this.transactionService = transactionService;
        this.scheduledPaymentService = scheduledPaymentService;
        this.dailySavingsService = dailySavingsService;
        this.smartCategoryService = smartCategoryService;
        this.incomeCalendarService = incomeCalendarService;
        this.spendProfileService = spendProfileService;
        this.forecastService = forecastService;
        this.objectMapper = objectMapper;
    }

    public String buildContextJson() {
        return buildContextJson(userContextService.getCurrentUser().getId());
    }

    public String buildContextJson(Long userId) {
        try {
            return objectMapper.writeValueAsString(buildContext(userId));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Не удалось собрать контекст AI-чата.", exception);
        }
    }

    public ObjectNode buildContext(Long userId) {
        User user = userContextService.getCurrentUser();
        if (!user.getId().equals(userId)) {
            throw new IllegalArgumentException("AI-чат недоступен для другого пользователя.");
        }

        LocalDate currentDate = userSettingsService.currentDate();
        LocalDateTime from = currentDate.minusMonths(3).atStartOfDay();

        List<Transaction> transactions = transactionService.getTransactionsForCurrentUser().stream()
                .filter(transaction -> !transaction.getOccurredAt().isBefore(from))
                .sorted((left, right) -> left.getOccurredAt().compareTo(right.getOccurredAt()))
                .toList();
        List<ScheduledPayment> scheduledPayments = scheduledPaymentService.getPendingPayments();
        DailySavingsPreviewResponse dailySafeToSave = dailySavingsService.previewForCurrentUser();
        List<AccountResponse> accounts = accountService.getAccounts();
        List<SmartCategoryResponse> smartCategories = smartCategoryService.getCategories();

        BigDecimal totalIncome = transactions.stream()
                .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                .map(Transaction::getAmount)
                .filter(amount -> amount.compareTo(BigDecimal.ZERO) > 0)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalExpense = transactions.stream()
                .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                .map(Transaction::getAmount)
                .filter(amount -> amount.compareTo(BigDecimal.ZERO) < 0)
                .map(BigDecimal::abs)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        LinkedHashMap<String, Object> context = new LinkedHashMap<>();
        context.put("userId", user.getId());
        context.put("userName", user.getFullName());
        context.put("user", Map.of(
                "id", user.getId(),
                "fullName", user.getFullName(),
                "currentDate", currentDate.toString()
        ));
        context.put("accounts", accounts.stream()
                .map(account -> Map.of(
                        "id", account.id(),
                        "name", account.name(),
                        "type", account.type(),
                        "balance", account.balance(),
                        "currency", account.currency()
                ))
                .toList());
        context.put("balances", balancesContext(accounts));
        context.put("summaryLast90Days", Map.of(
                "income", totalIncome,
                "expense", totalExpense,
                "net", totalIncome.subtract(totalExpense)
        ));
        context.put("transactionsLast3Months", transactions.stream()
                .map(this::toTransactionContext)
                .toList());
        context.put("scheduledPayments", scheduledPayments.stream()
                .map(this::toScheduledPaymentContext)
                .toList());
        context.put("dailySafeToSave", Map.of(
                "enabled", dailySafeToSave.enabled(),
                "suggestedAmount", dailySafeToSave.suggestedAmount(),
                "safeBalance", dailySafeToSave.safeBalance(),
                "currentBalance", dailySafeToSave.currentBalance(),
                "requiredPayments", dailySafeToSave.requiredPayments(),
                "lifeBuffer", dailySafeToSave.lifeBuffer(),
                "nextIncomeDate", dailySafeToSave.nextIncomeDate(),
                "daysToNextIncome", dailySafeToSave.daysToNextIncome(),
                "status", dailySafeToSave.status()
        ));
        context.put("smartCategories", smartCategories.stream()
                .map(category -> Map.of(
                        "id", category.id(),
                        "name", category.name(),
                        "plannedMonthly", category.plannedMonthly(),
                        "remaining", category.remaining(),
                        "favorite", category.isFavorite()
                ))
                .toList());

        context.put("derivedFeatures", buildDerivedFeatures(user.getId(), currentDate, transactions, accounts));

        return objectMapper.valueToTree(context);
    }

    private Map<String, Object> buildDerivedFeatures(Long userId,
                                                      LocalDate currentDate,
                                                      List<Transaction> transactions,
                                                      List<AccountResponse> accounts) {
        IncomeCalendarService.IncomeCalendar calendar = incomeCalendarService.buildCalendar(userId, currentDate);
        SpendProfileService.SpendProfile spendProfile = spendProfileService.buildProfile(userId, currentDate);

        LinkedHashMap<String, Object> features = new LinkedHashMap<>();

        features.put("incomeCalendar", calendar.clusters().stream()
                .map(cluster -> Map.of(
                        "type", cluster.type().name(),
                        "dayOfMonth", cluster.dayOfMonth(),
                        "averageAmount", cluster.averageAmount(),
                        "occurrences", cluster.occurrences(),
                        "confidence", cluster.confidence()
                ))
                .toList());
        features.put("nextIncomeDate", calendar.nextExpectedDate().toString());
        features.put("incomeConfidence", calendar.confidencePercent());

        features.put("burnRate", spendProfile.dailyTotal());
        features.put("burnRateEssential", spendProfile.dailyEssentialSpend());
        features.put("burnRateDiscretionary", spendProfile.dailyDiscretionarySpend());
        features.put("burnRateVolatility", spendProfile.volatility());

        LinkedHashMap<String, Object> weekdayProfile = new LinkedHashMap<>();
        spendProfile.weekdayMultipliers().forEach((day, mult) -> weekdayProfile.put(day.name(), mult));
        features.put("weekdaySpendProfile", weekdayProfile);

        var dashboard = forecastService.buildDashboard(30);
        int daysToNegative = -1;
        for (var point : dashboard.points()) {
            if (point.balance().compareTo(java.math.BigDecimal.ZERO) < 0) {
                daysToNegative = point.dayOffset();
                break;
            }
        }
        features.put("daysToNegativeBalance", daysToNegative);

        AccountResponse mainAccount = accounts.stream()
                .filter(a -> "MAIN".equals(a.type()))
                .findFirst()
                .orElse(null);
        if (mainAccount != null) {
            var requiredPayments = dashboard.scheduledPayments().stream()
                    .map(com.example.hackathonbank.ai.dto.ScheduledPaymentSnapshot::amount)
                    .reduce(java.math.BigDecimal.ZERO, java.math.BigDecimal::add);
            features.put("freeBalance", mainAccount.balance().subtract(requiredPayments));
        }

        LinkedHashMap<String, Long> merchantCounts = new LinkedHashMap<>();
        transactions.stream()
                .filter(t -> t.getAmount().compareTo(java.math.BigDecimal.ZERO) < 0)
                .filter(t -> t.getCounterparty() != null && !t.getCounterparty().isBlank())
                .forEach(t -> merchantCounts.merge(t.getCounterparty(), 1L, Long::sum));
        List<String> topMerchants = merchantCounts.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(5)
                .map(Map.Entry::getKey)
                .toList();
        features.put("recurringMerchants", topMerchants);

        return features;
    }

    private Map<String, Object> balancesContext(List<AccountResponse> accounts) {
        AccountResponse mainAccount = accounts.stream()
                .filter(account -> "MAIN".equals(account.type()))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Основной счет не найден."));
        AccountResponse savingsAccount = accounts.stream()
                .filter(account -> "SAVINGS".equals(account.type()))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Накопительный депозит не найден."));
        return Map.of(
                "main", mainAccount.balance().toPlainString(),
                "savings", savingsAccount.balance().toPlainString(),
                "currency", mainAccount.currency()
        );
    }

    private Map<String, Object> toTransactionContext(Transaction transaction) {
        LinkedHashMap<String, Object> item = new LinkedHashMap<>();
        item.put("id", transaction.getId());
        item.put("accountId", transaction.getAccount().getId());
        item.put("accountName", transaction.getAccount().getName());
        item.put("title", transaction.getTitle());
        item.put("counterparty", transaction.getCounterparty());
        item.put("amount", transaction.getAmount());
        item.put("category", transaction.getCategory());
        item.put("type", transaction.getType().name());
        item.put("status", transaction.getStatus().name());
        item.put("occurredAt", transaction.getOccurredAt());
        if (transaction.getSmartCategory() != null) {
            item.put("smartCategory", Map.of(
                    "id", transaction.getSmartCategory().getId(),
                    "name", transaction.getSmartCategory().getName()
            ));
        }
        return item;
    }

    private Map<String, Object> toScheduledPaymentContext(ScheduledPayment payment) {
        LinkedHashMap<String, Object> item = new LinkedHashMap<>();
        item.put("id", payment.getId());
        item.put("accountId", payment.getAccount().getId());
        item.put("accountName", payment.getAccount().getName());
        item.put("title", payment.getTitle());
        item.put("counterparty", payment.getCounterparty());
        item.put("amount", payment.getAmount());
        item.put("category", payment.getCategory());
        item.put("dueDate", payment.getDueDate());
        item.put("status", payment.getStatus().name());
        item.put("isReminder", payment.isReminder());
        item.put("isScheduled", payment.getStatus() == PaymentStatus.SCHEDULED || payment.getStatus() == PaymentStatus.POSTPONED);
        return item;
    }
}
