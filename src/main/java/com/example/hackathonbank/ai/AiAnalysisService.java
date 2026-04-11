package com.example.hackathonbank.ai;

import com.example.hackathonbank.ai.dto.AiAnalyzeResponse;
import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.AiExecuteRequest;
import com.example.hackathonbank.ai.dto.AiExecuteResponse;
import com.example.hackathonbank.ai.dto.BalanceSuggestionResponse;
import com.example.hackathonbank.ai.dto.EnrichmentSummary;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.service.AccountService;
import com.example.hackathonbank.service.ForecastService;
import com.example.hackathonbank.service.ScheduledPaymentService;
import com.example.hackathonbank.service.TransactionService;
import com.example.hackathonbank.service.IncomeCalendarService;
import com.example.hackathonbank.service.UserContextService;
import com.example.hackathonbank.service.UserSettingsService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class AiAnalysisService {

    private static final String INVALID_ACTION_TOKEN_MESSAGE = "Токен действия недействителен или уже истек.";

    private final ForecastService forecastService;
    private final TransactionService transactionService;
    private final ScheduledPaymentService scheduledPaymentService;
    private final TransactionEnrichmentService transactionEnrichmentService;
    private final AccountService accountService;
    private final BankingAgentTools bankingAgentTools;
    private final UserSettingsService userSettingsService;
    private final IncomeCalendarService incomeCalendarService;
    private final UserContextService userContextService;

    public AiAnalysisService(ForecastService forecastService,
                             TransactionService transactionService,
                             ScheduledPaymentService scheduledPaymentService,
                             TransactionEnrichmentService transactionEnrichmentService,
                             AccountService accountService,
                             BankingAgentTools bankingAgentTools,
                             UserSettingsService userSettingsService,
                             IncomeCalendarService incomeCalendarService,
                             UserContextService userContextService) {
        this.forecastService = forecastService;
        this.transactionService = transactionService;
        this.scheduledPaymentService = scheduledPaymentService;
        this.transactionEnrichmentService = transactionEnrichmentService;
        this.accountService = accountService;
        this.bankingAgentTools = bankingAgentTools;
        this.userSettingsService = userSettingsService;
        this.incomeCalendarService = incomeCalendarService;
        this.userContextService = userContextService;
    }

    @Transactional(readOnly = true)
    public AiAnalyzeResponse analyze(int offsetDays) {
        AiDashboardResponse dashboard = forecastService.buildDashboard(offsetDays);
        List<Transaction> transactions = transactionService.getTransactionsForCurrentUser();
        List<ScheduledPayment> pendingPayments = scheduledPaymentService.getPendingPayments();
        EnrichmentSummary enrichmentSummary = transactionEnrichmentService.enrichDeterministic(
                transactions,
                pendingPayments,
                dashboard.minimumProjectedBalance()
        );

        if (dashboard.minimumProjectedBalance().compareTo(BigDecimal.ZERO) >= 0) {
            return new AiAnalyzeResponse(
                    false,
                    normalizeReasoning(enrichmentSummary),
                    null,
                    List.of()
            );
        }

        BigDecimal deficit = dashboard.minimumProjectedBalance().abs();
        List<BalanceSuggestionResponse> suggestions = buildSuggestions(dashboard, deficit);
        LocalDate horizonDate = userSettingsService.currentDate().plusDays(Math.max(0, offsetDays));
        LocalDate firstNegativeDate = firstNegativeDate(dashboard).orElse(horizonDate);
        LocalDate minimumBalanceDate = minimumBalanceDate(dashboard).orElse(firstNegativeDate);
        List<ScheduledPayment> contributingPayments = paymentsContributingToDeficit(minimumBalanceDate, offsetDays);
        String message = buildDeficitTimelineMessage(
                firstNegativeDate,
                minimumBalanceDate,
                deficit,
                contributingPayments,
                suggestions.isEmpty()
        );
        String actionToken = suggestions.isEmpty() ? null : suggestions.get(0).actionToken();

        return new AiAnalyzeResponse(
                true,
                "%s %s".formatted(message, normalizeReasoning(enrichmentSummary)).trim(),
                actionToken,
                suggestions
        );
    }

    @Transactional
    public AiExecuteResponse execute(AiExecuteRequest request) {
        ActionExecutionResult result = executeActionToken(request.actionToken());
        return new AiExecuteResponse(
                true,
                result.message(),
                result.currentBalance(),
                result.savingsBalance()
        );
    }

    private List<BalanceSuggestionResponse> buildSuggestions(AiDashboardResponse dashboard, BigDecimal deficit) {
        LinkedHashMap<String, BalanceSuggestionResponse> suggestions = new LinkedHashMap<>();
        Account savings = accountService.getAccountByType(AccountType.SAVINGS);
        List<ScheduledPayment> flexiblePayments = collectFlexiblePayments(dashboard.horizonDays());

        if (savings.getBalance().compareTo(BigDecimal.ZERO) > 0) {
            boolean covered = savings.getBalance().compareTo(deficit) >= 0;
            BalanceSuggestionResponse suggestion = new BalanceSuggestionResponse(
                    "close-deposit-%d".formatted(savings.getId()),
                    covered ? "Закрыть депозит и закрыть разрыв" : "Закрыть депозит и сократить разрыв",
                    covered
                            ? "Закрытие накопительного депозита даст %s и полностью покроет дефицит %s."
                            .formatted(money(savings.getBalance()), money(deficit))
                            : "Закрытие накопительного депозита даст %s и сократит дефицит %s."
                            .formatted(money(savings.getBalance()), money(deficit)),
                    "CLOSE_DEPOSIT:%d".formatted(savings.getId())
            );
            suggestions.put(suggestion.actionToken(), suggestion);
        }

        ScheduledPayment singleCandidate = pickSinglePostponeCandidate(flexiblePayments, deficit);
        if (singleCandidate != null) {
            LocalDate targetDate = inferRecommendedPostponeDate(singleCandidate.getDueDate());
            if (targetDate.isAfter(singleCandidate.getDueDate())) {
                BigDecimal postponedAmount = singleCandidate.getAmount();
                boolean covers = postponedAmount.compareTo(deficit) >= 0;
                BalanceSuggestionResponse suggestion = new BalanceSuggestionResponse(
                        "postpone-%d".formatted(singleCandidate.getId()),
                        "Перенести платеж \"%s\"".formatted(singleCandidate.getTitle()),
                        (covers
                                ? "Сдвиг до %s освободит %s и полностью закроет разрыв."
                                : "Сдвиг до %s освободит %s и уменьшит текущий разрыв.")
                                .formatted(shortDateLabel(targetDate), money(postponedAmount)),
                        "POSTPONE:%d:%s".formatted(singleCandidate.getId(), targetDate)
                );
                suggestions.put(suggestion.actionToken(), suggestion);
            }
        }

        List<ScheduledPayment> grouped = pickPaymentsForCoverage(flexiblePayments, deficit);
        if (!grouped.isEmpty()) {
            boolean duplicateSingleGroup = grouped.size() == 1
                    && singleCandidate != null
                    && grouped.get(0).getId().equals(singleCandidate.getId());
            LocalDate latestDueDate = latestDueDate(grouped);
            LocalDate targetDate = inferRecommendedPostponeDate(latestDueDate);
            if (!duplicateSingleGroup && targetDate.isAfter(latestDueDate)) {
                BigDecimal coveredAmount = grouped.stream()
                        .map(ScheduledPayment::getAmount)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                String paymentIds = grouped.stream()
                        .map(payment -> payment.getId().toString())
                        .reduce((left, right) -> left + "," + right)
                        .orElse("");
                BalanceSuggestionResponse suggestion = new BalanceSuggestionResponse(
                        "postpone-group-%s".formatted(paymentIds),
                        grouped.size() == 1 ? "Перенести один гибкий платеж" : "Перенести группу платежей",
                        "Перенос %d платежей до %s освободит %s и снизит нагрузку на баланс."
                                .formatted(grouped.size(), shortDateLabel(targetDate), money(coveredAmount)),
                        "POSTPONE_GROUP:%s:%s".formatted(paymentIds, targetDate)
                );
                suggestions.put(suggestion.actionToken(), suggestion);

                if (savings.getBalance().compareTo(BigDecimal.ZERO) > 0
                        && savings.getBalance().compareTo(deficit) < 0
                        && savings.getBalance().add(coveredAmount).compareTo(deficit) >= 0) {
                    BalanceSuggestionResponse combo = new BalanceSuggestionResponse(
                            "combo-%d-%s".formatted(savings.getId(), paymentIds),
                            "Комбинировать депозит и перенос",
                            "Закройте депозит и перенесите %d платежей до %s, чтобы полностью убрать дефицит."
                                    .formatted(grouped.size(), shortDateLabel(targetDate)),
                            "CLOSE_DEPOSIT_AND_POSTPONE:%d:%s:%s"
                                    .formatted(savings.getId(), paymentIds, targetDate)
                    );
                    suggestions.put(combo.actionToken(), combo);
                }
            }
        }

        return new ArrayList<>(suggestions.values());
    }

    private List<ScheduledPayment> collectFlexiblePayments(int horizonDays) {
        return paymentsInHorizon(horizonDays).stream()
                .filter(ScheduledPayment::isFlexible)
                .sorted(Comparator.comparing(ScheduledPayment::getDueDate)
                        .thenComparing(ScheduledPayment::getAmount, Comparator.reverseOrder()))
                .toList();
    }

    private List<ScheduledPayment> paymentsInHorizon(int horizonDays) {
        LocalDate currentDate = userSettingsService.currentDate();
        LocalDate horizonDate = currentDate.plusDays(Math.max(0, horizonDays));
        return scheduledPaymentService.getPendingPayments().stream()
                .filter(payment -> payment.getAccount().getType() == AccountType.MAIN)
                .filter(payment -> !payment.getDueDate().isBefore(currentDate))
                .filter(payment -> !payment.getDueDate().isAfter(horizonDate))
                .sorted(Comparator.comparing(ScheduledPayment::getDueDate)
                        .thenComparing(ScheduledPayment::getAmount, Comparator.reverseOrder()))
                .toList();
    }

    private java.util.Optional<LocalDate> firstNegativeDate(AiDashboardResponse dashboard) {
        return dashboard.points().stream()
                .filter(point -> point.balance().compareTo(BigDecimal.ZERO) < 0)
                .map(point -> LocalDate.parse(point.isoDate()))
                .findFirst();
    }

    private java.util.Optional<LocalDate> minimumBalanceDate(AiDashboardResponse dashboard) {
        return dashboard.points().stream()
                .filter(point -> point.balance().compareTo(dashboard.minimumProjectedBalance()) == 0)
                .map(point -> LocalDate.parse(point.isoDate()))
                .findFirst();
    }

    private List<ScheduledPayment> paymentsContributingToDeficit(LocalDate untilDate, int horizonDays) {
        return paymentsInHorizon(horizonDays).stream()
                .filter(payment -> !payment.getDueDate().isAfter(untilDate))
                .toList();
    }

    private String buildDeficitTimelineMessage(LocalDate firstNegativeDate,
                                               LocalDate minimumBalanceDate,
                                               BigDecimal deficit,
                                               List<ScheduledPayment> payments,
                                               boolean noSuggestions) {
        if (payments.isEmpty()) {
            return noSuggestions
                    ? "К %s ожидается дефицит %s. Подходящих действий не найдено."
                    .formatted(shortDateLabel(minimumBalanceDate), money(deficit))
                    : "К %s ожидается дефицит %s. Ниже варианты, как закрыть разрыв."
                    .formatted(shortDateLabel(minimumBalanceDate), money(deficit));
        }

        StringBuilder message = new StringBuilder();
        if (firstNegativeDate.isEqual(minimumBalanceDate)) {
            message.append("С ")
                    .append(shortDateLabel(firstNegativeDate))
                    .append(" счет уйдет в минус.");
        } else {
            message.append("С ")
                    .append(shortDateLabel(firstNegativeDate))
                    .append(" счет уйдет в минус, а к ")
                    .append(shortDateLabel(minimumBalanceDate))
                    .append(" дефицит вырастет до ")
                    .append(money(deficit))
                    .append(".");
        }

        Map<LocalDate, List<ScheduledPayment>> paymentsByDate = payments.stream()
                .collect(Collectors.groupingBy(
                        ScheduledPayment::getDueDate,
                        LinkedHashMap::new,
                        Collectors.toList()
                ));

        for (Map.Entry<LocalDate, List<ScheduledPayment>> entry : paymentsByDate.entrySet()) {
            BigDecimal amountForDate = entry.getValue().stream()
                    .map(ScheduledPayment::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            message.append(" ")
                    .append(shortDateLabel(entry.getKey()))
                    .append(" спишется ")
                    .append(money(amountForDate))
                    .append(" ");
            if (entry.getValue().size() == 1) {
                message.append("по платежу \"")
                        .append(entry.getValue().get(0).getTitle())
                        .append("\".");
            } else {
                String titles = entry.getValue().stream()
                        .map(ScheduledPayment::getTitle)
                        .map(title -> "\"" + title + "\"")
                        .collect(Collectors.joining(", "));
                message.append("по платежам ")
                        .append(titles)
                        .append(".");
            }
        }

        message.append(" В сумме к ")
                .append(shortDateLabel(minimumBalanceDate))
                .append(" дефицит составит ")
                .append(money(deficit))
                .append(".");
        message.append(noSuggestions
                ? " Подходящих действий не найдено."
                : " Ниже варианты, как закрыть разрыв.");
        return message.toString();
    }

    private ScheduledPayment pickSinglePostponeCandidate(List<ScheduledPayment> payments, BigDecimal deficit) {
        return payments.stream()
                .sorted((left, right) -> {
                    int byAmount = right.getAmount().compareTo(left.getAmount());
                    return byAmount != 0 ? byAmount : left.getDueDate().compareTo(right.getDueDate());
                })
                .filter(payment -> inferRecommendedPostponeDate(payment.getDueDate()).isAfter(payment.getDueDate()))
                .filter(payment -> payment.getAmount().compareTo(deficit) >= 0)
                .findFirst()
                .orElseGet(() -> payments.stream()
                        .filter(payment -> inferRecommendedPostponeDate(payment.getDueDate()).isAfter(payment.getDueDate()))
                        .findFirst()
                        .orElse(null));
    }

    private List<ScheduledPayment> pickPaymentsForCoverage(List<ScheduledPayment> payments, BigDecimal requiredAmount) {
        if (payments.size() <= 15) {
            return optimalSubsetCoverage(payments, requiredAmount);
        }
        return greedyCoverage(payments, requiredAmount);
    }

    private List<ScheduledPayment> optimalSubsetCoverage(List<ScheduledPayment> payments, BigDecimal requiredAmount) {
        List<ScheduledPayment> bestSubset = null;
        int bestSize = Integer.MAX_VALUE;
        BigDecimal bestTotal = null;

        int n = payments.size();
        for (int mask = 1; mask < (1 << n); mask++) {
            List<ScheduledPayment> subset = new ArrayList<>();
            BigDecimal total = BigDecimal.ZERO;
            for (int bit = 0; bit < n; bit++) {
                if ((mask & (1 << bit)) != 0) {
                    subset.add(payments.get(bit));
                    total = total.add(payments.get(bit).getAmount());
                }
            }
            if (total.compareTo(requiredAmount) < 0) {
                continue;
            }
            if (subset.size() < bestSize || (subset.size() == bestSize && (bestTotal == null || total.compareTo(bestTotal) < 0))) {
                bestSubset = subset;
                bestSize = subset.size();
                bestTotal = total;
            }
        }
        return bestSubset != null ? bestSubset : greedyCoverage(payments, requiredAmount);
    }

    private List<ScheduledPayment> greedyCoverage(List<ScheduledPayment> payments, BigDecimal requiredAmount) {
        List<ScheduledPayment> selected = new ArrayList<>();
        BigDecimal covered = BigDecimal.ZERO;
        for (ScheduledPayment payment : payments) {
            selected.add(payment);
            covered = covered.add(payment.getAmount());
            if (covered.compareTo(requiredAmount) >= 0) {
                break;
            }
        }
        return selected;
    }

    private LocalDate inferRecommendedPostponeDate(LocalDate afterDate) {
        Long userId = userContextService.getCurrentUser().getId();
        IncomeCalendarService.IncomeCalendar calendar = incomeCalendarService.buildCalendar(userId, afterDate);
        if (calendar.confidencePercent() >= 50) {
            LocalDate candidate = calendar.rangeEnd().isAfter(afterDate)
                    ? calendar.rangeEnd()
                    : calendar.nextExpectedDate();
            if (candidate.isAfter(afterDate)) {
                return candidate;
            }
        }
        return afterDate.plusDays(7);
    }

    private ActionExecutionResult executeActionToken(String actionToken) {
        if (actionToken == null || actionToken.isBlank()) {
            throw new IllegalArgumentException(INVALID_ACTION_TOKEN_MESSAGE);
        }

        String[] parts = actionToken.split(":");
        return switch (parts[0]) {
            case "CLOSE_DEPOSIT" -> closeDeposit();
            case "POSTPONE" -> postponeSingle(parts);
            case "POSTPONE_GROUP" -> postponeGroup(parts);
            case "CLOSE_DEPOSIT_AND_POSTPONE" -> closeDepositAndPostpone(parts);
            default -> throw new IllegalArgumentException(INVALID_ACTION_TOKEN_MESSAGE);
        };
    }

    private ActionExecutionResult closeDeposit() {
        Account savings = accountService.getAccountByType(AccountType.SAVINGS);
        return bankingAgentTools.autoTransferFromSavings(savings.getBalance().toPlainString());
    }

    private ActionExecutionResult postponeSingle(String[] parts) {
        if (parts.length < 3) {
            throw new IllegalArgumentException(INVALID_ACTION_TOKEN_MESSAGE);
        }
        Long paymentId = Long.parseLong(parts[1]);
        LocalDate targetDate = resolveTargetDate(parts[2], paymentDateById(paymentId));
        return scheduledPaymentService.postponePaymentTo(paymentId, targetDate);
    }

    private ActionExecutionResult postponeGroup(String[] parts) {
        if (parts.length < 3) {
            throw new IllegalArgumentException(INVALID_ACTION_TOKEN_MESSAGE);
        }
        List<Long> paymentIds = parsePaymentIds(parts[1]);
        LocalDate targetDate = resolveTargetDate(parts[2], latestPaymentDate(paymentIds));
        return scheduledPaymentService.postponePaymentsTo(paymentIds, targetDate);
    }

    private ActionExecutionResult closeDepositAndPostpone(String[] parts) {
        if (parts.length < 4) {
            throw new IllegalArgumentException(INVALID_ACTION_TOKEN_MESSAGE);
        }
        closeDeposit();
        List<Long> paymentIds = parsePaymentIds(parts[2]);
        LocalDate targetDate = resolveTargetDate(parts[3], latestPaymentDate(paymentIds));
        return scheduledPaymentService.postponePaymentsTo(paymentIds, targetDate);
    }

    private List<Long> parsePaymentIds(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return List.of();
        }
        return Arrays.stream(rawValue.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(Long::parseLong)
                .toList();
    }

    private LocalDate resolveTargetDate(String targetSpec, LocalDate referenceDate) {
        try {
            return referenceDate.plusDays(Long.parseLong(targetSpec));
        } catch (NumberFormatException ignored) {
            return LocalDate.parse(targetSpec);
        }
    }

    private LocalDate paymentDateById(Long paymentId) {
        return scheduledPaymentService.getPendingPayments().stream()
                .filter(payment -> payment.getId().equals(paymentId))
                .map(ScheduledPayment::getDueDate)
                .findFirst()
                .orElse(userSettingsService.currentDate());
    }

    private LocalDate latestPaymentDate(List<Long> paymentIds) {
        return scheduledPaymentService.getPendingPayments().stream()
                .filter(payment -> paymentIds.contains(payment.getId()))
                .map(ScheduledPayment::getDueDate)
                .max(LocalDate::compareTo)
                .orElse(userSettingsService.currentDate());
    }

    private LocalDate latestDueDate(List<ScheduledPayment> payments) {
        return payments.stream()
                .map(ScheduledPayment::getDueDate)
                .max(LocalDate::compareTo)
                .orElse(userSettingsService.currentDate());
    }

    private String normalizeReasoning(EnrichmentSummary enrichmentSummary) {
        if (enrichmentSummary == null || enrichmentSummary.reasoning() == null || enrichmentSummary.reasoning().isBlank()) {
            return "Регулярные расходы и запланированные списания создают риск кассового разрыва.";
        }
        return enrichmentSummary.reasoning();
    }

    private String money(BigDecimal amount) {
        return amount.setScale(2, RoundingMode.HALF_UP).toPlainString() + " KGS";
    }

    private String shortDateLabel(LocalDate value) {
        return "%d %s".formatted(value.getDayOfMonth(), switch (value.getMonthValue()) {
            case 1 -> "янв.";
            case 2 -> "фев.";
            case 3 -> "мар.";
            case 4 -> "апр.";
            case 5 -> "мая";
            case 6 -> "июн.";
            case 7 -> "июл.";
            case 8 -> "авг.";
            case 9 -> "сент.";
            case 10 -> "окт.";
            case 11 -> "нояб.";
            default -> "дек.";
        });
    }

}

