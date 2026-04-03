package com.example.hackathonbank.service;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.TransactionRepository;
import com.example.hackathonbank.service.IncomeCalendarService.IncomeCalendar;
import com.example.hackathonbank.service.IncomeCalendarService.IncomeCluster;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class IncomeCalendarServiceTests {

    private static final Long USER_ID = 1L;
    private static final LocalDate REF_DATE = LocalDate.of(2026, 3, 20);

    @Mock
    private TransactionRepository transactionRepository;

    private IncomeCalendarService service;
    private User user;
    private Account account;

    @BeforeEach
    void setUp() {
        service = new IncomeCalendarService(transactionRepository);
        user = new User("TestUser");
        ReflectionTestUtils.setField(user, "id", USER_ID);
        account = new Account(user, AccountType.MAIN, "Main", new BigDecimal("100000.00"), "KGS");
        ReflectionTestUtils.setField(account, "id", 1L);
    }

    @Test
    void emptyTransactionsReturnsFallbackDate() {
        stubIncomes(List.of());

        IncomeCalendar calendar = service.buildCalendar(USER_ID, REF_DATE);

        assertThat(calendar.nextExpectedDate()).isEqualTo(REF_DATE.plusDays(14));
        assertThat(calendar.confidencePercent()).isZero();
        assertThat(calendar.clusters()).isEmpty();
    }

    @Test
    void singleSalaryCreatesClusterWithLowConfidence() {
        stubIncomes(List.of(
                income("Зарплата", "2026-02-15T10:00:00", "40000.00")
        ));

        IncomeCalendar calendar = service.buildCalendar(USER_ID, REF_DATE);

        assertThat(calendar.clusters()).hasSize(1);
        IncomeCluster cluster = calendar.clusters().get(0);
        assertThat(cluster.type()).isEqualTo(IncomeType.SALARY);
        assertThat(cluster.confidence()).isEqualTo(33.0);
        assertThat(cluster.dayOfMonth()).isEqualTo(15);
    }

    @Test
    void repeatedSalaryOnSameDayGivesHighConfidence() {
        stubIncomes(List.of(
                income("Зарплата", "2026-01-15T10:00:00", "40000.00"),
                income("Зарплата", "2026-02-15T10:00:00", "40000.00")
        ));

        IncomeCalendar calendar = service.buildCalendar(USER_ID, REF_DATE);

        assertThat(calendar.clusters()).hasSize(1);
        IncomeCluster cluster = calendar.clusters().get(0);
        assertThat(cluster.confidence()).isEqualTo(66.0);
        assertThat(calendar.nextExpectedDate()).isEqualTo(LocalDate.of(2026, 4, 15));
    }

    @Test
    void mixedIncomesClassifiedCorrectly() {
        stubIncomes(List.of(
                income("Зарплата", "2026-02-15T10:00:00", "50000.00"),
                income("Фриланс", "2026-02-22T10:00:00", "10000.00"),
                income("Возврат за товар", "2026-03-01T10:00:00", "1500.00")
        ));

        IncomeCalendar calendar = service.buildCalendar(USER_ID, REF_DATE);

        List<IncomeType> types = calendar.clusters().stream()
                .map(IncomeCluster::type)
                .toList();
        assertThat(types).contains(IncomeType.SALARY);
        assertThat(types).contains(IncomeType.FREELANCE);
    }

    @Test
    void dayToleranceMergesNearbyDays() {
        stubIncomes(List.of(
                income("Зарплата", "2026-01-14T10:00:00", "40000.00"),
                income("Зарплата", "2026-02-16T10:00:00", "40000.00")
        ));

        IncomeCalendar calendar = service.buildCalendar(USER_ID, REF_DATE);

        assertThat(calendar.clusters()).hasSize(1);
        IncomeCluster cluster = calendar.clusters().get(0);
        assertThat(cluster.occurrences()).isEqualTo(2);
    }

    @Test
    void refundsAndCashbackClassifiedAsRefund() {
        stubIncomes(List.of(
                income("Возврат средств", "2026-03-01T10:00:00", "2000.00"),
                income("Кэшбэк за покупки", "2026-03-05T10:00:00", "500.00")
        ));

        IncomeCalendar calendar = service.buildCalendar(USER_ID, REF_DATE);

        List<IncomeType> allTypes = calendar.clusters().stream()
                .map(IncomeCluster::type)
                .toList();
        assertThat(allTypes).containsOnly(IncomeType.REFUND);
    }

    private void stubIncomes(List<Transaction> transactions) {
        when(transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                eq(USER_ID),
                eq(TransactionStatus.COMPLETED),
                any(LocalDateTime.class),
                any(LocalDateTime.class)
        )).thenReturn(transactions);
    }

    private Transaction income(String title, String occurredAt, String amount) {
        return new Transaction(
                user,
                account,
                null,
                title,
                title,
                new BigDecimal(amount),
                "Income",
                "income",
                TransactionType.INCOME,
                TransactionStatus.COMPLETED,
                LocalDateTime.parse(occurredAt)
        );
    }
}
