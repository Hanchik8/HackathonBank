package com.example.hackathonbank.service;

import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
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

    private static final int LOOKBACK_DAYS = 90;
    private static final int DEFAULT_FALLBACK_DAYS = 14;
    private static final int DAY_TOLERANCE = 2;
    private static final BigDecimal SALARY_THRESHOLD = new BigDecimal("30000.00");
    private static final BigDecimal TOPUP_LOWER = new BigDecimal("5000.00");
    private static final BigDecimal AMOUNT_BAND_SIZE = new BigDecimal("10000.00");

    private final TransactionRepository transactionRepository;

    public IncomeCalendarService(TransactionRepository transactionRepository) {
        this.transactionRepository = transactionRepository;
    }

    public IncomeCalendar buildCalendar(Long userId, LocalDate referenceDate) {
        List<Transaction> incomes = loadIncomes(userId, referenceDate);
        if (incomes.isEmpty()) {
            return IncomeCalendar.empty(referenceDate.plusDays(DEFAULT_FALLBACK_DAYS));
        }

        List<ClassifiedIncome> classified = classifyIncomes(incomes);
        List<IncomeCluster> clusters = buildClusters(classified);
        clusters.sort(Comparator.comparingDouble((IncomeCluster c) -> c.confidence()).reversed()
                .thenComparing(IncomeCluster::averageAmount, Comparator.reverseOrder()));

        IncomeCluster nextCluster = findNextCluster(clusters, referenceDate);
        LocalDate nextDate = nextCluster != null
                ? nextOccurrence(referenceDate, nextCluster.dayOfMonth())
                : referenceDate.plusDays(DEFAULT_FALLBACK_DAYS);
        int confidence = nextCluster != null ? (int) Math.round(nextCluster.confidence()) : 0;

        int tolerance = nextCluster != null ? computeTolerance(nextCluster) : DAY_TOLERANCE;
        LocalDate rangeStart = nextDate.minusDays(tolerance);
        LocalDate rangeEnd = nextDate.plusDays(tolerance);

        return new IncomeCalendar(clusters, nextDate, confidence, rangeStart, rangeEnd);
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
            if (cluster.confidence() < minConfidencePercent) {
                continue;
            }

            LocalDate occurrence = nextOccurrence(referenceDate.minusDays(1), cluster.dayOfMonth());
            while (!occurrence.isAfter(horizonEnd)) {
                int tolerance = computeTolerance(cluster);
                events.add(new ProjectedIncomeEvent(
                        cluster.type(),
                        occurrence,
                        occurrence.minusDays(tolerance),
                        occurrence.plusDays(tolerance),
                        cluster.averageAmount(),
                        (int) Math.round(cluster.confidence())
                ));
                occurrence = nextOccurrence(occurrence, cluster.dayOfMonth());
            }
        }

        events.sort(Comparator.comparing(ProjectedIncomeEvent::conservativeDate)
                .thenComparing(ProjectedIncomeEvent::expectedAmount, Comparator.reverseOrder()));
        return events;
    }

    private List<Transaction> loadIncomes(Long userId, LocalDate referenceDate) {
        LocalDateTime windowStart = referenceDate.minusDays(LOOKBACK_DAYS).atStartOfDay();
        LocalDateTime windowEnd = referenceDate.atTime(23, 59, 59);
        return transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                userId, TransactionStatus.COMPLETED, windowStart, windowEnd
        ).stream()
                .filter(t -> t.getAmount().compareTo(BigDecimal.ZERO) > 0)
                .sorted(Comparator.comparing(Transaction::getOccurredAt))
                .toList();
    }

    private List<ClassifiedIncome> classifyIncomes(List<Transaction> incomes) {
        return incomes.stream().map(t -> {
            BigDecimal amount = t.getAmount();
            String text = ((t.getTitle() != null ? t.getTitle() : "") + " " +
                    (t.getCategory() != null ? t.getCategory() : "") + " " +
                    (t.getCounterparty() != null ? t.getCounterparty() : "")).toLowerCase(Locale.ROOT);

            IncomeType type;
            if (isLikelyRefund(text)) {
                type = IncomeType.REFUND;
            } else if (isLikelyTopup(text)) {
                type = IncomeType.TOPUP;
            } else if (amount.compareTo(SALARY_THRESHOLD) >= 0) {
                type = IncomeType.SALARY;
            } else if (amount.compareTo(TOPUP_LOWER) >= 0) {
                type = isLikelySalary(text) ? IncomeType.SALARY : IncomeType.FREELANCE;
            } else {
                type = IncomeType.OTHER;
            }
            return new ClassifiedIncome(t, type);
        }).toList();
    }

    private boolean isLikelySalary(String text) {
        return containsAny(text, "зарплат", "salary", "оклад", "аванс");
    }

    private boolean isLikelyRefund(String text) {
        return containsAny(text, "возврат", "кэшбэк", "cashback", "refund", "бонус");
    }

    private boolean isLikelyTopup(String text) {
        return containsAny(text, "пополнен", "top-up", "topup", "top up", "deposit", "внесен");
    }

    private List<IncomeCluster> buildClusters(List<ClassifiedIncome> classified) {
        List<ClassifiedIncome> meaningful = classified.stream()
                .filter(c -> c.type() != IncomeType.REFUND && c.type() != IncomeType.OTHER)
                .toList();
        if (meaningful.isEmpty()) {
            meaningful = classified;
        }

        Map<ClusterKey, List<ClassifiedIncome>> byCluster = new LinkedHashMap<>();
        for (ClassifiedIncome ci : meaningful) {
            int rawDay = ci.transaction().getOccurredAt().getDayOfMonth();
            int amountBand = amountBand(ci.transaction().getAmount().abs());
            ClusterKey clusterKey = findOrCreateClusterKey(byCluster, ci.type(), amountBand, rawDay);
            byCluster.computeIfAbsent(clusterKey, ignored -> new ArrayList<>()).add(ci);
        }

        List<IncomeCluster> clusters = new ArrayList<>();
        for (Map.Entry<ClusterKey, List<ClassifiedIncome>> entry : byCluster.entrySet()) {
            List<ClassifiedIncome> group = entry.getValue();
            int occurrences = group.size();
            BigDecimal totalAmount = group.stream()
                    .map(ci -> ci.transaction().getAmount())
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal averageAmount = totalAmount.divide(BigDecimal.valueOf(occurrences), 2, RoundingMode.HALF_UP);

            IncomeType dominantType = group.stream()
                    .collect(Collectors.groupingBy(ClassifiedIncome::type, Collectors.counting()))
                    .entrySet().stream()
                    .max(Map.Entry.comparingByValue())
                    .map(Map.Entry::getKey)
                    .orElse(IncomeType.OTHER);

            double confidence = computeConfidence(group, averageAmount);

            clusters.add(new IncomeCluster(dominantType, entry.getKey().dayOfMonth(), averageAmount, occurrences, confidence));
        }
        return clusters;
    }

    private ClusterKey findOrCreateClusterKey(Map<ClusterKey, List<ClassifiedIncome>> existing,
                                              IncomeType type,
                                              int amountBand,
                                              int rawDay) {
        for (ClusterKey key : existing.keySet()) {
            if (key.type() != type || key.amountBand() != amountBand) {
                continue;
            }
            if (circularDayDistance(key.dayOfMonth(), rawDay) <= DAY_TOLERANCE) {
                return key;
            }
        }
        return new ClusterKey(type, amountBand, rawDay);
    }

    private IncomeCluster findNextCluster(List<IncomeCluster> clusters, LocalDate referenceDate) {
        return clusters.stream()
                .filter(c -> c.confidence() >= 50.0)
                .min(Comparator.comparing((IncomeCluster cluster) -> nextOccurrence(referenceDate, cluster.dayOfMonth()))
                        .thenComparing(IncomeCluster::confidence, Comparator.reverseOrder())
                        .thenComparing(IncomeCluster::averageAmount, Comparator.reverseOrder()))
                .orElse(clusters.isEmpty() ? null : clusters.get(0));
    }

    private int computeTolerance(IncomeCluster cluster) {
        return cluster.confidence() >= 100.0 ? 1 : DAY_TOLERANCE;
    }

    private int amountBand(BigDecimal amount) {
        return amount.divide(AMOUNT_BAND_SIZE, 0, RoundingMode.FLOOR).intValue();
    }

    private int circularDayDistance(int left, int right) {
        int distance = Math.abs(left - right);
        return Math.min(distance, 31 - Math.min(distance, 31));
    }

    private double computeConfidence(List<ClassifiedIncome> group, BigDecimal averageAmount) {
        double base = Math.min(100.0, group.size() * 33.0);
        int minDay = group.stream()
                .map(ci -> ci.transaction().getOccurredAt().getDayOfMonth())
                .min(Integer::compareTo)
                .orElse(1);
        int maxDay = group.stream()
                .map(ci -> ci.transaction().getOccurredAt().getDayOfMonth())
                .max(Integer::compareTo)
                .orElse(minDay);
        double dayPenalty = Math.max(0, maxDay - minDay - DAY_TOLERANCE) * 4.0;

        double mean = averageAmount.doubleValue();
        double amountPenalty = 0.0;
        if (mean > 0.0 && group.size() > 1) {
            double variance = group.stream()
                    .map(ci -> ci.transaction().getAmount().doubleValue())
                    .mapToDouble(value -> {
                        double diff = value - mean;
                        return diff * diff;
                    })
                    .average()
                    .orElse(0.0);
            double coefficientOfVariation = Math.sqrt(variance) / mean;
            amountPenalty = Math.min(18.0, coefficientOfVariation * 25.0);
        }

        return Math.max(0.0, Math.min(100.0, base - dayPenalty - amountPenalty));
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

    private record ClassifiedIncome(Transaction transaction, IncomeType type) {}

    private record ClusterKey(IncomeType type, int amountBand, int dayOfMonth) {}

    public record IncomeCalendar(
            List<IncomeCluster> clusters,
            LocalDate nextExpectedDate,
            int confidencePercent,
            LocalDate rangeStart,
            LocalDate rangeEnd
    ) {
        static IncomeCalendar empty(LocalDate fallbackDate) {
            return new IncomeCalendar(List.of(), fallbackDate, 0, fallbackDate, fallbackDate);
        }
    }

    public record IncomeCluster(
            IncomeType type,
            int dayOfMonth,
            BigDecimal averageAmount,
            int occurrences,
            double confidence
    ) {}

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
