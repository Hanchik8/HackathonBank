package com.example.hackathonbank.service;

import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.SpendEssentiality;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.EnumMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class SpendProfileService {

    private static final int LOOKBACK_DAYS = 30;

    private final TransactionRepository transactionRepository;

    public SpendProfileService(TransactionRepository transactionRepository) {
        this.transactionRepository = transactionRepository;
    }

    public SpendProfile buildProfile(Long userId, LocalDate referenceDate) {
        return buildProfile(userId, referenceDate, Set.of());
    }

    public SpendProfile buildProfile(Long userId, LocalDate referenceDate, Set<String> excludedRecurringKeys) {
        List<Transaction> expenses = loadExpenses(userId, referenceDate).stream()
                .filter(transaction -> !excludedRecurringKeys.contains(transaction.getNormalizedCounterparty()))
                .toList();
        if (expenses.isEmpty()) {
            return SpendProfile.zero();
        }

        BigDecimal totalEssential = BigDecimal.ZERO;
        BigDecimal totalDiscretionary = BigDecimal.ZERO;

        for (Transaction transaction : expenses) {
            BigDecimal absoluteAmount = transaction.getAmount().abs();
            if (isEssential(transaction)) {
                totalEssential = totalEssential.add(absoluteAmount);
            } else {
                totalDiscretionary = totalDiscretionary.add(absoluteAmount);
            }
        }

        BigDecimal dailyEssential = totalEssential.divide(BigDecimal.valueOf(LOOKBACK_DAYS), 2, RoundingMode.HALF_UP);
        BigDecimal dailyDiscretionary = totalDiscretionary.divide(BigDecimal.valueOf(LOOKBACK_DAYS), 2, RoundingMode.HALF_UP);

        Map<DayOfWeek, BigDecimal> essentialMultipliers = computeWeekdayMultipliers(
                expenses.stream().filter(this::isEssential).toList(),
                referenceDate
        );
        Map<DayOfWeek, BigDecimal> discretionaryMultipliers = computeWeekdayMultipliers(
                expenses.stream().filter(transaction -> !isEssential(transaction)).toList(),
                referenceDate
        );
        BigDecimal volatility = computeVolatility(expenses, referenceDate);

        return new SpendProfile(
                dailyEssential,
                dailyDiscretionary,
                essentialMultipliers,
                discretionaryMultipliers,
                volatility,
                excludedRecurringKeys
        );
    }

    private List<Transaction> loadExpenses(Long userId, LocalDate referenceDate) {
        LocalDateTime windowStart = referenceDate.minusDays(LOOKBACK_DAYS - 1L).atStartOfDay();
        LocalDateTime windowEnd = referenceDate.atTime(23, 59, 59);
        return transactionRepository.findByUserIdAndAccountTypeAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                userId,
                AccountType.MAIN,
                TransactionStatus.COMPLETED,
                windowStart,
                windowEnd
        ).stream()
                .filter(transaction -> transaction.getAmount().compareTo(BigDecimal.ZERO) < 0)
                .toList();
    }

    private boolean isEssential(Transaction transaction) {
        if (transaction.getEssentiality() == SpendEssentiality.ESSENTIAL) {
            return true;
        }
        if (transaction.getEssentiality() == SpendEssentiality.DISCRETIONARY) {
            return false;
        }
        String normalized = ((transaction.getTitle() != null ? transaction.getTitle() : "") + " "
                + (transaction.getCategory() != null ? transaction.getCategory() : "")).toLowerCase(Locale.ROOT);
        return containsAny(
                normalized,
                "продукт", "еда", "food", "grocery", "супермаркет", "магазин",
                "аптек", "здоров", "health",
                "транспорт", "такси", "автобус", "метро", "бензин", "азс", "transport",
                "аренд", "коммунал", "жкх", "электр", "газ", "вода",
                "мобиль", "связь", "интернет", "подпис"
        );
    }

    private Map<DayOfWeek, BigDecimal> computeWeekdayMultipliers(List<Transaction> expenses, LocalDate referenceDate) {
        Map<DayOfWeek, BigDecimal> dailyTotals = new EnumMap<>(DayOfWeek.class);
        Map<DayOfWeek, Integer> dayCounts = new EnumMap<>(DayOfWeek.class);

        for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
            dailyTotals.put(dayOfWeek, BigDecimal.ZERO);
            dayCounts.put(dayOfWeek, 0);
        }

        LocalDate startDate = referenceDate.minusDays(LOOKBACK_DAYS - 1L);
        for (LocalDate date = startDate; !date.isAfter(referenceDate); date = date.plusDays(1)) {
            dayCounts.merge(date.getDayOfWeek(), 1, Integer::sum);
        }

        for (Transaction transaction : expenses) {
            DayOfWeek dayOfWeek = transaction.getOccurredAt().getDayOfWeek();
            dailyTotals.merge(dayOfWeek, transaction.getAmount().abs(), BigDecimal::add);
        }

        Map<DayOfWeek, BigDecimal> averageByDay = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
            int count = dayCounts.getOrDefault(dayOfWeek, 1);
            averageByDay.put(
                    dayOfWeek,
                    count > 0
                            ? dailyTotals.get(dayOfWeek).divide(BigDecimal.valueOf(count), 4, RoundingMode.HALF_UP)
                            : BigDecimal.ZERO
            );
        }

        BigDecimal overallAverage = averageByDay.values().stream()
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(7), 4, RoundingMode.HALF_UP);

        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
            if (overallAverage.compareTo(BigDecimal.ZERO) == 0) {
                multipliers.put(dayOfWeek, BigDecimal.ONE);
            } else {
                multipliers.put(
                        dayOfWeek,
                        averageByDay.get(dayOfWeek).divide(overallAverage, 2, RoundingMode.HALF_UP)
                );
            }
        }
        return multipliers;
    }

    private BigDecimal computeVolatility(List<Transaction> expenses, LocalDate referenceDate) {
        Map<LocalDate, BigDecimal> dailySpend = expenses.stream()
                .collect(Collectors.groupingBy(
                        transaction -> transaction.getOccurredAt().toLocalDate(),
                        Collectors.reducing(BigDecimal.ZERO, transaction -> transaction.getAmount().abs(), BigDecimal::add)
                ));

        LocalDate startDate = referenceDate.minusDays(LOOKBACK_DAYS - 1L);
        List<BigDecimal> dailyValues = new java.util.ArrayList<>();
        for (LocalDate date = startDate; !date.isAfter(referenceDate); date = date.plusDays(1)) {
            dailyValues.add(dailySpend.getOrDefault(date, BigDecimal.ZERO));
        }

        if (dailyValues.size() < 2) {
            return BigDecimal.ZERO;
        }

        BigDecimal mean = dailyValues.stream()
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(dailyValues.size()), 4, RoundingMode.HALF_UP);
        if (mean.compareTo(BigDecimal.ZERO) == 0) {
            return BigDecimal.ZERO;
        }

        BigDecimal sumSquaredDiffs = dailyValues.stream()
                .map(value -> value.subtract(mean).pow(2))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal variance = sumSquaredDiffs.divide(BigDecimal.valueOf(dailyValues.size()), 4, RoundingMode.HALF_UP);
        BigDecimal stdDev = BigDecimal.valueOf(Math.sqrt(variance.doubleValue()));
        return stdDev.divide(mean, 2, RoundingMode.HALF_UP);
    }

    private boolean containsAny(String value, String... candidates) {
        for (String candidate : candidates) {
            if (value.contains(candidate)) {
                return true;
            }
        }
        return false;
    }

    public record SpendProfile(
            BigDecimal dailyEssentialSpend,
            BigDecimal dailyDiscretionarySpend,
            Map<DayOfWeek, BigDecimal> essentialWeekdayMultipliers,
            Map<DayOfWeek, BigDecimal> discretionaryWeekdayMultipliers,
            BigDecimal volatility,
            Set<String> excludedRecurringKeys
    ) {
        public BigDecimal dailyTotal() {
            return dailyEssentialSpend.add(dailyDiscretionarySpend);
        }

        public BigDecimal projectedSpend(DayOfWeek dayOfWeek) {
            return projectedEssentialSpend(dayOfWeek)
                    .add(projectedDiscretionarySpend(dayOfWeek))
                    .setScale(2, RoundingMode.HALF_UP);
        }

        public BigDecimal projectedEssentialSpend(DayOfWeek dayOfWeek) {
            BigDecimal multiplier = essentialWeekdayMultipliers.getOrDefault(dayOfWeek, BigDecimal.ONE);
            return dailyEssentialSpend.multiply(multiplier).setScale(2, RoundingMode.HALF_UP);
        }

        public BigDecimal projectedDiscretionarySpend(DayOfWeek dayOfWeek) {
            BigDecimal multiplier = discretionaryWeekdayMultipliers.getOrDefault(dayOfWeek, BigDecimal.ONE);
            return dailyDiscretionarySpend.multiply(multiplier).setScale(2, RoundingMode.HALF_UP);
        }

        public Map<DayOfWeek, BigDecimal> weekdayMultipliers() {
            Map<DayOfWeek, BigDecimal> merged = new EnumMap<>(DayOfWeek.class);
            for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
                BigDecimal total = projectedSpend(dayOfWeek);
                if (dailyTotal().compareTo(BigDecimal.ZERO) == 0) {
                    merged.put(dayOfWeek, BigDecimal.ONE);
                } else {
                    merged.put(dayOfWeek, total.divide(dailyTotal(), 2, RoundingMode.HALF_UP));
                }
            }
            return merged;
        }

        static SpendProfile zero() {
            Map<DayOfWeek, BigDecimal> ones = new EnumMap<>(DayOfWeek.class);
            for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
                ones.put(dayOfWeek, BigDecimal.ONE);
            }
            return new SpendProfile(BigDecimal.ZERO, BigDecimal.ZERO, ones, ones, BigDecimal.ZERO, Set.of());
        }
    }
}
