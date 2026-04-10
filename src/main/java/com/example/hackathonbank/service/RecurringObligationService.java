package com.example.hackathonbank.service;

import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.SpendEssentiality;
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
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class RecurringObligationService {

    private static final int LOOKBACK_DAYS = 120;
    private static final int MIN_OCCURRENCES = 2;
    private static final int MIN_CONFIDENCE = 55;
    private static final int DAY_TOLERANCE = 3;

    private final TransactionRepository transactionRepository;

    public RecurringObligationService(TransactionRepository transactionRepository) {
        this.transactionRepository = transactionRepository;
    }

    public RecurringObligationForecast buildForecast(Long userId,
                                                     LocalDate referenceDate,
                                                     LocalDate horizonEnd,
                                                     List<ScheduledPayment> confirmedPayments) {
        if (horizonEnd.isBefore(referenceDate)) {
            return RecurringObligationForecast.empty();
        }

        List<Transaction> transactions = transactionRepository
                .findByUserIdAndAccountTypeAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                        userId,
                        AccountType.MAIN,
                        TransactionStatus.COMPLETED,
                        referenceDate.minusDays(LOOKBACK_DAYS).atStartOfDay(),
                        referenceDate.atTime(23, 59, 59)
                ).stream()
                .filter(transaction -> transaction.getAmount().compareTo(BigDecimal.ZERO) < 0)
                .filter(transaction -> transaction.getType() != TransactionType.TRANSFER)
                .filter(transaction -> transaction.getScheduledPayment() == null)
                .toList();

        if (transactions.isEmpty()) {
            return RecurringObligationForecast.empty();
        }

        Set<String> confirmedKeys = confirmedPayments.stream()
                .filter(payment -> payment.getStatus() == PaymentStatus.SCHEDULED || payment.getStatus() == PaymentStatus.POSTPONED)
                .map(this::scheduledPaymentKey)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        Map<RecurringKey, List<Transaction>> grouped = new LinkedHashMap<>();
        for (Transaction transaction : transactions) {
            RecurringKey key = new RecurringKey(
                    transaction.getNormalizedCounterparty(),
                    normalize(transaction.getCategory()),
                    transaction.getEssentiality()
            );
            grouped.computeIfAbsent(key, ignored -> new ArrayList<>()).add(transaction);
        }

        List<RecurringObligationCluster> clusters = new ArrayList<>();
        for (Map.Entry<RecurringKey, List<Transaction>> entry : grouped.entrySet()) {
            RecurringObligationCluster cluster = cluster(entry.getKey(), entry.getValue(), referenceDate);
            if (cluster == null) {
                continue;
            }
            if (confirmedKeys.contains(cluster.matchKey())) {
                continue;
            }
            clusters.add(cluster);
        }

        List<ProjectedObligationEvent> events = new ArrayList<>();
        for (RecurringObligationCluster cluster : clusters) {
            if (cluster.confidencePercent() < MIN_CONFIDENCE) {
                continue;
            }
            LocalDate occurrence = nextOccurrence(referenceDate.minusDays(1), cluster.expectedDayOfMonth());
            while (!occurrence.isAfter(horizonEnd)) {
                events.add(new ProjectedObligationEvent(
                        cluster.matchKey(),
                        cluster.displayName(),
                        cluster.category(),
                        cluster.expectedAmount(),
                        cluster.weightedAmount(),
                        occurrence,
                        cluster.confidencePercent(),
                        cluster.essentiality()
                ));
                occurrence = nextOccurrence(occurrence, cluster.expectedDayOfMonth());
            }
        }

        events.sort(Comparator.comparing(ProjectedObligationEvent::date)
                .thenComparing(ProjectedObligationEvent::weightedAmount, Comparator.reverseOrder()));

        Set<String> recurringKeys = clusters.stream()
                .filter(cluster -> cluster.confidencePercent() >= MIN_CONFIDENCE)
                .map(RecurringObligationCluster::matchKey)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        return new RecurringObligationForecast(clusters, events, recurringKeys);
    }

    private RecurringObligationCluster cluster(RecurringKey key,
                                               List<Transaction> transactions,
                                               LocalDate referenceDate) {
        if (transactions.size() < MIN_OCCURRENCES) {
            return null;
        }

        List<Transaction> ordered = transactions.stream()
                .sorted(Comparator.comparing(Transaction::getOccurredAt))
                .toList();

        long distinctMonths = ordered.stream()
                .map(transaction -> YearMonth.from(transaction.getOccurredAt()))
                .distinct()
                .count();
        if (distinctMonths < MIN_OCCURRENCES) {
            return null;
        }

        BigDecimal averageAmount = ordered.stream()
                .map(Transaction::getAmount)
                .map(BigDecimal::abs)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(ordered.size()), 2, RoundingMode.HALF_UP);

        int expectedDay = (int) Math.round(ordered.stream()
                .mapToInt(transaction -> transaction.getOccurredAt().getDayOfMonth())
                .average()
                .orElse(referenceDate.getDayOfMonth()));

        int confidence = confidence(ordered, averageAmount, key.essentiality());
        String displayName = ordered.stream()
                .map(Transaction::getCounterparty)
                .filter(value -> value != null && !value.isBlank())
                .findFirst()
                .orElseGet(() -> ordered.get(0).getTitle());

        return new RecurringObligationCluster(
                key.counterparty() + "|" + key.category(),
                displayName,
                key.category(),
                averageAmount,
                weightedAmount(averageAmount, confidence),
                Math.max(1, Math.min(31, expectedDay)),
                confidence,
                key.essentiality(),
                ordered.size(),
                distinctMonths
        );
    }

    private int confidence(List<Transaction> transactions,
                           BigDecimal averageAmount,
                           SpendEssentiality essentiality) {
        double base = Math.min(90.0, transactions.size() * 22.0);
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
                    .map(BigDecimal::abs)
                    .mapToDouble(BigDecimal::doubleValue)
                    .map(value -> {
                        double diff = value - mean;
                        return diff * diff;
                    })
                    .average()
                    .orElse(0.0);
            double coefficientOfVariation = Math.sqrt(variance) / mean;
            amountPenalty = Math.min(25.0, coefficientOfVariation * 35.0);
        }

        double essentialBonus = essentiality == SpendEssentiality.ESSENTIAL ? 8.0 : 0.0;
        return (int) Math.max(0.0, Math.min(100.0, base + essentialBonus - dayPenalty - amountPenalty));
    }

    private BigDecimal weightedAmount(BigDecimal amount, int confidencePercent) {
        BigDecimal confidenceFactor = confidencePercent >= 80
                ? BigDecimal.ONE
                : confidencePercent >= 65
                ? new BigDecimal("0.80")
                : new BigDecimal("0.60");
        return amount.multiply(confidenceFactor).setScale(2, RoundingMode.HALF_UP);
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

    private String scheduledPaymentKey(ScheduledPayment payment) {
        return normalize(payment.getCounterparty()) + "|" + normalize(payment.getCategory());
    }

    private String normalize(String value) {
        if (value == null || value.isBlank()) {
            return "unknown";
        }
        return value.toLowerCase(Locale.ROOT)
                .replaceAll("[^\\p{IsAlphabetic}\\p{IsDigit}]+", " ")
                .trim()
                .replaceAll("\\s{2,}", " ");
    }

    private record RecurringKey(String counterparty, String category, SpendEssentiality essentiality) {
    }

    public record RecurringObligationCluster(
            String matchKey,
            String displayName,
            String category,
            BigDecimal expectedAmount,
            BigDecimal weightedAmount,
            int expectedDayOfMonth,
            int confidencePercent,
            SpendEssentiality essentiality,
            int occurrences,
            long distinctMonths
    ) {
    }

    public record ProjectedObligationEvent(
            String matchKey,
            String title,
            String category,
            BigDecimal expectedAmount,
            BigDecimal weightedAmount,
            LocalDate date,
            int confidencePercent,
            SpendEssentiality essentiality
    ) {
    }

    public record RecurringObligationForecast(
            List<RecurringObligationCluster> clusters,
            List<ProjectedObligationEvent> events,
            Set<String> recurringKeys
    ) {
        public static RecurringObligationForecast empty() {
            return new RecurringObligationForecast(List.of(), List.of(), Set.of());
        }
    }
}
