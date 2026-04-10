package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.ai.AiCapabilityService;
import com.example.hackathonbank.controller.dto.DailySavingsPreviewResponse;
import com.example.hackathonbank.controller.dto.DemoSimulateDayResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.model.UserSettings;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import com.example.hackathonbank.repository.UserSettingsRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DailySavingsServiceTests {

    @Mock
    private UserContextService userContextService;

    @Mock
    private UserSettingsRepository userSettingsRepository;

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private TransferService transferService;

    @Mock
    private AiCapabilityService aiCapabilityService;

    @Mock
    private ChatClient aiChatClient;

    @Mock
    private AiCallExecutor aiCallExecutor;

    @Mock
    private IncomeCalendarService incomeCalendarService;

    @Mock
    private CashFlowProjectionService cashFlowProjectionService;

    private DailySavingsService dailySavingsService;

    @BeforeEach
    void setUp() {
        dailySavingsService = new DailySavingsService(
                userContextService,
                userSettingsRepository,
                accountRepository,
                transactionRepository,
                transferService,
                aiCapabilityService,
                aiChatClient,
                aiCallExecutor,
                new ObjectMapper(),
                incomeCalendarService,
                cashFlowProjectionService
        );
    }

    @Test
    void previewCalculatesSafeAmountFromProjection() {
        User user = user(1L);
        LocalDate currentDate = LocalDate.of(2026, 3, 10);
        UserSettings settings = new UserSettings(user, true, true, false, currentDate);
        Account main = account(user, 1L, AccountType.MAIN, "Main", "20000.00");
        Account savings = account(user, 2L, AccountType.SAVINGS, "Savings", "50000.00");

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));
        when(incomeCalendarService.buildCalendar(eq(1L), eq(currentDate))).thenReturn(calendar(
                LocalDate.of(2026, 3, 15),
                new BigDecimal("90000.00"),
                IncomeType.SALARY,
                80
        ));
        when(cashFlowProjectionService.buildProjection(eq(1L), eq(currentDate), eq(LocalDate.of(2026, 3, 16)), eq(BigDecimal.ZERO)))
                .thenReturn(projection(user, main, savings, currentDate, LocalDate.of(2026, 3, 16), new BigDecimal("15500.00")));
        when(cashFlowProjectionService.buildProjection(
                eq(1L),
                eq(currentDate),
                eq(LocalDate.of(2026, 3, 16)),
                argThat(amount -> amount.compareTo(BigDecimal.ZERO) > 0)
        ))
                .thenAnswer(invocation -> projection(user, main, savings, currentDate, LocalDate.of(2026, 3, 16), new BigDecimal("14730.85")));

        DailySavingsPreviewResponse preview = dailySavingsService.previewForCurrentUser();

        assertThat(preview.nextIncomeDate()).isEqualTo(LocalDate.of(2026, 3, 15));
        assertThat(preview.daysToNextIncome()).isEqualTo(5);
        assertThat(preview.requiredPayments()).isEqualByComparingTo("4000.00");
        assertThat(preview.lifeBuffer()).isEqualByComparingTo("620.40");
        assertThat(preview.safeBalance()).isEqualByComparingTo("15279.60");
        assertThat(preview.suggestedAmount()).isEqualByComparingTo("763.98");
        assertThat(preview.overdraftGuardTriggered()).isFalse();
    }

    @Test
    void previewReturnsZeroWhenMainBalanceBelowThreshold() {
        User user = user(1L);
        LocalDate currentDate = LocalDate.of(2026, 3, 10);
        UserSettings settings = new UserSettings(user, true, false, false, currentDate);
        Account main = account(user, 1L, AccountType.MAIN, "Main", "900.00");
        Account savings = account(user, 2L, AccountType.SAVINGS, "Savings", "50000.00");

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));

        DailySavingsPreviewResponse preview = dailySavingsService.previewForCurrentUser();

        assertThat(preview.suggestedAmount()).isEqualByComparingTo("0.00");
        assertThat(preview.status()).contains("1000 KGS");
        verify(transferService, never()).autoSaveToSavings(any(User.class), any(BigDecimal.class), any(LocalDate.class));
    }

    @Test
    void overdraftGuardBlocksTransferWhenProjectedMinimumFallsTooLow() {
        User user = user(1L);
        LocalDate currentDate = LocalDate.of(2026, 3, 10);
        UserSettings settings = new UserSettings(user, true, true, false, currentDate);
        Account main = account(user, 1L, AccountType.MAIN, "Main", "20000.00");
        Account savings = account(user, 2L, AccountType.SAVINGS, "Savings", "50000.00");

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));
        when(incomeCalendarService.buildCalendar(eq(1L), eq(currentDate))).thenReturn(calendar(
                LocalDate.of(2026, 3, 15),
                new BigDecimal("90000.00"),
                IncomeType.SALARY,
                80
        ));
        when(cashFlowProjectionService.buildProjection(eq(1L), eq(currentDate), eq(LocalDate.of(2026, 3, 16)), eq(BigDecimal.ZERO)))
                .thenReturn(projection(user, main, savings, currentDate, LocalDate.of(2026, 3, 16), new BigDecimal("15500.00")));
        when(cashFlowProjectionService.buildProjection(
                eq(1L),
                eq(currentDate),
                eq(LocalDate.of(2026, 3, 16)),
                argThat(amount -> amount.compareTo(BigDecimal.ZERO) > 0)
        ))
                .thenReturn(projection(user, main, savings, currentDate, LocalDate.of(2026, 3, 16), new BigDecimal("50.00")));

        DailySavingsPreviewResponse preview = dailySavingsService.previewForCurrentUser();

        assertThat(preview.suggestedAmount()).isEqualByComparingTo("0.00");
        assertThat(preview.overdraftGuardTriggered()).isTrue();
        assertThat(preview.status()).contains("Overdraft Guard");
    }

    @Test
    void simulateNextDayExecutesTransferWhenAutoSaveEnabled() {
        User user = user(1L);
        UserSettings settings = new UserSettings(user, true, true, true, LocalDate.of(2026, 3, 10));
        Account main = account(user, 1L, AccountType.MAIN, "Main", "30000.00");
        Account savings = account(user, 2L, AccountType.SAVINGS, "Savings", "55000.00");
        LocalDate nextDay = LocalDate.of(2026, 3, 11);

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));
        when(incomeCalendarService.buildCalendar(eq(1L), eq(nextDay))).thenReturn(calendar(
                LocalDate.of(2026, 3, 13),
                new BigDecimal("90000.00"),
                IncomeType.SALARY,
                75
        ));
        when(cashFlowProjectionService.buildProjection(eq(1L), eq(nextDay), eq(LocalDate.of(2026, 3, 14)), eq(BigDecimal.ZERO)))
                .thenReturn(simulationProjection(user, main, savings, nextDay, LocalDate.of(2026, 3, 14), new BigDecimal("27000.00")));
        when(cashFlowProjectionService.buildProjection(
                eq(1L),
                eq(nextDay),
                eq(LocalDate.of(2026, 3, 14)),
                argThat(amount -> amount.compareTo(BigDecimal.ZERO) > 0)
        ))
                .thenReturn(simulationProjection(user, main, savings, nextDay, LocalDate.of(2026, 3, 14), new BigDecimal("26500.00")));
        when(transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                eq(1L),
                eq(TransactionStatus.COMPLETED),
                any(LocalDateTime.class),
                any(LocalDateTime.class)
        )).thenReturn(List.of(
                income(user, main, "Salary", "2026-03-09T10:00:00", "90000.00"),
                expense(user, main, "Transport", "2026-03-10T12:00:00", "1000.00")
        ));
        when(aiCapabilityService.isLiveAiEnabled()).thenReturn(false);
        when(transferService.autoSaveToSavings(eq(user), any(BigDecimal.class), eq(nextDay)))
                .thenAnswer(invocation -> {
                    BigDecimal amount = invocation.getArgument(1);
                    main.setBalance(main.getBalance().subtract(amount));
                    savings.setBalance(savings.getBalance().add(amount));
                    return new ActionExecutionResult("AUTO_DAILY_SAVE", "saved", main.getBalance(), savings.getBalance());
                });

        DemoSimulateDayResponse response = dailySavingsService.simulateNextDayForCurrentUser();

        assertThat(response.currentDate()).isEqualTo(nextDay);
        assertThat(response.autoSaveExecuted()).isTrue();
        assertThat(response.savedAmount()).isPositive();
        assertThat(response.notification()).contains("Safe-to-Save");
        verify(userSettingsRepository).save(settings);
        verify(transferService).autoSaveToSavings(eq(user), any(BigDecimal.class), eq(nextDay));
    }

    private IncomeCalendarService.IncomeCalendar calendar(LocalDate expectedDate,
                                                          BigDecimal amount,
                                                          IncomeType type,
                                                          int confidence) {
        return new IncomeCalendarService.IncomeCalendar(
                List.of(new IncomeCalendarService.IncomeCluster(
                        type,
                        "salary issuer",
                        amount,
                        expectedDate.getDayOfMonth(),
                        3,
                        3,
                        confidence
                )),
                new IncomeCalendarService.NextIncomeForecast(
                        expectedDate,
                        expectedDate.minusDays(1),
                        expectedDate.plusDays(1),
                        amount,
                        type,
                        confidence
                )
        );
    }

    private CashFlowProjectionService.CashFlowProjection projection(User user,
                                                                    Account main,
                                                                    Account savings,
                                                                    LocalDate currentDate,
                                                                    LocalDate horizonEnd,
                                                                    BigDecimal minimumBalance) {
        Map<DayOfWeek, BigDecimal> multipliers = uniformMultipliers();
        SpendProfileService.SpendProfile spendProfile = new SpendProfileService.SpendProfile(
                new BigDecimal("60.00"),
                new BigDecimal("40.00"),
                multipliers,
                multipliers,
                BigDecimal.ZERO,
                Set.of("rent")
        );
        List<CashFlowProjectionService.ProjectedCashFlowDay> days = List.of(
                day(0, currentDate, "20000.00", "0.00", "0.00", "0.00", "0.00", "0.00"),
                day(1, currentDate.plusDays(1), "19900.00", "0.00", "60.00", "40.00", "0.00", "0.00"),
                day(2, currentDate.plusDays(2), "19800.00", "0.00", "60.00", "40.00", "0.00", "0.00"),
                day(3, currentDate.plusDays(3), "19700.00", "0.00", "60.00", "40.00", "0.00", "0.00"),
                day(4, currentDate.plusDays(4), "19600.00", "0.00", "60.00", "40.00", "0.00", "0.00"),
                day(5, currentDate.plusDays(5), "15500.00", "0.00", "60.00", "40.00", "4000.00", "0.00"),
                day(6, horizonEnd, "15400.00", "0.00", "60.00", "40.00", "0.00", "0.00")
        );
        return new CashFlowProjectionService.CashFlowProjection(
                currentDate,
                horizonEnd,
                main,
                savings,
                main.getBalance(),
                calendar(LocalDate.of(2026, 3, 15), new BigDecimal("90000.00"), IncomeType.SALARY, 80),
                List.of(),
                spendProfile,
                List.of(),
                new RecurringObligationService.RecurringObligationForecast(List.of(), List.of(), Set.of("rent")),
                days,
                minimumBalance,
                null,
                new BigDecimal("4000.00"),
                BigDecimal.ZERO,
                new BigDecimal("600.00")
        );
    }

    private CashFlowProjectionService.CashFlowProjection simulationProjection(User user,
                                                                              Account main,
                                                                              Account savings,
                                                                              LocalDate currentDate,
                                                                              LocalDate horizonEnd,
                                                                              BigDecimal minimumBalance) {
        Map<DayOfWeek, BigDecimal> multipliers = uniformMultipliers();
        SpendProfileService.SpendProfile spendProfile = new SpendProfileService.SpendProfile(
                new BigDecimal("100.00"),
                new BigDecimal("20.00"),
                multipliers,
                multipliers,
                BigDecimal.ZERO,
                Set.of()
        );
        List<CashFlowProjectionService.ProjectedCashFlowDay> days = List.of(
                day(0, currentDate, "30000.00", "0.00", "0.00", "0.00", "0.00", "0.00"),
                day(1, currentDate.plusDays(1), "29880.00", "0.00", "100.00", "20.00", "0.00", "0.00"),
                day(2, currentDate.plusDays(2), "29760.00", "0.00", "100.00", "20.00", "0.00", "0.00"),
                day(3, horizonEnd, "29640.00", "0.00", "100.00", "20.00", "0.00", "0.00")
        );
        return new CashFlowProjectionService.CashFlowProjection(
                currentDate,
                horizonEnd,
                main,
                savings,
                main.getBalance(),
                calendar(LocalDate.of(2026, 3, 13), new BigDecimal("90000.00"), IncomeType.SALARY, 75),
                List.of(),
                spendProfile,
                List.of(),
                RecurringObligationService.RecurringObligationForecast.empty(),
                days,
                minimumBalance,
                null,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                new BigDecimal("360.00")
        );
    }

    private CashFlowProjectionService.ProjectedCashFlowDay day(int offset,
                                                               LocalDate date,
                                                               String balance,
                                                               String income,
                                                               String essential,
                                                               String discretionary,
                                                               String confirmed,
                                                               String inferred) {
        return new CashFlowProjectionService.ProjectedCashFlowDay(
                offset,
                date,
                new BigDecimal(balance),
                new BigDecimal(income),
                new BigDecimal(essential),
                new BigDecimal(discretionary),
                new BigDecimal(confirmed),
                new BigDecimal(inferred)
        );
    }

    private User user(Long id) {
        User user = new User("Azizkhan");
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    private Account account(User user, Long id, AccountType type, String name, String balance) {
        Account account = new Account(user, type, name, new BigDecimal(balance), "KGS");
        ReflectionTestUtils.setField(account, "id", id);
        return account;
    }

    private Map<DayOfWeek, BigDecimal> uniformMultipliers() {
        Map<DayOfWeek, BigDecimal> multipliers = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dayOfWeek : DayOfWeek.values()) {
            multipliers.put(dayOfWeek, BigDecimal.ONE);
        }
        return multipliers;
    }

    private Transaction income(User user, Account account, String title, String occurredAt, String amount) {
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

    private Transaction expense(User user, Account account, String title, String occurredAt, String amount) {
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
