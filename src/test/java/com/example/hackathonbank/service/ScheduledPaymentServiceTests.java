package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.controller.dto.ScheduledPaymentRequest;
import com.example.hackathonbank.controller.dto.ScheduledPaymentResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ScheduledPaymentServiceTests {

    @Mock
    private ScheduledPaymentRepository scheduledPaymentRepository;

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private UserContextService userContextService;

    @Mock
    private AccountService accountService;

    private ScheduledPaymentService scheduledPaymentService;

    @BeforeEach
    void setUp() {
        scheduledPaymentService = new ScheduledPaymentService(
                scheduledPaymentRepository,
                transactionRepository,
                userContextService,
                accountService
        );
    }

    @Test
    void createScheduledPaymentStoresPaymentAndScheduledTransaction() {
        User user = new User("Azizkhan");
        ReflectionTestUtils.setField(user, "id", 1L);
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        ReflectionTestUtils.setField(main, "id", 1L);

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(accountService.getOwnedAccount(1L)).thenReturn(main);
        when(scheduledPaymentRepository.save(any(ScheduledPayment.class))).thenAnswer(invocation -> {
            ScheduledPayment payment = invocation.getArgument(0);
            ReflectionTestUtils.setField(payment, "id", 55L);
            return payment;
        });

        ScheduledPaymentResponse response = scheduledPaymentService.createScheduledPayment(
                new ScheduledPaymentRequest(
                        1L,
                        "Интернет",
                        "HomeNet",
                        "Подписки",
                        new BigDecimal("3900.00"),
                        LocalDate.now().plusDays(5)
                )
        );

        ArgumentCaptor<Transaction> transactionCaptor = ArgumentCaptor.forClass(Transaction.class);
        verify(transactionRepository).save(transactionCaptor.capture());
        Transaction scheduledTransaction = transactionCaptor.getValue();

        assertThat(response.title()).isEqualTo("Интернет");
        assertThat(response.counterparty()).isEqualTo("HomeNet");
        assertThat(response.iconKey()).isEqualTo("subscription");
        assertThat(scheduledTransaction.getTitle()).isEqualTo("Автоплатеж: Интернет");
        assertThat(scheduledTransaction.getAmount()).isEqualByComparingTo("-3900.00");
        assertThat(scheduledTransaction.getStatus()).isEqualTo(TransactionStatus.SCHEDULED);
        assertThat(scheduledTransaction.getType()).isEqualTo(TransactionType.AUTO_PAYMENT);
    }

    @Test
    void postponePaymentMovesDueDateAndScheduledTransaction() {
        User user = new User("Azizkhan");
        ReflectionTestUtils.setField(user, "id", 1L);
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ScheduledPayment payment = new ScheduledPayment(
                user,
                main,
                "Аренда",
                new BigDecimal("25000.00"),
                "Аренда",
                LocalDate.now().plusDays(4),
                PaymentStatus.SCHEDULED
        );
        ReflectionTestUtils.setField(payment, "id", 99L);

        Transaction scheduledTransaction = new Transaction(
                user,
                main,
                payment,
                "Автоплатеж: Аренда",
                "Landlord",
                new BigDecimal("-25000.00"),
                "Аренда",
                "home",
                TransactionType.AUTO_PAYMENT,
                TransactionStatus.SCHEDULED,
                LocalDateTime.now().plusDays(4).withHour(9).withMinute(0)
        );

        when(scheduledPaymentRepository.findById(99L)).thenReturn(Optional.of(payment));
        when(userContextService.getCurrentUser()).thenReturn(user);
        when(transactionRepository.findByScheduledPaymentId(99L)).thenReturn(Optional.of(scheduledTransaction));
        when(accountService.getAccountByType(AccountType.MAIN)).thenReturn(main);
        when(accountService.getAccountByType(AccountType.SAVINGS)).thenReturn(savings);

        ActionExecutionResult result = scheduledPaymentService.postponePayment(99L);

        assertThat(payment.getStatus()).isEqualTo(PaymentStatus.POSTPONED);
        assertThat(scheduledTransaction.getStatus()).isEqualTo(TransactionStatus.POSTPONED);
        assertThat(payment.getDueDate()).isEqualTo(LocalDate.now().plusDays(11));
        assertThat(result.message()).contains("Платеж \"Аренда\" перенесен");
        verify(scheduledPaymentRepository).save(payment);
    }
}
