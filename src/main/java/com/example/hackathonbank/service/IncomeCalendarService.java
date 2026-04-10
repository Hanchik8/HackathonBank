package com.example.hackathonbank.service;

import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class IncomeCalendarService {

    private static final int LOOKBACK_DAYS = 120;
    private static final int DEFAULT_FALLBACK_DAYS = 14;
    private static final int DAY_TOLERANCE = 2;
    private static final BigDecimal AMOUNT_BAND_SIZE = new BigDecimal("10000.00");

    private final TransactionRepository transactionRepository;

    public IncomeCalendarService(TransactionRepository transactionRepository) {
        this.transactionRepository = transactionRepository;
    }

    public IncomeCalendar buildCalendar(Long userId, LocalDate referenceDate) {
        List<Transaction> incomes = loadIncomes(userId, referenceDate);
        if (incomes.isEmpty()) {
            LocalDate fallbackDate = referenceDate.plusDays(DEFAULT_FALLBACK_DAYS);
            return IncomeCalendar.empty(fallbackDate);
        }

        List<IncomeCluster> clusters = buildClusters(incomes);
        clusters.sort(Comparator.comparing(IncomeCluster::typePriority)
                .thenComparing(IncomeCluster::confidencePercent, Comparator.reverseOrder())
                .thenComparing(cluster -> nextOccurrence(referenceDate, cluster.expectedDayOfMonth()))
                .thenComparing(IncomeCluster::averageAmount, Comparator.reverseOrder()));

        IncomeCluster selectedCluster = selectPrimaryCluster(clusters, referenceDate);
        if (selectedCluster == null) {
            LocalDate fallbackDate = referenceDate.plusDays(DEFAULT_FALLBACK_DAYS);
            return new IncomeCalendar(clusters, new NextIncomeForecast(
                    fallbackDate,
                    fallbackDate,
                    fallbackDate,
                    BigDecimal.ZERO,
                    IncomeType.OTHER,
                    0
            ));
        }

        LocalDate expectedDate = nextOccurrence(referenceDate, selectedCluster.expectedDayOfMonth());
        int tolerance = toleranceDays(selectedCluster);
        return new IncomeCalendar(
                clusters,
                new NextIncomeForecast(
                        expectedDate,
                        expectedDate.minusDays(tolerance),
                        expectedDate.plusDays(tolerance),
                        selectedCluster.averageAmount(),
                        selectedCluster.type(),
                        selectedCluster.confidencePercent()
                )
        );
    }

    public List<ProjectedIncomeEvent> projectedIncomeEvents(Long userId,
                                                            LocalDate referenceDate,
                                                            LocalDate horizonEnd,
                                                            int minConfidencePercent) {
        return projectedIncomeEvents(buildCalendar(userId, referenceDate), referenceDate, horizonEnd, minConfidencePercent);
    }

    public List<ProjectedIncomeEvent> projectedIncomeEvents(IncomeCalendar calendar,
                                                            LocalDate referenceDate,
                                                            LocalDate horizonEnd,
                                                            int minConfidencePercent) {
        if (horizonEnd.isBefore(referenceDate)) {
            return List.of();
        }

        List<ProjectedIncomeEvent> events = new ArrayList<>();
        for (IncomeCluster cluster : calendar.clusters()) {
            if (cluster.confidencePercent() < minConfidencePercent) {
                continue;
            }

            LocalDate occurrence = nextOccurrence(referenceDate.minusDays(1), cluster.expectedDayOfMonth());
            while (!occurrence.isAfter(horizonEnd)) {
                int tolerance = toleranceDays(cluster);
                events.add(new ProjectedIncomeEvent(
                        cluster.type(),
                        occurrence,
                        occurrence.minusDays(tolerance),
                        occurrence.plusDays(tolerance),
                        cluster.averageAmount(),
                        cluster.confidencePercent()
                ));
                occurrence = nextOccurrence(occurrence, cluster.expectedDayOfMonth());
            }
        }

        events.sort(Comparator.comparing(ProjectedIncomeEvent::conservativeDate)
                .thenComparing(ProjectedIncomeEvent::expectedAmount, Comparator.reverseOrder()));
        return events;
    }

    private List<Transaction> loadIncomes(Long userId, LocalDate referenceDate) {
        LocalDateTime windowStart = referenceDate.minusDays(LOOKBACK_DAYS).atStartOfDay();
        LocalDateTime windowEnd = referenceDate.atTime(23, 59, 59);
        return transactionRepository.findByUserIdAndAccountTypeAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                userId,
                AccountType.MAIN,
                TransactionStatus.COMPLETED,
                windowStart,
                windowEnd
        ).stream()
                .filter(transaction -> transaction.getAmount().compareTo(BigDecimal.ZERO) > 0)
                .filter(transaction -> transaction.getType() != TransactionType.TRANSFER)
                .sorted(Comparator.comparing(Transaction::getOccurredAt))
                .toList();
    }

    private List<IncomeCluster> buildClusters(List<Transaction> incomes) {
        Map<ClusterKey, List<Transaction>> grouped = new LinkedHashMap<>();
        for (Transaction transaction : incomes) {
            IncomeType type = resolveIncomeType(transaction);
            int amountBand = amountBand(transaction.getAmount());
            int rawDay = transaction.getOccurredAt().getDayOfMonth();
            ClusterKey clusterKey = findOrCreateClusterKey(grouped, type, transaction.getNormalizedCounterparty(), amountBand, rawDay);
            grouped.computeIfAbsent(clusterKey, ignored -> new ArrayList<>()).add(transaction);
        }

        List<IncomeCluster> clusters = new ArrayList<>();
        for (Map.Entry<ClusterKey, List<Transaction>> entry : grouped.entrySet()) {
            List<Transaction> group = entry.getValue();
            BigDecimal averageAmount = group.stream()
                    .map(Transaction::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .divide(BigDecimal.valueOf(group.size()), 2, RoundingMode.HALF_UP);
            int expectedDay = (int) Math.round(group.stream()
                    .mapToInt(transaction -> transaction.getOccurredAt().getDayOfMonth())
                    .average()
                    .orElse(entry.getKey().dayOfMonth()));
            int confidence = confidence(group, averageAmount, entry.getKey().type());

            clusters.add(new IncomeCluster(
                    entry.getKey().type(),
                    entry.getKey().normalizedCounterparty(),
                    averageAmount,
                    Math.max(1, Math.min(31, expectedDay)),
                    group.size(),
                    distinctMonths(group),
                    confidence
            ));
        }
        return clusters;
    }

    private ClusterKey findOrCreateClusterKey(Map<ClusterKey, List<Transaction>> existing,
                                              IncomeType type,
                                              String normalizedCounterparty,
                                              int amountBand,
                                              int rawDay) {
        for (ClusterKey key : existing.keySet()) {
            if (key.type() != type) {
                continue;
            }
            if (!key.normalizedCounterparty().equals(normalizedCounterparty)) {
                continue;
            }
            if (key.amountBand() != amountBand) {
                continue;
            }
            if (circularDayDistance(key.dayOfMonth(), rawDay) <= DAY_TOLERANCE) {
                return key;
            }
        }
        return new ClusterKey(type, normalizedCounterparty, amountBand, rawDay);
    }

    private IncomeCluster selectPrimaryCluster(List<IncomeCluster> clusters, LocalDate referenceDate) {
        return clusters.stream()
                .filter(cluster -> cluster.confidencePercent() >= 50)
                .min(Comparator.comparing(IncomeCluster::typePriority)
                        .thenComparing(cluster -> nextOccurrence(referenceDate, cluster.expectedDayOfMonth()))
                        .thenComparing(IncomeCluster::confidencePercent, Comparator.reverseOrder()))
                .orElse(clusters.stream()
                        .max(Comparator.comparing(IncomeCluster::confidencePercent)
                                .thenComparing(IncomeCluster::averageAmount))
                        .orElse(null));
    }

    private IncomeType resolveIncomeType(Transaction transaction) {
        if (transaction.getIncomeType() != null && transaction.getIncomeType() != IncomeType.OTHER) {
            return transaction.getIncomeType();
        }
        String normalized = (
                (transaction.getTitle() != null ? transaction.getTitle() : "") + " " +
                        (transaction.getCategory() != null ? transaction.getCategory() : "") + " " +
                        (transaction.getCounterparty() != null ? transaction.getCounterparty() : "")
        ).toLowerCase(Locale.ROOT);
        if (containsAny(normalized, "возврат", "refund", "cashback", "кэшбэк")) {
            return IncomeType.REFUND;
        }
        if (containsAny(normalized, "пополнение", "top up", "topup", "deposit")) {
            return IncomeType.TOPUP;
        }
        if (containsAny(normalized, "зарплат", "salary", "оклад", "аванс")) {
            return IncomeType.SALARY;
        }
        if (transaction.getAmount().compareTo(new BigDecimal("5000.00")) >= 0) {
            return IncomeType.FREELANCE;
        }
        return IncomeType.OTHER;
    }

    private int confidence(List<Transaction> transactions, BigDecimal averageAmount, IncomeType type) {
        double base = Math.min(95.0, transactions.size() * 28.0);
        long distinctMonths = distinctMonths(transactions);
        base += Math.min(15.0, distinctMonths * 4.0);
        if (type == IncomeType.SALARY) {
            base += 8.0;
        }

        int minDay = transactions.stream()
                .map(transaction -> transaction.getOccurredAt().getDayOfMonth())
                .min(Integer::compareTo)
                .orElse(1);
        int maxDay = transactions.stream()
                .map(transaction -> transaction.getOccurredAt().getDayOfMonth())
                .max(Integer::compareTo)
                .orElse(minDay);
        double dayPenalty = Math.max(0, maxDay - minDay - DAY_TOLERANCE) * 4.0;

        double mean = averageAmount.doubleValue();
        double amountPenalty = 0.0;
        if (mean > 0.0 && transactions.size() > 1) {
            double variance = transactions.stream()
                    .map(Transaction::getAmount)
                    .mapToDouble(BigDecimal::doubleValue)
                    .map(value -> {
                        double diff = value - mean;
                        return diff * diff;
                    })
                    .average()
                    .orElse(0.0);
            double coefficientOfVariation = Math.sqrt(variance) / mean;
            amountPenalty = Math.min(25.0, coefficientOfVariation * 30.0);
        }

        double cadencePenalty = cadencePenalty(transactions);
        return (int) Math.max(0.0, Math.min(100.0, base - dayPenalty - amountPenalty - cadencePenalty));
    }

    private double cadencePenalty(List<Transaction> transactions) {
        if (transactions.size() < 2) {
            return 20.0;
        }
        List<YearMonth> months = transactions.stream()
                .map(transaction -> YearMonth.from(transaction.getOccurredAt()))
                .distinct()
                .sorted()
                .toList();
        if (months.size() < 2) {
            return 0.0;
        }
        int missedGaps = 0;
        for (int index = 1; index < months.size(); index++) {
            long gap = months.get(index - 1).until(months.get(index), java.time.temporal.ChronoUnit.MONTHS);
            if (gap > 1) {
                missedGaps += (int) gap - 1;
            }
        }
        return Math.min(20.0, missedGaps * 6.0);
    }

    private long distinctMonths(List<Transaction> transactions) {
        return transactions.stream()
                .map(transaction -> YearMonth.from(transaction.getOccurredAt()))
                .distinct()
                .count();
    }

    private int toleranceDays(IncomeCluster cluster) {
        return cluster.confidencePercent() >= 85 ? 1 : DAY_TOLERANCE;
    }

    private int amountBand(BigDecimal amount) {
        return amount.divide(AMOUNT_BAND_SIZE, 0, RoundingMode.FLOOR).intValue();
    }

    private int circularDayDistance(int left, int right) {
        int distance = Math.abs(left - right);
        return Math.min(distance, 31 - Math.min(distance, 31));
    }

    private LocalDate nextOccurrence(LocalDate afterDate, int dayOfMonth) {
        LocalDate monthStart = afterDate.withDayOfMonth(1);
        List<LocalDate> candidates = List.of(
                safeDate(monthStart.getYear(), monthStart.getMonthValue(), dayOfMonth),
                safeDate(monthStart.plusMonths(1).getYear(), monthStart.plusMonths(1).getMonthValue(), dayOfMonth),
                safeDate(monthStart.plusMonths(2).getYear(), monthStart.plusMonths(2).getMonthValue(), dayOfMonth)
        );
        return candidates.stream()
                .filter(candidate -> candidate.isAfter(afterDate))
                .findFirst()
                .orElse(candidates.get(candidates.size() - 1));
    }

    private LocalDate safeDate(int year, int month, int dayOfMonth) {
        LocalDate monthStart = LocalDate.of(year, month, 1);
        return LocalDate.of(year, month, Math.min(dayOfMonth, monthStart.lengthOfMonth()));
    }

    private boolean containsAny(String value, String... candidates) {
        for (String candidate : candidates) {
            if (value.contains(candidate)) {
                return true;
            }
        }
        return false;
    }

    private record ClusterKey(IncomeType type, String normalizedCounterparty, int amountBand, int dayOfMonth) {
    }

    public record NextIncomeForecast(
            LocalDate expectedDate,
            LocalDate dateFrom,
            LocalDate dateTo,
            BigDecimal expectedAmount,
            IncomeType incomeType,
            int confidencePercent
    ) {
    }

    public record IncomeCalendar(List<IncomeCluster> clusters, NextIncomeForecast nextIncomeForecast) {
        public static IncomeCalendar empty(LocalDate fallbackDate) {
            return new IncomeCalendar(
                    List.of(),
                    new NextIncomeForecast(fallbackDate, fallbackDate, fallbackDate, BigDecimal.ZERO, IncomeType.OTHER, 0)
            );
        }

        public LocalDate nextExpectedDate() {
            return nextIncomeForecast.expectedDate();
        }

        public int confidencePercent() {
            return nextIncomeForecast.confidencePercent();
        }

        public LocalDate rangeStart() {
            return nextIncomeForecast.dateFrom();
        }

        public LocalDate rangeEnd() {
            return nextIncomeForecast.dateTo();
        }
    }

    public record IncomeCluster(
            IncomeType type,
            String normalizedCounterparty,
            BigDecimal averageAmount,
            int expectedDayOfMonth,
            int occurrences,
            long distinctMonths,
            int confidencePercent
    ) {
        int typePriority() {
            return switch (type) {
                case SALARY -> 0;
                case FREELANCE -> 1;
                case TOPUP -> 2;
                case REFUND, OTHER -> 3;
            };
        }
    }

    public record ProjectedIncomeEvent(
            IncomeType type,
            LocalDate expectedDate,
            LocalDate rangeStart,
            LocalDate rangeEnd,
            BigDecimal expectedAmount,
            int confidencePercent
    ) {
        public LocalDate conservativeDate() {
            return rangeEnd;
        }
    }
}
