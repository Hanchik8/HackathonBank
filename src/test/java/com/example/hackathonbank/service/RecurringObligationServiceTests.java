package com.example.hackathonbank.service;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.TransactionRepository;
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
class RecurringObligationServiceTests {

    @Mock
    private TransactionRepository transactionRepository;

    private RecurringObligationService recurringObligationService;
    private User user;
    private Account account;

    @BeforeEach
    void setUp() {
        recurringObligationService = new RecurringObligationService(transactionRepository);
        user = new User("TestUser");
        ReflectionTestUtils.setField(user, "id", 1L);
        account = new Account(user, AccountType.MAIN, "Main", new BigDecimal("100000.00"), "KGS");
        ReflectionTestUtils.setField(account, "id", 1L);
    }

    @Test
    void detectsRecurringEssentialBillFromHistory() {
        when(transactionRepository.findByUserIdAndAccountTypeAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                eq(1L),
                eq(AccountType.MAIN),
                eq(TransactionStatus.COMPLETED),
                any(LocalDateTime.class),
                any(LocalDateTime.class)
        )).thenReturn(List.of(
                expense("Коммунальные БишкекЭнерго", "2026-01-15T12:00:00", "3200.00"),
                expense("Коммунальные БишкекЭнерго", "2026-02-16T12:00:00", "3300.00"),
                expense("Коммунальные БишкекЭнерго", "2026-03-15T12:00:00", "3100.00")
        ));

        RecurringObligationService.RecurringObligationForecast forecast = recurringObligationService.buildForecast(
                1L,
                LocalDate.of(2026, 3, 20),
                LocalDate.of(2026, 4, 30),
                List.of()
        );

        assertThat(forecast.clusters()).hasSize(1);
        assertThat(forecast.events()).isNotEmpty();
        assertThat(forecast.clusters().get(0).confidencePercent()).isGreaterThanOrEqualTo(55);
    }

    @Test
    void skipsRecurringBillWhenConfirmedScheduledPaymentAlreadyExists() {
        ScheduledPayment scheduledPayment = new ScheduledPayment(
                user,
                account,
                "Коммунальные БишкекЭнерго",
                "Коммунальные БишкекЭнерго",
                new BigDecimal("3200.00"),
                "Коммунальные",
                "utilities",
                LocalDate.of(2026, 4, 15),
                true,
                PaymentStatus.SCHEDULED,
                false
        );

        when(transactionRepository.findByUserIdAndAccountTypeAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                eq(1L),
                eq(AccountType.MAIN),
                eq(TransactionStatus.COMPLETED),
                any(LocalDateTime.class),
                any(LocalDateTime.class)
        )).thenReturn(List.of(
                expense("Коммунальные БишкекЭнерго", "2026-01-15T12:00:00", "3200.00"),
                expense("Коммунальные БишкекЭнерго", "2026-02-16T12:00:00", "3300.00"),
                expense("Коммунальные БишкекЭнерго", "2026-03-15T12:00:00", "3100.00")
        ));

        RecurringObligationService.RecurringObligationForecast forecast = recurringObligationService.buildForecast(
                1L,
                LocalDate.of(2026, 3, 20),
                LocalDate.of(2026, 4, 30),
                List.of(scheduledPayment)
        );

        assertThat(forecast.clusters()).isEmpty();
        assertThat(forecast.events()).isEmpty();
    }

    private Transaction expense(String title, String occurredAt, String amount) {
        return new Transaction(
                user,
                account,
                null,
                title,
                title,
                new BigDecimal(amount).negate(),
                "Коммунальные",
                "utilities",
                TransactionType.AUTO_PAYMENT,
                TransactionStatus.COMPLETED,
                LocalDateTime.parse(occurredAt)
        );
    }
}
