package com.example.hackathonbank.service;

import com.example.hackathonbank.controller.dto.TransactionResponse;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional(readOnly = true)
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final UserContextService userContextService;

    public TransactionService(TransactionRepository transactionRepository, UserContextService userContextService) {
        this.transactionRepository = transactionRepository;
        this.userContextService = userContextService;
    }

    public List<TransactionResponse> getTransactions() {
        return getTransactionsForCurrentUser().stream().map(this::toResponse).toList();
    }

    public List<Transaction> getTransactionsForCurrentUser() {
        return transactionRepository.findByUserIdOrderByOccurredAtDesc(userContextService.getCurrentUser().getId());
    }

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

    public Optional<Transaction> findScheduledTransaction(Long paymentId) {
        return transactionRepository.findByScheduledPaymentId(paymentId);
    }
}
