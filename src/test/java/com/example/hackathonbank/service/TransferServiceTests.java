package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.controller.dto.ExternalTransferRequest;
import com.example.hackathonbank.controller.dto.ExternalTransferResponse;
import com.example.hackathonbank.controller.dto.TransferRequest;
import com.example.hackathonbank.controller.dto.TransferResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.TransferRecipientType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TransferServiceTests {

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private AccountService accountService;

    @Mock
    private UserContextService userContextService;

    private TransferService transferService;

    @BeforeEach
    void setUp() {
        transferService = new TransferService(
                accountRepository,
                transactionRepository,
                accountService,
                userContextService
        );
    }

    @Test
    void transferUpdatesBothAccounts() {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ReflectionTestUtils.setField(savings, "id", 1L);
        ReflectionTestUtils.setField(main, "id", 2L);

        when(accountService.getOwnedAccount(1L)).thenReturn(savings);
        when(accountService.getOwnedAccount(2L)).thenReturn(main);
        when(userContextService.getCurrentUser()).thenReturn(user);

        TransferResponse response = transferService.transfer(new TransferRequest(
                1L,
                2L,
                new BigDecimal("5000.00"),
                "Тест"
        ));

        assertThat(response.message()).isEqualTo("Перевод выполнен.");
        assertThat(savings.getBalance()).isEqualByComparingTo("45000.00");
        assertThat(main.getBalance()).isEqualByComparingTo("20000.00");
        verify(accountRepository).saveAll(List.of(savings, main));
        verify(transactionRepository).saveAll(anyList());
    }

    @Test
    void autoTransferFromSavingsReturnsLocalizedMessage() {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ReflectionTestUtils.setField(savings, "id", 1L);
        ReflectionTestUtils.setField(main, "id", 2L);

        when(accountService.getAccountByType(AccountType.SAVINGS)).thenReturn(savings);
        when(accountService.getAccountByType(AccountType.MAIN)).thenReturn(main);
        when(userContextService.getCurrentUser()).thenReturn(user);

        ActionExecutionResult result = transferService.autoTransferFromSavings(new BigDecimal("10000.00"));

        assertThat(result.message()).contains("10000.00 KGS");
        assertThat(result.currentBalance()).isEqualByComparingTo("25000.00");
        assertThat(result.savingsBalance()).isEqualByComparingTo("40000.00");
    }

    @Test
    void transferRejectsInsufficientFunds() {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        Account savings = new Account(user, AccountType.SAVINGS, "Savings", new BigDecimal("50000.00"), "KGS");
        ReflectionTestUtils.setField(main, "id", 1L);
        ReflectionTestUtils.setField(savings, "id", 2L);

        when(accountService.getOwnedAccount(1L)).thenReturn(main);
        when(accountService.getOwnedAccount(2L)).thenReturn(savings);

        assertThatThrownBy(() -> transferService.transfer(new TransferRequest(
                1L,
                2L,
                new BigDecimal("99999.00"),
                null
        )))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Недостаточно средств");
    }

    @Test
    void externalTransferToMerchantDebitsSourceAccount() {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        ReflectionTestUtils.setField(main, "id", 1L);

        when(accountService.getOwnedAccount(1L)).thenReturn(main);
        when(userContextService.getCurrentUser()).thenReturn(user);

        ExternalTransferResponse response = transferService.transferExternal(new ExternalTransferRequest(
                1L,
                TransferRecipientType.MERCHANT,
                "Globus",
                new BigDecimal("2200.00"),
                null
        ));

        assertThat(response.recipientType()).isEqualTo("MERCHANT");
        assertThat(response.recipientName()).isEqualTo("Globus");
        assertThat(main.getBalance()).isEqualByComparingTo("12800.00");
        assertThat(response.message()).contains("Оплата магазину");
    }
}
