package com.example.hackathonbank.service;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.TransactionRepository;
import com.example.hackathonbank.service.SpendProfileService.SpendProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SpendProfileServiceTests {

    private static final Long USER_ID = 1L;
    private static final LocalDate REF_DATE = LocalDate.of(2026, 3, 20);

    @Mock
    private TransactionRepository transactionRepository;

    private SpendProfileService service;
    private User user;
    private Account account;

    @BeforeEach
    void setUp() {
        service = new SpendProfileService(transactionRepository);
        user = new User("TestUser");
        ReflectionTestUtils.setField(user, "id", USER_ID);
        account = new Account(user, AccountType.MAIN, "Main", new BigDecimal("100000.00"), "KGS");
        ReflectionTestUtils.setField(account, "id", 1L);
    }

    @Test
    void emptyExpensesReturnsZeroProfile() {
        stubExpenses(List.of());

        SpendProfile profile = service.buildProfile(USER_ID, REF_DATE);

        assertThat(profile.dailyEssentialSpend()).isEqualByComparingTo("0");
        assertThat(profile.dailyDiscretionarySpend()).isEqualByComparingTo("0");
        assertThat(profile.volatility()).isEqualByComparingTo("0");
        for (DayOfWeek dow : DayOfWeek.values()) {
            assertThat(profile.weekdayMultipliers().get(dow)).isEqualByComparingTo("1");
        }
    }

    @Test
    void essentialExpensesClassifiedCorrectly() {
        stubExpenses(List.of(
                expense("Продукты Магнит", "2026-03-10T12:00:00", "1500.00"),
                expense("Такси Яндекс", "2026-03-12T09:00:00", "300.00")
        ));

        SpendProfile profile = service.buildProfile(USER_ID, REF_DATE);

        assertThat(profile.dailyEssentialSpend()).isGreaterThan(BigDecimal.ZERO);
    }

    @Test
    void discretionaryExpensesClassifiedCorrectly() {
        stubExpenses(List.of(
                expense("Развлечения ТРЦ", "2026-03-10T18:00:00", "2000.00"),
                expense("Кино IMAX", "2026-03-15T20:00:00", "800.00")
        ));

        SpendProfile profile = service.buildProfile(USER_ID, REF_DATE);

        assertThat(profile.dailyDiscretionarySpend()).isGreaterThan(BigDecimal.ZERO);
        assertThat(profile.dailyEssentialSpend()).isEqualByComparingTo("0");
    }

    @Test
    void weekdayMultipliersReflectActualSpending() {
        List<Transaction> expenses = new ArrayList<>();
        LocalDate start = REF_DATE.minusDays(29);
        for (LocalDate d = start; !d.isAfter(REF_DATE); d = d.plusDays(1)) {
            DayOfWeek dow = d.getDayOfWeek();
            String amount = (dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY)
                    ? "3000.00"
                    : "500.00";
            expenses.add(expense(
                    "Покупка",
                    d.atTime(12, 0).toString(),
                    amount
            ));
        }
        stubExpenses(expenses);

        SpendProfile profile = service.buildProfile(USER_ID, REF_DATE);

        BigDecimal satMultiplier = profile.weekdayMultipliers().get(DayOfWeek.SATURDAY);
        BigDecimal monMultiplier = profile.weekdayMultipliers().get(DayOfWeek.MONDAY);
        assertThat(satMultiplier).isGreaterThan(BigDecimal.ONE);
        assertThat(monMultiplier).isLessThan(BigDecimal.ONE);
    }

    @Test
    void volatilityComputedCorrectly() {
        List<Transaction> expenses = new ArrayList<>();
        LocalDate start = REF_DATE.minusDays(29);
        boolean toggle = false;
        for (LocalDate d = start; !d.isAfter(REF_DATE); d = d.plusDays(1)) {
            String amount = toggle ? "5000.00" : "100.00";
            expenses.add(expense("Покупка", d.atTime(12, 0).toString(), amount));
            toggle = !toggle;
        }
        stubExpenses(expenses);

        SpendProfile profile = service.buildProfile(USER_ID, REF_DATE);

        assertThat(profile.volatility()).isGreaterThan(BigDecimal.ZERO);
    }

    private void stubExpenses(List<Transaction> transactions) {
        when(transactionRepository.findByUserIdAndAccountTypeAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                eq(USER_ID),
                eq(AccountType.MAIN),
                eq(TransactionStatus.COMPLETED),
                any(LocalDateTime.class),
                any(LocalDateTime.class)
        )).thenReturn(transactions);
    }

    private Transaction expense(String title, String occurredAt, String amount) {
        return new Transaction(
                user,
                account,
                null,
                title,
                title,
                new BigDecimal(amount).negate(),
                "Expense",
                "shopping",
                TransactionType.PURCHASE,
                TransactionStatus.COMPLETED,
                LocalDateTime.parse(occurredAt)
        );
    }
}
