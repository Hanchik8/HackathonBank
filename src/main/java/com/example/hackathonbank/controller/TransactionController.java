package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.BulkCategorizeTransactionsRequest;
import com.example.hackathonbank.controller.dto.CreateTransactionRequest;
import com.example.hackathonbank.controller.dto.TransactionResponse;
import com.example.hackathonbank.service.TransactionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/transactions")
public class TransactionController {

    private final TransactionService transactionService;

    public TransactionController(TransactionService transactionService) {
        this.transactionService = transactionService;
    }

    @GetMapping
    public List<TransactionResponse> getTransactions() {
        return transactionService.getTransactions();
    }

    @PostMapping
    public TransactionResponse createTransaction(@Valid @RequestBody CreateTransactionRequest request) {
        return transactionService.createTransaction(request);
    }

    @PutMapping("/bulk-categorize")
    public void bulkCategorize(@Valid @RequestBody BulkCategorizeTransactionsRequest request) {
        transactionService.assignTransactionsToSmartCategory(request.transactionIds(), request.categoryId());
    }
}
