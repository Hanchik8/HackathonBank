package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record BulkCategorizeTransactionsRequest(
        @NotEmpty List<Long> transactionIds,
        Long categoryId
) {
}
