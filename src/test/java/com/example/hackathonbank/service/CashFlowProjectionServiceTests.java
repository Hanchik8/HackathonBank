package com.example.hackathonbank.service;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CashFlowProjectionServiceTests {

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private ScheduledPaymentRepository scheduledPaymentRepository;

    @Mock
    private IncomeCalendarService incomeCalendarService;

    @Mock
    private SpendProfileService spendProfileService;

    @Mock
    private RecurringObligationService recurringObligationService;

    private CashFlowProjectionService cashFlowProjectionService;
    private User user;
    private Account main;
    private Account savings;

    @BeforeEach
    void setUp() {
        cashFlowProjectionService = new CashFlowProjectionService(
                accountRepository,
                scheduledPaymentRepository,
                incomeCalendarService,
                spendProfileService,
                recurringObligationService
        );
        user = new User("TestUser");
        ReflectionTestUtils.setField(user, "id", 1L);
        main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("10000.00"), "KGS");
        savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("5000.00"), "KGS");
    }

    @Test
    void projectionUsesOnlyMainScheduledPaymentsAndIncludesInferredBills() {
        ScheduledPayment mainPayment = new ScheduledPayment(
                user,
                main,
                "Аренда",
                "Аренда",
                new BigDecimal("3000.00"),
                "Аренда",
                "home",
                LocalDate.of(2026, 4, 12),
                true,
                PaymentStatus.SCHEDULED,
                false
        );
        ScheduledPayment savingsPayment = new ScheduledPayment(
                user,
                savings,
                "Savings bill",
                "Savings bill",
                new BigDecimal("2000.00"),
                "Misc",
                "calendar",
                LocalDate.of(2026, 4, 12),
                true,
                PaymentStatus.SCHEDULED,
                false
        );

        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
            multipliers.put(dayOfWeek, BigDecimal.ONE);
        }

        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));
        when(scheduledPaymentRepository.findByUserIdAndStatusInOrderByDueDateAsc(
                1L,
                List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED)
        )).thenReturn(List.of(mainPayment, savingsPayment));
        when(incomeCalendarService.buildCalendar(eq(1L), eq(LocalDate.of(2026, 4, 10))))
                .thenReturn(new IncomeCalendarService.IncomeCalendar(
                        List.of(),
                        new IncomeCalendarService.NextIncomeForecast(
                                LocalDate.of(2026, 4, 25),
                                LocalDate.of(2026, 4, 24),
                                LocalDate.of(2026, 4, 26),
                                new BigDecimal("90000.00"),
                                IncomeType.SALARY,
                                70
                        )
                ));
        when(incomeCalendarService.projectedIncomeEvents(
                eq(new IncomeCalendarService.IncomeCalendar(
                        List.of(),
                        new IncomeCalendarService.NextIncomeForecast(
                                LocalDate.of(2026, 4, 25),
                                LocalDate.of(2026, 4, 24),
                                LocalDate.of(2026, 4, 26),
                                new BigDecimal("90000.00"),
                                IncomeType.SALARY,
                                70
                        )
                )),
                eq(LocalDate.of(2026, 4, 11)),
                eq(LocalDate.of(2026, 4, 15)),
                eq(50)
        )).thenReturn(List.of());
        when(recurringObligationService.buildForecast(eq(1L), eq(LocalDate.of(2026, 4, 10)), eq(LocalDate.of(2026, 4, 15)), eq(List.of(mainPayment))))
                .thenReturn(new RecurringObligationService.RecurringObligationForecast(
                        List.of(),
                        List.of(new RecurringObligationService.ProjectedObligationEvent(
                                "internet|подписка",
                                "Интернет",
                                "Подписка",
                                new BigDecimal("500.00"),
                                new BigDecimal("400.00"),
                                LocalDate.of(2026, 4, 13),
                                70,
                                com.example.hackathonbank.model.SpendEssentiality.ESSENTIAL
                        )),
                        Set.of("internet")
                ));
        when(spendProfileService.buildProfile(eq(1L), eq(LocalDate.of(2026, 4, 10)), eq(Set.of("internet"))))
                .thenReturn(new SpendProfileService.SpendProfile(
                        new BigDecimal("100.00"),
                        new BigDecimal("50.00"),
                        multipliers,
                        multipliers,
                        BigDecimal.ZERO,
                        Set.of("internet")
                ));

        CashFlowProjectionService.CashFlowProjection projection = cashFlowProjectionService.buildProjection(
                1L,
                LocalDate.of(2026, 4, 10),
                5
        );

        assertThat(projection.confirmedPayments()).containsExactly(mainPayment);
        assertThat(projection.confirmedOutflowsTotal()).isEqualByComparingTo("3000.00");
        assertThat(projection.inferredOutflowsTotal()).isEqualByComparingTo("400.00");
        assertThat(projection.days()).hasSize(6);
        assertThat(projection.days().stream().anyMatch(day -> day.inferredOutflow().compareTo(BigDecimal.ZERO) > 0)).isTrue();
    }
}
