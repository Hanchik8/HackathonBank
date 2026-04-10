package com.example.hackathonbank.service;

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
        List<Transaction> expenses = loadExpenses(userId, referenceDate);
        if (expenses.isEmpty()) {
            return SpendProfile.zero();
        }

        BigDecimal totalEssential = BigDecimal.ZERO;
        BigDecimal totalDiscretionary = BigDecimal.ZERO;

        for (Transaction t : expenses) {
            BigDecimal absAmount = t.getAmount().abs();
            if (isEssential(t)) {
                totalEssential = totalEssential.add(absAmount);
            } else {
                totalDiscretionary = totalDiscretionary.add(absAmount);
            }
        }

        BigDecimal dailyEssential = totalEssential.divide(BigDecimal.valueOf(LOOKBACK_DAYS), 2, RoundingMode.HALF_UP);
        BigDecimal dailyDiscretionary = totalDiscretionary.divide(BigDecimal.valueOf(LOOKBACK_DAYS), 2, RoundingMode.HALF_UP);

        Map<DayOfWeek, BigDecimal> weekdayMultipliers = computeWeekdayMultipliers(expenses, referenceDate);
        BigDecimal volatility = computeVolatility(expenses, referenceDate);

        return new SpendProfile(dailyEssential, dailyDiscretionary, weekdayMultipliers, volatility);
    }

    private List<Transaction> loadExpenses(Long userId, LocalDate referenceDate) {
        LocalDateTime windowStart = referenceDate.minusDays(LOOKBACK_DAYS - 1L).atStartOfDay();
        LocalDateTime windowEnd = referenceDate.atTime(23, 59, 59);
        return transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                userId, TransactionStatus.COMPLETED, windowStart, windowEnd
        ).stream()
                .filter(t -> t.getAmount().compareTo(BigDecimal.ZERO) < 0)
                .toList();
    }

    private boolean isEssential(Transaction t) {
        String normalized = ((t.getTitle() != null ? t.getTitle() : "") + " "
                + (t.getCategory() != null ? t.getCategory() : "")).toLowerCase(Locale.ROOT);
        return containsAny(normalized,
                "продукт", "еда", "food", "grocery", "супермаркет", "магазин",
                "аптек", "здоровь", "health",
                "транспорт", "такси", "автобус", "метро", "бензин", "азс", "transport",
                "аренд", "коммунал", "жкх", "электричеств",
                "мобиль", "связь", "интернет", "подпис");
    }

    private Map<DayOfWeek, BigDecimal> computeWeekdayMultipliers(List<Transaction> expenses, LocalDate referenceDate) {
        Map<DayOfWeek, BigDecimal> dailyTotals = new EnumMap<>(DayOfWeek.class);
        Map<DayOfWeek, Integer> dayCounts = new EnumMap<>(DayOfWeek.class);

        for (DayOfWeek dow : DayOfWeek.values()) {
            dailyTotals.put(dow, BigDecimal.ZERO);
            dayCounts.put(dow, 0);
        }

        LocalDate startDate = referenceDate.minusDays(LOOKBACK_DAYS - 1L);
        for (LocalDate d = startDate; !d.isAfter(referenceDate); d = d.plusDays(1)) {
            dayCounts.merge(d.getDayOfWeek(), 1, Integer::sum);
        }

        for (Transaction t : expenses) {
            DayOfWeek dow = t.getOccurredAt().getDayOfWeek();
            dailyTotals.merge(dow, t.getAmount().abs(), BigDecimal::add);
        }

        Map<DayOfWeek, BigDecimal> averageByDay = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dow : DayOfWeek.values()) {
            int count = dayCounts.getOrDefault(dow, 1);
            averageByDay.put(dow, count > 0
                    ? dailyTotals.get(dow).divide(BigDecimal.valueOf(count), 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO);
        }

        BigDecimal overallAverage = averageByDay.values().stream()
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(7), 4, RoundingMode.HALF_UP);

        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dow : DayOfWeek.values()) {
            if (overallAverage.compareTo(BigDecimal.ZERO) == 0) {
                multipliers.put(dow, BigDecimal.ONE);
            } else {
                multipliers.put(dow, averageByDay.get(dow)
                        .divide(overallAverage, 2, RoundingMode.HALF_UP));
            }
        }
        return multipliers;
    }

    private BigDecimal computeVolatility(List<Transaction> expenses, LocalDate referenceDate) {
        Map<LocalDate, BigDecimal> dailySpend = expenses.stream()
                .collect(Collectors.groupingBy(
                        t -> t.getOccurredAt().toLocalDate(),
                        Collectors.reducing(BigDecimal.ZERO, t -> t.getAmount().abs(), BigDecimal::add)
                ));

        LocalDate startDate = referenceDate.minusDays(LOOKBACK_DAYS - 1L);
        List<BigDecimal> dailyValues = new java.util.ArrayList<>();
        for (LocalDate d = startDate; !d.isAfter(referenceDate); d = d.plusDays(1)) {
            dailyValues.add(dailySpend.getOrDefault(d, BigDecimal.ZERO));
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
                .map(v -> v.subtract(mean).pow(2))
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
            Map<DayOfWeek, BigDecimal> weekdayMultipliers,
            BigDecimal volatility
    ) {
        public BigDecimal dailyTotal() {
            return dailyEssentialSpend.add(dailyDiscretionarySpend);
        }

        public BigDecimal projectedSpend(DayOfWeek dayOfWeek) {
            BigDecimal multiplier = weekdayMultipliers.getOrDefault(dayOfWeek, BigDecimal.ONE);
            return dailyTotal().multiply(multiplier).setScale(2, RoundingMode.HALF_UP);
        }

        static SpendProfile zero() {
            Map<DayOfWeek, BigDecimal> ones = new EnumMap<>(DayOfWeek.class);
            for (DayOfWeek dow : DayOfWeek.values()) {
                ones.put(dow, BigDecimal.ONE);
            }
            return new SpendProfile(BigDecimal.ZERO, BigDecimal.ZERO, ones, BigDecimal.ZERO);
        }
    }
}
