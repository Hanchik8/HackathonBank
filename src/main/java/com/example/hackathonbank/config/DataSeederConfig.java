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

            seedIncomeTransactions(user, mainAccount, now, transactions);
            seedExpenseTransactions(user, mainAccount, now, random, transactions);
            seedRecentActivity(user, mainAccount, now, transactions);
            alignMainBalance(user, mainAccount, now, transactions);

            ScheduledPayment rentPayment = scheduledPaymentRepository.save(
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
                    )
            );
            transactions.add(scheduledTransaction(user, mainAccount, rentPayment));

            ScheduledPayment utilitiesPayment = scheduledPaymentRepository.save(
                    new ScheduledPayment(
                            user,
                            mainAccount,
                            "Коммунальные",
                            "БишкекЭнерго",
                            new BigDecimal("7800.00"),
                            "Коммунальные",
                            "home",
                            LocalDate.now().plusDays(8),
                            true,
                            PaymentStatus.SCHEDULED
                    )
            );
            transactions.add(scheduledTransaction(user, mainAccount, utilitiesPayment));

            ScheduledPayment internetPayment = scheduledPaymentRepository.save(
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
            );
            transactions.add(scheduledTransaction(user, mainAccount, internetPayment));

            transactionRepository.saveAll(transactions);

            BigDecimal completedNet = transactions.stream()
                    .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                    .map(Transaction::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            mainAccount.setBalance(MAIN_START_CAPITAL.add(completedNet).setScale(2, RoundingMode.HALF_UP));
            accountRepository.save(mainAccount);
        };
    }

    private void seedIncomeTransactions(User user,
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
                "Фриланс", "Nova Studio",
                new BigDecimal("4500.00"),
                "Поступления", "income",
                TransactionType.INCOME, TransactionStatus.COMPLETED,
                now.minusDays(12).withHour(14).withMinute(10)
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
                now.minusDays(3).withHour(9).withMinute(25)
        ));
    }

    private void seedExpenseTransactions(User user,
                                         Account mainAccount,
                                         LocalDateTime now,
                                         Random random,
                                         List<Transaction> transactions) {
        List<TransactionSeed> weekdayPool = List.of(
                new TransactionSeed("Яндекс.Такси", "Яндекс Go", "Транспорт", "transport", TransactionType.PURCHASE, 180, 1450),
                new TransactionSeed("Супермаркет", "Пятерочка", "Еда", "food", TransactionType.PURCHASE, 450, 4200),
                new TransactionSeed("Аптека", "Аптека 312", "Здоровье", "health", TransactionType.PURCHASE, 250, 2400),
                new TransactionSeed("Обед", "VTS GTS Canteen", "Еда", "food", TransactionType.PURCHASE, 120, 850),
                new TransactionSeed("Оплата по QR", "Тулпар", "Транспорт", "qr", TransactionType.QR_TRANSFER, 17, 120),
                new TransactionSeed("Мобильная связь", "O!", "Подписки", "subscription", TransactionType.PURCHASE, 320, 1400),
                new TransactionSeed("Перевод", "Aigerim", "Переводы", "transfer", TransactionType.TRANSFER, 800, 6500),
                new TransactionSeed("Маркетплейс", "Wildberries", "Покупки", "shopping", TransactionType.PURCHASE, 1900, 14500)
        );
        List<TransactionSeed> weekendPool = List.of(
                new TransactionSeed("Ресторан", "Navat", "Рестораны", "food", TransactionType.PURCHASE, 1200, 7200),
                new TransactionSeed("Кино", "Manas Cinema", "Развлечения", "entertainment", TransactionType.PURCHASE, 900, 2800),
                new TransactionSeed("АЗС", "Газпромнефть", "Транспорт", "transport", TransactionType.PURCHASE, 3200, 9500),
                new TransactionSeed("Маркетплейс", "Kaspi Shop", "Покупки", "shopping", TransactionType.PURCHASE, 2500, 17000),
                new TransactionSeed("Кофейня", "Coffee Room", "Еда", "food", TransactionType.PURCHASE, 180, 1300)
        );

        LocalDate startDate = now.toLocalDate().minusDays(84);
        LocalDate endDate = now.toLocalDate().minusDays(5);

        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            if (random.nextDouble() < 0.42) {
                transactions.add(randomExpense(user, mainAccount, date, weekdayPool, weekendPool, random));
            }
            if (random.nextDouble() < 0.16) {
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

    private void alignMainBalance(User user,
                                  Account mainAccount,
                                  LocalDateTime now,
                                  List<Transaction> transactions) {
        BigDecimal completedNet = transactions.stream()
                .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                .map(Transaction::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal currentBalance = MAIN_START_CAPITAL.add(completedNet);
        BigDecimal delta = TARGET_MAIN_BALANCE.subtract(currentBalance);
        if (delta.signum() == 0) {
            return;
        }

        transactions.add(transaction(
                user,
                mainAccount,
                null,
                delta.signum() > 0 ? "Возврат после сверки" : "Покупка техники",
                delta.signum() > 0 ? "MBank Support" : "Technodom",
                delta,
                delta.signum() > 0 ? "Поступления" : "Покупки",
                delta.signum() > 0 ? "income" : "shopping",
                delta.signum() > 0 ? TransactionType.INCOME : TransactionType.PURCHASE,
                TransactionStatus.COMPLETED,
                now.minusHours(2)
        ));
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

    private LocalDateTime salaryMoment(LocalDateTime monthAnchor) {
        LocalDate salaryDate = monthAnchor.toLocalDate().withDayOfMonth(15);
        if (salaryDate.getDayOfWeek() == DayOfWeek.SATURDAY) {
            salaryDate = salaryDate.minusDays(1);
        } else if (salaryDate.getDayOfWeek() == DayOfWeek.SUNDAY) {
            salaryDate = salaryDate.minusDays(2);
        }
        return salaryDate.atTime(9, 0);
    }

    private Transaction scheduledTransaction(User user, Account account, ScheduledPayment payment) {
        return transaction(
                user,
                account,
                payment,
                "Автоплатеж: " + payment.getTitle(),
                payment.getCounterparty(),
                payment.getAmount().negate(),
                payment.getCategory(),
                payment.getIconKey(),
                TransactionType.AUTO_PAYMENT,
                TransactionStatus.SCHEDULED,
                payment.getDueDate().atTime(9, 0)
        );
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
