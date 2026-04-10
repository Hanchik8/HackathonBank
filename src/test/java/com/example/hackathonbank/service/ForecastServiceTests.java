package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ForecastServiceTests {

    @Mock
    private AccountService accountService;

    @Mock
    private ScheduledPaymentService scheduledPaymentService;

    @Mock
    private UserSettingsService userSettingsService;

    @Mock
    private UserContextService userContextService;

    @Mock
    private IncomeCalendarService incomeCalendarService;

    @Mock
    private SpendProfileService spendProfileService;

    @Mock
    private User currentUser;

    private ForecastService forecastService;

    @BeforeEach
    void setUp() {
        forecastService = new ForecastService(
                accountService,
                scheduledPaymentService,
                userSettingsService,
                userContextService,
                incomeCalendarService,
                spendProfileService
        );
    }

    @Test
    void buildDashboardUsesRequestedHorizonAndProducesNonLinearForecast() {
        LocalDate currentDate = LocalDate.of(2026, 3, 25);
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ScheduledPayment rent = new ScheduledPayment(
                user,
                main,
                "Аренда",
                new BigDecimal("25000.00"),
                "Аренда",
                currentDate.plusDays(4),
                PaymentStatus.SCHEDULED
        );

        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dow : DayOfWeek.values()) {
            multipliers.put(dow, BigDecimal.ONE);
        }
        SpendProfileService.SpendProfile spendProfile = new SpendProfileService.SpendProfile(
                new BigDecimal("80.00"),
                new BigDecimal("40.00"),
                multipliers,
                BigDecimal.ZERO
        );

        IncomeCalendarService.IncomeCalendar incomeCalendar = new IncomeCalendarService.IncomeCalendar(
                List.of(new IncomeCalendarService.IncomeCluster(
                        IncomeType.SALARY,
                        26,
                        new BigDecimal("5000.00"),
                        3,
                        85.0
                )),
                currentDate.plusDays(7),
                85,
                currentDate.plusDays(5),
                currentDate.plusDays(9)
        );

        when(userContextService.getCurrentUser()).thenReturn(currentUser);
        when(currentUser.getId()).thenReturn(99L);
        when(accountService.getAccountByType(AccountType.MAIN)).thenReturn(main);
        when(accountService.getAccountByType(AccountType.SAVINGS)).thenReturn(savings);
        when(scheduledPaymentService.getPendingPayments()).thenReturn(List.of(rent));
        when(userSettingsService.currentDate()).thenReturn(currentDate);
        when(incomeCalendarService.buildCalendar(eq(99L), eq(currentDate))).thenReturn(incomeCalendar);
        when(incomeCalendarService.projectedIncomeEvents(eq(incomeCalendar), eq(currentDate.plusDays(1)), eq(currentDate.plusDays(42)), eq(50)))
                .thenReturn(List.of(new IncomeCalendarService.ProjectedIncomeEvent(
                        IncomeType.SALARY,
                        currentDate.plusDays(1),
                        currentDate.plusDays(1),
                        currentDate.plusDays(3),
                        new BigDecimal("5000.00"),
                        85
                )));
        when(spendProfileService.buildProfile(eq(99L), eq(currentDate))).thenReturn(spendProfile);

        AiDashboardResponse dashboard = forecastService.buildDashboard(42);

        assertThat(dashboard.horizonDays()).isEqualTo(42);
        assertThat(dashboard.points()).hasSize(43);
        assertThat(dashboard.scheduledPayments()).hasSize(1);
        assertThat(dashboard.minimumProjectedBalance()).isLessThan(main.getBalance());

        List<BigDecimal> deltas = new ArrayList<>();
        for (int index = 1; index < dashboard.points().size(); index++) {
            deltas.add(dashboard.points().get(index).balance().subtract(dashboard.points().get(index - 1).balance()));
        }

        assertThat(deltas).anyMatch(delta -> delta.signum() < 0);
        assertThat(deltas).anyMatch(delta -> delta.signum() > 0);
    }

    @Test
    void incomeOnDay31AppearsInFebruaryForecast() {
        LocalDate currentDate = LocalDate.of(2026, 2, 15);
        User user = new User("TestUser");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("10000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("5000.00"), "KGS");

        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dow : DayOfWeek.values()) {
            multipliers.put(dow, BigDecimal.ONE);
        }
        SpendProfileService.SpendProfile spendProfile = new SpendProfileService.SpendProfile(
                new BigDecimal("50.00"), new BigDecimal("50.00"), multipliers, BigDecimal.ZERO
        );
        IncomeCalendarService.IncomeCalendar incomeCalendar = new IncomeCalendarService.IncomeCalendar(
                List.of(new IncomeCalendarService.IncomeCluster(
                        IncomeType.SALARY, 31, new BigDecimal("80000.00"), 3, 99.0
                )),
                LocalDate.of(2026, 2, 28), 99,
                LocalDate.of(2026, 2, 27), LocalDate.of(2026, 3, 1)
        );

        when(userContextService.getCurrentUser()).thenReturn(currentUser);
        when(currentUser.getId()).thenReturn(99L);
        when(accountService.getAccountByType(AccountType.MAIN)).thenReturn(main);
        when(accountService.getAccountByType(AccountType.SAVINGS)).thenReturn(savings);
        when(scheduledPaymentService.getPendingPayments()).thenReturn(List.of());
        when(userSettingsService.currentDate()).thenReturn(currentDate);
        when(incomeCalendarService.buildCalendar(eq(99L), eq(currentDate))).thenReturn(incomeCalendar);
        when(incomeCalendarService.projectedIncomeEvents(eq(incomeCalendar), eq(currentDate.plusDays(1)), eq(currentDate.plusDays(20)), eq(50)))
                .thenReturn(List.of(new IncomeCalendarService.ProjectedIncomeEvent(
                        IncomeType.SALARY,
                        LocalDate.of(2026, 2, 28),
                        LocalDate.of(2026, 2, 27),
                        LocalDate.of(2026, 3, 1),
                        new BigDecimal("80000.00"),
                        99
                )));
        when(spendProfileService.buildProfile(eq(99L), eq(currentDate))).thenReturn(spendProfile);

        AiDashboardResponse dashboard = forecastService.buildDashboard(20);

        boolean incomeDetected = false;
        for (int i = 1; i < dashboard.points().size(); i++) {
            BigDecimal delta = dashboard.points().get(i).balance().subtract(dashboard.points().get(i - 1).balance());
            if (delta.compareTo(new BigDecimal("70000")) > 0) {
                incomeDetected = true;
                break;
            }
        }
        assertThat(incomeDetected).as("Income on day 31 should appear normalized in February forecast").isTrue();
    }
}
