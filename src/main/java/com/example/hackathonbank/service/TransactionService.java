package com.example.hackathonbank.service;

import com.example.hackathonbank.controller.dto.CreateTransactionRequest;
import com.example.hackathonbank.controller.dto.TransactionResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.SmartCategory;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final UserContextService userContextService;
    private final AccountService accountService;
    private final SmartCategoryService smartCategoryService;
    private final AccountRepository accountRepository;
    private final UserSettingsService userSettingsService;

    public TransactionService(TransactionRepository transactionRepository,
                              UserContextService userContextService,
                              AccountService accountService,
                              SmartCategoryService smartCategoryService,
                              AccountRepository accountRepository,
                              UserSettingsService userSettingsService) {
        this.transactionRepository = transactionRepository;
        this.userContextService = userContextService;
        this.accountService = accountService;
        this.smartCategoryService = smartCategoryService;
        this.accountRepository = accountRepository;
        this.userSettingsService = userSettingsService;
    }

    @Transactional(readOnly = true)
    public List<TransactionResponse> getTransactions() {
        return getTransactionsForCurrentUser().stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<Transaction> getTransactionsForCurrentUser() {
        return transactionRepository.findByUserIdOrderByOccurredAtDesc(userContextService.getCurrentUser().getId());
    }

    @Transactional
    public TransactionResponse createTransaction(CreateTransactionRequest request) {
        Account account = accountService.getOwnedAccount(request.accountId());
        SmartCategory smartCategory = request.smartCategoryId() == null
                ? null
                : smartCategoryService.getOwnedCategory(request.smartCategoryId());
        User user = userContextService.getCurrentUser();
        TransactionType type = TransactionType.valueOf(request.type().trim().toUpperCase());
        BigDecimal normalizedAmount = normalizeAmount(type, request.amount());
        LocalDateTime occurredAt = userSettingsService.currentDate().atTime(12, 0);

        Transaction transaction = transactionRepository.save(new Transaction(
                user,
                account,
                null,
                smartCategory,
                request.title().trim(),
                request.counterparty().trim(),
                normalizedAmount,
                request.category().trim(),
                request.iconKey().trim(),
                type,
                TransactionStatus.COMPLETED,
                occurredAt
        ));

        account.setBalance(account.getBalance().add(normalizedAmount));
        accountRepository.save(account);

        return toResponse(transaction);
    }

    @Transactional
    public TransactionResponse adjustAccountBalance(Long accountId, BigDecimal delta, String title) {
        Account account = accountService.getOwnedAccount(accountId);
        User user = userContextService.getCurrentUser();
        LocalDateTime occurredAt = userSettingsService.currentDate().atTime(12, 0);

        Transaction transaction = transactionRepository.save(new Transaction(
                user,
                account,
                null,
                null,
                title.trim(),
                "Admin",
                delta,
                delta.compareTo(BigDecimal.ZERO) >= 0 ? "Поступления" : "Корректировки",
                delta.compareTo(BigDecimal.ZERO) >= 0 ? "income" : "calendar",
                delta.compareTo(BigDecimal.ZERO) >= 0 ? TransactionType.INCOME : TransactionType.ADJUSTMENT,
                TransactionStatus.COMPLETED,
                occurredAt
        ));
        account.setBalance(account.getBalance().add(delta));
        accountRepository.save(account);
        return toResponse(transaction);
    }

    @Transactional(readOnly = true)
    public TransactionResponse toResponse(Transaction transaction) {
        return new TransactionResponse(
                transaction.getId(),
                transaction.getTitle(),
                transaction.getCounterparty(),
                transaction.getAmount(),
                transaction.getCategory(),
                transaction.getIconKey(),
                transaction.getType().name(),
                transaction.getStatus().name(),
                transaction.getAccount().getName(),
                transaction.getOccurredAt()
        );
    }

    @Transactional(readOnly = true)
    public Optional<Transaction> findScheduledTransaction(Long paymentId) {
        return transactionRepository.findByScheduledPaymentId(paymentId);
    }

    @Transactional
    public void assignTransactionToSmartCategory(Long transactionId, Long smartCategoryId) {
        Transaction transaction = transactionRepository.findByIdAndUserId(
                        transactionId,
                        userContextService.getCurrentUser().getId()
                )
                .orElseThrow(() -> new IllegalArgumentException("Транзакция не найдена."));
        if (transaction.getStatus() != TransactionStatus.COMPLETED || transaction.getAmount().compareTo(BigDecimal.ZERO) >= 0) {
            throw new IllegalArgumentException("В Smart List можно добавить только завершенный расход.");
        }

        SmartCategory smartCategory = smartCategoryService.getOwnedCategory(smartCategoryId);
        transaction.setSmartCategory(smartCategory);
        transactionRepository.save(transaction);
    }

    private BigDecimal normalizeAmount(TransactionType type, BigDecimal amount) {
        return switch (type) {
            case INCOME -> amount.abs();
            default -> amount.abs().negate();
        };
    }
}
