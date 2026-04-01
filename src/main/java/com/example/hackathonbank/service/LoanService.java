package com.example.hackathonbank.service;

import com.example.hackathonbank.controller.dto.CreateLoanRequest;
import com.example.hackathonbank.controller.dto.ScheduledPaymentRequest;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
public class LoanService {

    private static final BigDecimal DEFAULT_INTEREST_MULTIPLIER = new BigDecimal("1.12");

    private final AccountService accountService;
    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;
    private final UserContextService userContextService;
    private final UserSettingsService userSettingsService;
    private final ScheduledPaymentService scheduledPaymentService;

    public LoanService(AccountService accountService,
                       AccountRepository accountRepository,
                       TransactionRepository transactionRepository,
                       UserContextService userContextService,
                       UserSettingsService userSettingsService,
                       ScheduledPaymentService scheduledPaymentService) {
        this.accountService = accountService;
        this.accountRepository = accountRepository;
        this.transactionRepository = transactionRepository;
        this.userContextService = userContextService;
        this.userSettingsService = userSettingsService;
        this.scheduledPaymentService = scheduledPaymentService;
    }

    @Transactional
    public void createLoan(CreateLoanRequest request) {
        Account account = accountService.getOwnedAccount(request.accountId());
        User user = userContextService.getCurrentUser();

        account.setBalance(account.getBalance().add(request.amount()));
        accountRepository.save(account);

        transactionRepository.save(new Transaction(
                user,
                account,
                null,
                null,
                request.title().trim(),
                "MBank",
                request.amount(),
                "Кредит",
                "income",
                TransactionType.INCOME,
                TransactionStatus.COMPLETED,
                userSettingsService.currentDate().atTime(12, 0)
        ));

        scheduledPaymentService.createScheduledPayment(new ScheduledPaymentRequest(
                request.accountId(),
                "%s · Погашение".formatted(request.title().trim()),
                "MBank",
                "Кредит",
                request.amount().multiply(DEFAULT_INTEREST_MULTIPLIER),
                request.dueDate(),
                true
        ));
    }
}
