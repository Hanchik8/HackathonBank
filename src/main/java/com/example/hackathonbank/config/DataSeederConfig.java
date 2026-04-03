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
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Configuration
public class DataSeederConfig {

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
                    new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS")
            );
            accountRepository.save(
                    new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS")
            );

            LocalDateTime now = LocalDateTime.now().withSecond(0).withNano(0);
            List<Transaction> transactions = new ArrayList<>();

            transactions.add(transaction(user, mainAccount, null, "Зарплата", "Tech Corp", "118000.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(84)));
            transactions.add(transaction(user, mainAccount, null, "Аренда", "Landlord", "-25000.00", "Жилье", "home", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(83).plusHours(2)));
            transactions.add(transaction(user, mainAccount, null, "Супермаркет", "Globus", "-5400.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(80)));
            transactions.add(transaction(user, mainAccount, null, "Такси", "Yandex Go", "-1350.00", "Транспорт", "transport", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(79).plusHours(5)));
            transactions.add(transaction(user, mainAccount, null, "Ресторан", "Navat", "-4600.00", "Рестораны", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(77)));
            transactions.add(transaction(user, mainAccount, null, "Мобильная связь", "MegaCom", "-950.00", "Подписки", "subscription", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(74)));
            transactions.add(transaction(user, mainAccount, null, "Возврат", "O!", "1200.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(72).plusHours(4)));
            transactions.add(transaction(user, mainAccount, null, "Фитнес", "JFC Gym", "-3900.00", "Здоровье", "health", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(69)));

            transactions.add(transaction(user, mainAccount, null, "Зарплата", "Tech Corp", "121000.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(56)));
            transactions.add(transaction(user, mainAccount, null, "QR оплата", "Тулпар", "-17.00", "Транспорт", "qr", TransactionType.QR_TRANSFER, TransactionStatus.COMPLETED, now.minusDays(55).plusHours(7)));
            transactions.add(transaction(user, mainAccount, null, "Обед", "VTS GTS Canteen", "-100.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(54).plusHours(3)));
            transactions.add(transaction(user, mainAccount, null, "Маркетплейс", "Wildberries", "-8450.00", "Покупки", "shopping", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(51)));
            transactions.add(transaction(user, mainAccount, null, "Перевод другу", "Nurlan", "-2800.00", "Переводы", "transfer", TransactionType.TRANSFER, TransactionStatus.COMPLETED, now.minusDays(49)));
            transactions.add(transaction(user, mainAccount, null, "Кофе", "Adriano", "-280.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(46).plusHours(2)));
            transactions.add(transaction(user, mainAccount, null, "Кино", "Манас Cinema", "-1750.00", "Развлечения", "entertainment", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(44)));
            transactions.add(transaction(user, mainAccount, null, "Возврат за билет", "AirManas", "2300.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(41)));

            transactions.add(transaction(user, mainAccount, null, "Зарплата", "Tech Corp", "119500.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(28)));
            transactions.add(transaction(user, mainAccount, null, "АЗС", "Газпромнефть", "-5200.00", "Транспорт", "transport", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(27).plusHours(6)));
            transactions.add(transaction(user, mainAccount, null, "Ресторан", "Бублик", "-3250.00", "Рестораны", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(24)));
            transactions.add(transaction(user, mainAccount, null, "Супермаркет", "Фрунзе", "-6700.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(22)));
            transactions.add(transaction(user, mainAccount, null, "Подписка", "Spotify", "-299.00", "Подписки", "subscription", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(21)));
            transactions.add(transaction(user, mainAccount, null, "Зарплата", "Tech Corp", "120000.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(18)));
            transactions.add(transaction(user, mainAccount, null, "Продукты", "Green Market", "-6200.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(17)));
            transactions.add(transaction(user, mainAccount, null, "Кофе", "Coffee Room", "-1500.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(17).plusHours(5)));
            transactions.add(transaction(user, mainAccount, null, "QR перевод", "Aigerim", "-3500.00", "Переводы", "qr", TransactionType.QR_TRANSFER, TransactionStatus.COMPLETED, now.minusDays(16)));
            transactions.add(transaction(user, mainAccount, null, "Такси", "Yandex Go", "-2200.00", "Транспорт", "transport", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(15)));
            transactions.add(transaction(user, mainAccount, null, "Кино", "Kinoplexx", "-4800.00", "Развлечения", "entertainment", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(14)));
            transactions.add(transaction(user, mainAccount, null, "Интернет", "HomeNet", "-3900.00", "Подписки", "subscription", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(13)));
            transactions.add(transaction(user, mainAccount, null, "Аптека", "Europharma", "-2800.00", "Здоровье", "health", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(12)));
            transactions.add(transaction(user, mainAccount, null, "АЗС", "Sinooil", "-9000.00", "Транспорт", "transport", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(11)));
            transactions.add(transaction(user, mainAccount, null, "Фриланс", "Freelance client", "35000.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(10)));
            transactions.add(transaction(user, mainAccount, null, "Ресторан", "Pinsa", "-7200.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(9)));
            transactions.add(transaction(user, mainAccount, null, "Стриминг", "Movie+", "-1990.00", "Подписки", "subscription", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(8)));
            transactions.add(transaction(user, mainAccount, null, "Маркетплейс", "Kaspi Shop", "-14500.00", "Покупки", "shopping", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(7)));
            transactions.add(transaction(user, mainAccount, null, "QR перевод", "Daniyar", "-5400.00", "Переводы", "qr", TransactionType.QR_TRANSFER, TransactionStatus.COMPLETED, now.minusDays(6)));
            transactions.add(transaction(user, mainAccount, null, "Супермаркет", "Magnum", "-8100.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(5)));
            transactions.add(transaction(user, mainAccount, null, "Автобус", "Onay", "-850.00", "Транспорт", "transport", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(4)));
            transactions.add(transaction(user, mainAccount, null, "Мобильная связь", "Beeline", "-2000.00", "Подписки", "subscription", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusDays(3)));
            transactions.add(transaction(user, mainAccount, null, "Подарок", "Friend", "-6000.00", "Развлечения", "gift", TransactionType.TRANSFER, TransactionStatus.COMPLETED, now.minusDays(2)));
            transactions.add(transaction(user, mainAccount, null, "Кэшбэк", "Bank bonus", "2400.00", "Поступления", "income", TransactionType.INCOME, TransactionStatus.COMPLETED, now.minusDays(1).minusHours(3)));
            transactions.add(transaction(user, mainAccount, null, "Оплата по QR", "Тулпар", "-17.00", "Транспорт", "qr", TransactionType.QR_TRANSFER, TransactionStatus.COMPLETED, now.minusDays(1).plusHours(2)));
            transactions.add(transaction(user, mainAccount, null, "Минимаркет", "У дома", "-680.00", "Еда", "food", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusHours(12)));
            transactions.add(transaction(user, mainAccount, null, "Покупка техники", "TechnoDom", "-12990.00", "Покупки", "shopping", TransactionType.PURCHASE, TransactionStatus.COMPLETED, now.minusHours(6)));

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
            transactions.add(transaction(user, mainAccount, rentPayment, "Автоплатеж: Аренда", "Landlord", "-25000.00", "Аренда", "home", TransactionType.AUTO_PAYMENT, TransactionStatus.SCHEDULED, rentPayment.getDueDate().atTime(9, 0)));

            ScheduledPayment utilitiesPayment = scheduledPaymentRepository.save(
                    new ScheduledPayment(
                            user,
                            mainAccount,
                            "Коммунальные",
                            "BishkekEnergo",
                            new BigDecimal("7800.00"),
                            "Коммунальные",
                            "home",
                            LocalDate.now().plusDays(8),
                            true,
                            PaymentStatus.SCHEDULED
                    )
            );
            transactions.add(transaction(user, mainAccount, utilitiesPayment, "Автоплатеж: Коммунальные", "BishkekEnergo", "-7800.00", "Коммунальные", "home", TransactionType.AUTO_PAYMENT, TransactionStatus.SCHEDULED, utilitiesPayment.getDueDate().atTime(10, 30)));

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
            transactions.add(transaction(user, mainAccount, internetPayment, "Автоплатеж: Интернет", "HomeNet", "-3900.00", "Подписки", "subscription", TransactionType.AUTO_PAYMENT, TransactionStatus.SCHEDULED, internetPayment.getDueDate().atTime(11, 15)));

            transactionRepository.saveAll(transactions);
        };
    }

    private Transaction transaction(User user,
                                    Account account,
                                    ScheduledPayment scheduledPayment,
                                    String title,
                                    String counterparty,
                                    String amount,
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
                new BigDecimal(amount),
                category,
                iconKey,
                type,
                status,
                occurredAt
        );
    }
}
