package com.example.hackathonbank.config;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.model.UserSettings;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import com.example.hackathonbank.repository.UserRepository;
import com.example.hackathonbank.repository.UserSettingsRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

@Configuration
public class DataSeederConfig {

    private static final BigDecimal TARGET_MAIN_BALANCE = new BigDecimal("15000.00");
    private static final BigDecimal SAVINGS_BALANCE = new BigDecimal("50000.00");
    private static final BigDecimal MAIN_START_CAPITAL = new BigDecimal("20000.00");

    @Bean
    public CommandLineRunner seedBankData(UserRepository userRepository,
                                          AccountRepository accountRepository,
                                          TransactionRepository transactionRepository,
                                          ScheduledPaymentRepository scheduledPaymentRepository,
                                          UserSettingsRepository userSettingsRepository) {
        return args -> {
            if (userRepository.count() > 0) {
                return;
            }

            User user = userRepository.save(new User("Azizkhan"));
            userSettingsRepository.save(new UserSettings(user, true, false, LocalDate.now()));

            Account mainAccount = accountRepository.save(
                    new Account(user, AccountType.MAIN, "Main", BigDecimal.ZERO, "KGS")
            );
            accountRepository.save(
                    new Account(user, AccountType.SAVINGS, "Savings", SAVINGS_BALANCE, "KGS")
            );

            LocalDateTime now = LocalDateTime.now().withSecond(0).withNano(0);
            Random random = new Random(42);
            List<Transaction> transactions = new ArrayList<>();

            seedRecurringIncomeTransactions(user, mainAccount, now, transactions);
            seedRecurringBills(user, mainAccount, now, transactions);
            seedLifestyleExpenses(user, mainAccount, now, random, transactions);
            seedRecentActivity(user, mainAccount, now, transactions);
            settleTargetBalanceWithRealisticEntries(user, mainAccount, now, transactions);

            transactionRepository.saveAll(transactions);
            seedUpcomingScheduledPayments(user, mainAccount, scheduledPaymentRepository);

            BigDecimal completedNet = transactions.stream()
                    .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                    .map(Transaction::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            mainAccount.setBalance(MAIN_START_CAPITAL.add(completedNet).setScale(2, RoundingMode.HALF_UP));
            accountRepository.save(mainAccount);
        };
    }

    private void seedRecurringIncomeTransactions(User user,
                                                 Account mainAccount,
                                                 LocalDateTime now,
                                                 List<Transaction> transactions) {
        transactions.add(transaction(
                user, mainAccount, null,
                "Зарплата", "Tech Corp",
                new BigDecimal("39000.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                salaryMoment(now.minusMonths(2))
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Зарплата", "Tech Corp",
                new BigDecimal("40500.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                salaryMoment(now.minusMonths(1))
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Подработка", "Nova Studio",
                new BigDecimal("6200.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusMonths(2).withDayOfMonth(27).withHour(14).withMinute(10)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Подработка", "Nova Studio",
                new BigDecimal("7500.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusMonths(1).withDayOfMonth(25).withHour(15).withMinute(20)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Возврат", "O! Store",
                new BigDecimal("1250.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusDays(19).withHour(11).withMinute(45)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Кэшбэк", "MBank bonus",
                new BigDecimal("2400.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusDays(24).withHour(9).withMinute(25)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Перевод от семьи", "Aman",
                new BigDecimal("1900.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusDays(33).withHour(20).withMinute(15)
        ));
    }

    private void seedRecurringBills(User user,
                                    Account mainAccount,
                                    LocalDateTime now,
                                    List<Transaction> transactions) {
        for (int monthsAgo = 2; monthsAgo >= 1; monthsAgo--) {
            LocalDate month = now.toLocalDate().minusMonths(monthsAgo).withDayOfMonth(1);
            transactions.add(transaction(
                    user, mainAccount, null,
                    "Аренда", "Landlord",
                    new BigDecimal("-18000.00"),
                    "Аренда", "home",
                    TransactionType.PURCHASE, TransactionStatus.COMPLETED,
                    businessDayMoment(month.plusDays(1), 10, 15)
            ));
            transactions.add(transaction(
                    user, mainAccount, null,
                    "Коммунальные услуги", "БишкекЭнерго",
                    monthsAgo == 2 ? new BigDecimal("-4650.00") : new BigDecimal("-4920.00"),
                    "Коммунальные", "utilities",
                    TransactionType.PURCHASE, TransactionStatus.COMPLETED,
                    businessDayMoment(month.plusDays(4), 11, 40)
            ));
            transactions.add(transaction(
                    user, mainAccount, null,
                    "Интернет", "HomeNet",
                    new BigDecimal("-1250.00"),
                    "Подписки", "subscription",
                    TransactionType.PURCHASE, TransactionStatus.COMPLETED,
                    businessDayMoment(month.plusDays(7), 9, 30)
            ));
            transactions.add(transaction(
                    user, mainAccount, null,
                    "Мобильная связь", "O!",
                    monthsAgo == 2 ? new BigDecimal("-540.00") : new BigDecimal("-580.00"),
                    "Подписки", "subscription",
                    TransactionType.PURCHASE, TransactionStatus.COMPLETED,
                    businessDayMoment(month.plusDays(10), 18, 5)
            ));
        }
    }

    private void seedLifestyleExpenses(User user,
                                       Account mainAccount,
                                       LocalDateTime now,
                                       Random random,
                                       List<Transaction> transactions) {
        List<TransactionSeed> weekdayPool = List.of(
                new TransactionSeed("Супермаркет", "Глобус", "Еда", "food", TransactionType.PURCHASE, 450, 3200),
                new TransactionSeed("Обед", "VTS GTS Canteen", "Еда", "food", TransactionType.PURCHASE, 120, 380),
                new TransactionSeed("Яндекс Go", "Yandex Go", "Транспорт", "transport", TransactionType.PURCHASE, 180, 900),
                new TransactionSeed("Оплата по QR", "Тулпар", "Транспорт", "qr", TransactionType.QR_TRANSFER, 17, 75),
                new TransactionSeed("Аптека", "Аптека 312", "Здоровье", "health", TransactionType.PURCHASE, 230, 1800),
                new TransactionSeed("Перевод", "Aigerim", "Переводы", "transfer", TransactionType.TRANSFER, 700, 4200),
                new TransactionSeed("Кофейня", "Coffee Room", "Еда", "food", TransactionType.PURCHASE, 180, 850)
        );
        List<TransactionSeed> weekendPool = List.of(
                new TransactionSeed("Ресторан", "Navat", "Рестораны", "food", TransactionType.PURCHASE, 1100, 4600),
                new TransactionSeed("АЗС", "Газпромнефть", "Транспорт", "transport", TransactionType.PURCHASE, 1800, 6500),
                new TransactionSeed("Маркетплейс", "Wildberries", "Покупки", "shopping", TransactionType.PURCHASE, 1500, 9500),
                new TransactionSeed("Кино", "Manas Cinema", "Развлечения", "entertainment", TransactionType.PURCHASE, 700, 1900),
                new TransactionSeed("Продукты", "Народный", "Еда", "food", TransactionType.PURCHASE, 900, 3600)
        );

        LocalDate startDate = now.toLocalDate().minusDays(84);
        LocalDate endDate = now.toLocalDate().minusDays(4);

        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            int expenseCount = expenseCountFor(date.getDayOfWeek(), random);
            for (int index = 0; index < expenseCount; index++) {
                transactions.add(randomExpense(user, mainAccount, date, weekdayPool, weekendPool, random));
            }
        }
    }

    private void seedRecentActivity(User user,
                                    Account mainAccount,
                                    LocalDateTime now,
                                    List<Transaction> transactions) {
        transactions.add(transaction(
                user, mainAccount, null,
                "Покупка", "VTS GTS*CANTIN STOLOVAYA, BISHKEK",
                new BigDecimal("-135.00"),
                "Еда", "food",
                TransactionType.PURCHASE, TransactionStatus.COMPLETED,
                now.minusDays(1).withHour(12).withMinute(36)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Оплата по QR", "Тулпар",
                new BigDecimal("-17.00"),
                "Транспорт", "qr",
                TransactionType.QR_TRANSFER, TransactionStatus.COMPLETED,
                now.minusDays(1).withHour(17).withMinute(23)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Покупка", "Минимаркет у дома",
                new BigDecimal("-63.00"),
                "Еда", "food",
                TransactionType.PURCHASE, TransactionStatus.COMPLETED,
                now.minusHours(7)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Перевод", "Visa *4451",
                new BigDecimal("-500.00"),
                "Переводы", "transfer",
                TransactionType.TRANSFER, TransactionStatus.COMPLETED,
                now.minusHours(3)
        ));
        transactions.add(transaction(
                user, mainAccount, null,
                "Возврат", "Корректировка платежа",
                new BigDecimal("630.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusDays(6).withHour(22).withMinute(47)
        ));
    }

    private void settleTargetBalanceWithRealisticEntries(User user,
                                                         Account mainAccount,
                                                         LocalDateTime now,
                                                         List<Transaction> transactions) {
        BigDecimal completedNet = transactions.stream()
                .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                .map(Transaction::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal delta = TARGET_MAIN_BALANCE.subtract(MAIN_START_CAPITAL.add(completedNet))
                .setScale(2, RoundingMode.HALF_UP);
        if (delta.signum() == 0) {
            return;
        }

        List<TransactionSeed> expenseTemplates = List.of(
                new TransactionSeed("Маркетплейс", "Wildberries", "Покупки", "shopping", TransactionType.PURCHASE, 1200, 8000),
                new TransactionSeed("Подарки", "Детский мир", "Покупки", "shopping", TransactionType.PURCHASE, 900, 6500),
                new TransactionSeed("Техника для дома", "Technodom", "Покупки", "shopping", TransactionType.PURCHASE, 1800, 14000)
        );
        List<TransactionSeed> incomeTemplates = List.of(
                new TransactionSeed("Подработка", "Nova Studio", "Поступления", "income", TransactionType.INCOME, 1500, 12000),
                new TransactionSeed("Продажа вещей", "Lalafo", "Поступления", "income", TransactionType.INCOME, 1200, 9000),
                new TransactionSeed("Перевод от семьи", "Aman", "Поступления", "income", TransactionType.INCOME, 1000, 7000)
        );

        List<TransactionSeed> templates = delta.signum() < 0 ? expenseTemplates : incomeTemplates;
        BigDecimal remaining = delta.abs();
        int index = 0;

        while (remaining.compareTo(BigDecimal.ZERO) > 0) {
            TransactionSeed seed = templates.get(index % templates.size());
            BigDecimal chunk = suggestedChunk(seed, remaining);
            BigDecimal signedAmount = delta.signum() < 0 ? chunk.negate() : chunk;
            LocalDateTime occurredAt = now.minusDays(9L + (index * 6L))
                    .withHour(delta.signum() < 0 ? 19 : 13)
                    .withMinute((12 + index * 11) % 60);

            transactions.add(transaction(
                    user,
                    mainAccount,
                    null,
                    seed.title,
                    seed.counterparty,
                    signedAmount,
                    seed.category,
                    seed.iconKey,
                    seed.type,
                    TransactionStatus.COMPLETED,
                    occurredAt
            ));

            remaining = remaining.subtract(chunk);
            index++;
        }
    }

    private void seedUpcomingScheduledPayments(User user,
                                               Account mainAccount,
                                               ScheduledPaymentRepository scheduledPaymentRepository) {
        scheduledPaymentRepository.saveAll(List.of(
                new ScheduledPayment(
                        user,
                        mainAccount,
                        "Аренда",
                        "Landlord",
                        new BigDecimal("25000.00"),
                        "Аренда",
                        "home",
                        LocalDate.now().plusDays(4),
                        true,
                        PaymentStatus.SCHEDULED
                ),
                new ScheduledPayment(
                        user,
                        mainAccount,
                        "Коммунальные",
                        "БишкекЭнерго",
                        new BigDecimal("7800.00"),
                        "Коммунальные",
                        "utilities",
                        LocalDate.now().plusDays(8),
                        true,
                        PaymentStatus.SCHEDULED
                ),
                new ScheduledPayment(
                        user,
                        mainAccount,
                        "Интернет",
                        "HomeNet",
                        new BigDecimal("3900.00"),
                        "Подписки",
                        "subscription",
                        LocalDate.now().plusDays(11),
                        true,
                        PaymentStatus.SCHEDULED
                )
        ));
    }

    private int expenseCountFor(DayOfWeek dayOfWeek, Random random) {
        boolean weekend = dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY;
        int count = 0;
        if (random.nextDouble() < (weekend ? 0.62 : 0.48)) {
            count++;
        }
        if (random.nextDouble() < (weekend ? 0.22 : 0.12)) {
            count++;
        }
        return count;
    }

    private Transaction randomExpense(User user,
                                      Account mainAccount,
                                      LocalDate date,
                                      List<TransactionSeed> weekdayPool,
                                      List<TransactionSeed> weekendPool,
                                      Random random) {
        List<TransactionSeed> pool = switch (date.getDayOfWeek()) {
            case SATURDAY, SUNDAY -> weekendPool;
            default -> weekdayPool;
        };
        TransactionSeed seed = pool.get(random.nextInt(pool.size()));
        int amount = seed.minAmount + random.nextInt(seed.maxAmount - seed.minAmount + 1);
        LocalDateTime occurredAt = date.atTime(8 + random.nextInt(13), random.nextInt(60));

        return transaction(
                user,
                mainAccount,
                null,
                seed.title,
                seed.counterparty,
                BigDecimal.valueOf(amount).negate(),
                seed.category,
                seed.iconKey,
                seed.type,
                TransactionStatus.COMPLETED,
                occurredAt
        );
    }

    private BigDecimal suggestedChunk(TransactionSeed seed, BigDecimal remaining) {
        BigDecimal preferred = BigDecimal.valueOf(Math.max(seed.minAmount, seed.maxAmount - 600L));
        return remaining.min(preferred).setScale(2, RoundingMode.HALF_UP);
    }

    private LocalDateTime salaryMoment(LocalDateTime monthAnchor) {
        LocalDate salaryDate = monthAnchor.toLocalDate().withDayOfMonth(15);
        if (salaryDate.getDayOfWeek() == DayOfWeek.SATURDAY) {
            salaryDate = salaryDate.minusDays(1);
        } else if (salaryDate.getDayOfWeek() == DayOfWeek.SUNDAY) {
            salaryDate = salaryDate.minusDays(2);
        }
        return salaryDate.atTime(9, 0);
    }

    private LocalDateTime businessDayMoment(LocalDate date, int hour, int minute) {
        LocalDate normalized = date;
        if (normalized.getDayOfWeek() == DayOfWeek.SATURDAY) {
            normalized = normalized.plusDays(2);
        } else if (normalized.getDayOfWeek() == DayOfWeek.SUNDAY) {
            normalized = normalized.plusDays(1);
        }
        return normalized.atTime(hour, minute);
    }

    private Transaction transaction(User user,
                                    Account account,
                                    ScheduledPayment scheduledPayment,
                                    String title,
                                    String counterparty,
                                    BigDecimal amount,
                                    String category,
                                    String iconKey,
                                    TransactionType type,
                                    TransactionStatus status,
                                    LocalDateTime occurredAt) {
        return new Transaction(
                user,
                account,
                scheduledPayment,
                title,
                counterparty,
                amount.setScale(2, RoundingMode.HALF_UP),
                category,
                iconKey,
                type,
                status,
                occurredAt
        );
    }

    private record TransactionSeed(String title,
                                   String counterparty,
                                   String category,
                                   String iconKey,
                                   TransactionType type,
                                   int minAmount,
                                   int maxAmount) {
    }
}
