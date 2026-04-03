package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.ai.AiCapabilityService;
import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.controller.dto.DailySavingsPreviewResponse;
import com.example.hackathonbank.controller.dto.DemoSimulateDayResponse;
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
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
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
    private ScheduledPaymentRepository scheduledPaymentRepository;

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
    private SpendProfileService spendProfileService;

    private DailySavingsService dailySavingsService;

    @BeforeEach
    void setUp() {
        dailySavingsService = new DailySavingsService(
                userContextService,
                userSettingsRepository,
                accountRepository,
                scheduledPaymentRepository,
                transactionRepository,
                transferService,
                aiCapabilityService,
                aiChatClient,
                aiCallExecutor,
                new ObjectMapper(),
                incomeCalendarService,
                spendProfileService
        );
    }

    @Test
    void previewCalculatesFivePercentOfSafeBalance() {
        User user = user(1L);
        LocalDate currentDate = LocalDate.of(2026, 3, 10);
        UserSettings settings = new UserSettings(user, true, true, false, currentDate);
        Account main = account(user, 1L, AccountType.MAIN, "Main", "20000.00");
        Account savings = account(user, 2L, AccountType.SAVINGS, "Savings", "50000.00");
        ScheduledPayment rent = scheduledPayment(user, main, 10L, "Rent", "4000.00", LocalDate.of(2026, 3, 15));

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));
        when(scheduledPaymentRepository.findByUserIdAndStatusInOrderByDueDateAsc(
                1L,
                List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED)
        )).thenReturn(List.of(rent));
        when(incomeCalendarService.buildCalendar(eq(1L), eq(currentDate)))
                .thenReturn(new IncomeCalendarService.IncomeCalendar(
                        List.of(new IncomeCalendarService.IncomeCluster(IncomeType.SALARY, 15, new BigDecimal("90000.00"), 2, 66.0)),
                        LocalDate.of(2026, 3, 15), 66,
                        LocalDate.of(2026, 3, 13), LocalDate.of(2026, 3, 17)
                ));
        when(spendProfileService.buildProfile(eq(1L), eq(currentDate)))
                .thenReturn(new SpendProfileService.SpendProfile(
                        new BigDecimal("60.00"), new BigDecimal("40.00"),
                        uniformMultipliers(), BigDecimal.ZERO
                ));

        DailySavingsPreviewResponse preview = dailySavingsService.previewForCurrentUser();

        assertThat(preview.nextIncomeDate()).isEqualTo(LocalDate.of(2026, 3, 15));
        assertThat(preview.daysToNextIncome()).isEqualTo(5);
        assertThat(preview.requiredPayments()).isEqualByComparingTo("4000.00");
        assertThat(preview.lifeBuffer()).isEqualByComparingTo("600.00");
        assertThat(preview.safeBalance()).isEqualByComparingTo("15400.00");
        assertThat(preview.suggestedAmount()).isEqualByComparingTo("770.00");
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
        when(incomeCalendarService.buildCalendar(eq(1L), any(LocalDate.class)))
                .thenReturn(new IncomeCalendarService.IncomeCalendar(
                        List.of(), currentDate.plusDays(14), 0,
                        currentDate.plusDays(14), currentDate.plusDays(14)
                ));

        DailySavingsPreviewResponse preview = dailySavingsService.previewForCurrentUser();

        assertThat(preview.suggestedAmount()).isEqualByComparingTo("0.00");
        assertThat(preview.status()).contains("1000 KGS");
        verify(transferService, never()).autoSaveToSavings(any(User.class), any(BigDecimal.class), any(LocalDate.class));
    }

    @Test
    void simulateNextDayExecutesTransferWhenAutoSaveEnabled() {
        User user = user(1L);
        UserSettings settings = new UserSettings(user, true, true, true, LocalDate.of(2026, 3, 10));
        Account main = account(user, 1L, AccountType.MAIN, "Main", "30000.00");
        Account savings = account(user, 2L, AccountType.SAVINGS, "Savings", "55000.00");
        ScheduledPayment payment = scheduledPayment(user, main, 10L, "Internet", "2000.00", LocalDate.of(2026, 3, 12));
        LocalDate nextDay = LocalDate.of(2026, 3, 11);

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(accountRepository.findByUserIdAndType(1L, AccountType.MAIN)).thenReturn(Optional.of(main));
        when(accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS)).thenReturn(Optional.of(savings));
        when(scheduledPaymentRepository.findByUserIdAndStatusInOrderByDueDateAsc(
                1L,
                List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED)
        )).thenReturn(List.of(payment));
        when(incomeCalendarService.buildCalendar(eq(1L), eq(nextDay)))
                .thenReturn(new IncomeCalendarService.IncomeCalendar(
                        List.of(new IncomeCalendarService.IncomeCluster(IncomeType.SALARY, 13, new BigDecimal("90000.00"), 2, 66.0)),
                        LocalDate.of(2026, 3, 13), 66,
                        LocalDate.of(2026, 3, 11), LocalDate.of(2026, 3, 15)
                ));
        when(spendProfileService.buildProfile(eq(1L), eq(nextDay)))
                .thenReturn(new SpendProfileService.SpendProfile(
                        new BigDecimal("60.00"), new BigDecimal("40.00"),
                        uniformMultipliers(), BigDecimal.ZERO
                ));
        when(transactionRepository.findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(
                eq(1L),
                eq(TransactionStatus.COMPLETED),
                any(LocalDateTime.class),
                any(LocalDateTime.class)
        )).thenReturn(List.of(
                income(user, main, "Salary A", "2026-01-13T10:00:00", "90000.00"),
                income(user, main, "Salary B", "2026-02-13T10:00:00", "90000.00"),
                expense(user, main, "Transport", "2026-03-09T12:00:00", "1000.00")
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

    private ScheduledPayment scheduledPayment(User user,
                                              Account account,
                                              Long id,
                                              String title,
                                              String amount,
                                              LocalDate dueDate) {
        ScheduledPayment payment = new ScheduledPayment(
                user,
                account,
                title,
                title,
                new BigDecimal(amount),
                title,
                "calendar",
                dueDate,
                true,
                PaymentStatus.SCHEDULED
        );
        ReflectionTestUtils.setField(payment, "id", id);
        return payment;
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

    private Map<DayOfWeek, BigDecimal> uniformMultipliers() {
        Map<DayOfWeek, BigDecimal> m = new EnumMap<>(DayOfWeek.class);
        for (DayOfWeek dow : DayOfWeek.values()) {
            m.put(dow, BigDecimal.ONE);
        }
        return m;
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
