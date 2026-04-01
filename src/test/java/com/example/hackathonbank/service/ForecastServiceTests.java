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
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ForecastServiceTests {

    @Mock
    private AccountService accountService;

    @Mock
    private ScheduledPaymentService scheduledPaymentService;

    @Mock
    private UserSettingsService userSettingsService;

    private ForecastService forecastService;

    @BeforeEach
    void setUp() {
        forecastService = new ForecastService(accountService, scheduledPaymentService, userSettingsService);
    }

    @Test
    void buildDashboardUsesRequestedHorizonAndTracksMinimumBalance() {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ScheduledPayment rent = new ScheduledPayment(
                user,
                main,
                "Аренда",
                new BigDecimal("25000.00"),
                "Аренда",
                LocalDate.now().plusDays(4),
                PaymentStatus.SCHEDULED
        );

        when(accountService.getAccountByType(AccountType.MAIN)).thenReturn(main);
        when(accountService.getAccountByType(AccountType.SAVINGS)).thenReturn(savings);
        when(scheduledPaymentService.getPendingPayments()).thenReturn(List.of(rent));
        when(userSettingsService.currentDate()).thenReturn(LocalDate.now());

        AiDashboardResponse dashboard = forecastService.buildDashboard(42);

        assertThat(dashboard.horizonDays()).isEqualTo(42);
        assertThat(dashboard.points()).hasSize(43);
        assertThat(dashboard.minimumProjectedBalance()).isEqualByComparingTo("-10000.00");
        assertThat(dashboard.scheduledPayments()).hasSize(1);
    }
}
