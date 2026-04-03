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
    private static final BigDecimal REFUND_UPPER = new BigDecimal("5000.00");

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

        LocalDate nextDate = predictNextDate(clusters, referenceDate);
        IncomeCluster bestCluster = clusters.stream()
                .filter(c -> c.confidence() >= 50.0)
                .findFirst()
                .orElse(clusters.isEmpty() ? null : clusters.get(0));
        int confidence = bestCluster != null ? (int) bestCluster.confidence() : 0;

        int tolerance = bestCluster != null ? computeTolerance(bestCluster) : 2;
        LocalDate rangeStart = nextDate.minusDays(tolerance);
        LocalDate rangeEnd = nextDate.plusDays(tolerance);

        return new IncomeCalendar(clusters, nextDate, confidence, rangeStart, rangeEnd);
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
            if (amount.compareTo(SALARY_THRESHOLD) >= 0 && isLikelySalary(text)) {
                type = IncomeType.SALARY;
            } else if (amount.compareTo(SALARY_THRESHOLD) >= 0) {
                type = IncomeType.SALARY;
            } else if (amount.compareTo(TOPUP_LOWER) >= 0 && amount.compareTo(SALARY_THRESHOLD) < 0) {
                type = isLikelyRefund(text) ? IncomeType.REFUND : IncomeType.FREELANCE;
            } else if (amount.compareTo(REFUND_UPPER) < 0 && isLikelyRefund(text)) {
                type = IncomeType.REFUND;
            } else if (amount.compareTo(REFUND_UPPER) < 0) {
                type = IncomeType.OTHER;
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

    private List<IncomeCluster> buildClusters(List<ClassifiedIncome> classified) {
        List<ClassifiedIncome> meaningful = classified.stream()
                .filter(c -> c.type() != IncomeType.REFUND && c.type() != IncomeType.OTHER)
                .toList();
        if (meaningful.isEmpty()) {
            meaningful = classified;
        }

        Map<Integer, List<ClassifiedIncome>> byNormalizedDay = new LinkedHashMap<>();
        for (ClassifiedIncome ci : meaningful) {
            int rawDay = ci.transaction().getOccurredAt().getDayOfMonth();
            int normalizedDay = findOrCreateClusterDay(byNormalizedDay, rawDay);
            byNormalizedDay.computeIfAbsent(normalizedDay, k -> new ArrayList<>()).add(ci);
        }

        List<IncomeCluster> clusters = new ArrayList<>();
        for (Map.Entry<Integer, List<ClassifiedIncome>> entry : byNormalizedDay.entrySet()) {
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

            double confidence = Math.min(100.0, occurrences * 33.0);

            clusters.add(new IncomeCluster(dominantType, entry.getKey(), averageAmount, occurrences, confidence));
        }
        return clusters;
    }

    private int findOrCreateClusterDay(Map<Integer, List<ClassifiedIncome>> existing, int rawDay) {
        for (int existingDay : existing.keySet()) {
            if (Math.abs(existingDay - rawDay) <= DAY_TOLERANCE) {
                return existingDay;
            }
            if (Math.abs(existingDay - rawDay + 30) <= DAY_TOLERANCE || Math.abs(existingDay - rawDay - 30) <= DAY_TOLERANCE) {
                return existingDay;
            }
        }
        return rawDay;
    }

    private LocalDate predictNextDate(List<IncomeCluster> clusters, LocalDate referenceDate) {
        return clusters.stream()
                .filter(c -> c.confidence() >= 50.0)
                .map(c -> nextOccurrence(referenceDate, c.dayOfMonth()))
                .filter(d -> d.isAfter(referenceDate))
                .min(LocalDate::compareTo)
                .orElseGet(() -> {
                    if (!clusters.isEmpty()) {
                        return nextOccurrence(referenceDate, clusters.get(0).dayOfMonth());
                    }
                    return referenceDate.plusDays(DEFAULT_FALLBACK_DAYS);
                });
    }

    private int computeTolerance(IncomeCluster cluster) {
        return cluster.confidence() >= 100.0 ? 1 : DAY_TOLERANCE;
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
}
