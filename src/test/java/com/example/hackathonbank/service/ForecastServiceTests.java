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
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ForecastServiceTests {

    @Mock
    private CashFlowProjectionService cashFlowProjectionService;

    @Mock
    private UserSettingsService userSettingsService;

    @Mock
    private UserContextService userContextService;

    @Mock
    private User currentUser;

    private ForecastService forecastService;

    @BeforeEach
    void setUp() {
        forecastService = new ForecastService(
                cashFlowProjectionService,
                userSettingsService,
                userContextService
        );
    }

    @Test
    void buildDashboardUsesUnifiedProjectionPoints() {
        LocalDate currentDate = LocalDate.of(2026, 3, 25);
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ScheduledPayment rent = new ScheduledPayment(
                user,
                main,
                "Аренда",
                "Landlord",
                new BigDecimal("25000.00"),
                "Аренда",
                "home",
                currentDate.plusDays(4),
                true,
                PaymentStatus.SCHEDULED,
                false
        );

        when(userContextService.getCurrentUser()).thenReturn(currentUser);
        when(currentUser.getId()).thenReturn(99L);
        when(userSettingsService.currentDate()).thenReturn(currentDate);
        when(cashFlowProjectionService.buildProjection(eq(99L), eq(currentDate), eq(42)))
                .thenReturn(projection(user, main, savings, rent, currentDate, currentDate.plusDays(42)));

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
        assertThat(dashboard.points().get(4).projectedExpense()).isEqualByComparingTo("25120.00");
    }

    private CashFlowProjectionService.CashFlowProjection projection(User user,
                                                                    Account main,
                                                                    Account savings,
                                                                    ScheduledPayment rent,
                                                                    LocalDate currentDate,
                                                                    LocalDate horizonEnd) {
        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
            multipliers.put(dayOfWeek, BigDecimal.ONE);
        }
        SpendProfileService.SpendProfile spendProfile = new SpendProfileService.SpendProfile(
                new BigDecimal("80.00"),
                new BigDecimal("40.00"),
                multipliers,
                multipliers,
                BigDecimal.ZERO,
                Set.of()
        );
        List<CashFlowProjectionService.ProjectedCashFlowDay> days = new ArrayList<>();
        BigDecimal balance = main.getBalance();
        days.add(new CashFlowProjectionService.ProjectedCashFlowDay(0, currentDate, balance, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO));
        for (int offset = 1; offset <= 42; offset++) {
            LocalDate date = currentDate.plusDays(offset);
            BigDecimal income = offset == 10 ? new BigDecimal("5000.00") : BigDecimal.ZERO;
            BigDecimal confirmed = offset == 4 ? rent.getAmount() : BigDecimal.ZERO;
            BigDecimal essential = new BigDecimal("80.00");
            BigDecimal discretionary = new BigDecimal("40.00");
            balance = balance.subtract(essential).subtract(discretionary).subtract(confirmed).add(income);
            days.add(new CashFlowProjectionService.ProjectedCashFlowDay(
                    offset,
                    date,
                    balance,
                    income,
                    essential,
                    discretionary,
                    confirmed,
                    BigDecimal.ZERO
            ));
        }

        return new CashFlowProjectionService.CashFlowProjection(
                currentDate,
                horizonEnd,
                main,
                savings,
                main.getBalance(),
                new IncomeCalendarService.IncomeCalendar(
                        List.of(new IncomeCalendarService.IncomeCluster(
                                IncomeType.SALARY,
                                "salary issuer",
                                new BigDecimal("5000.00"),
                                4,
                                3,
                                3,
                                85
                        )),
                        new IncomeCalendarService.NextIncomeForecast(
                                currentDate.plusDays(10),
                                currentDate.plusDays(9),
                                currentDate.plusDays(11),
                                new BigDecimal("5000.00"),
                                IncomeType.SALARY,
                                85
                        )
                ),
                List.of(new IncomeCalendarService.ProjectedIncomeEvent(
                        IncomeType.SALARY,
                        currentDate.plusDays(10),
                        currentDate.plusDays(9),
                        currentDate.plusDays(11),
                        new BigDecimal("5000.00"),
                        85
                )),
                spendProfile,
                List.of(rent),
                RecurringObligationService.RecurringObligationForecast.empty(),
                days,
                balance.min(new BigDecimal("-10600.00")),
                currentDate.plusDays(4),
                rent.getAmount(),
                BigDecimal.ZERO,
                new BigDecimal("5040.00")
        );
    }
}
