package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record CreateTransactionRequest(
        @NotNull Long accountId,
        @NotBlank String title,
        @NotBlank String counterparty,
        @NotNull @DecimalMin("0.01") BigDecimal amount,
        @NotBlank String type,
        @NotBlank String category,
        @NotBlank String iconKey,
        Long smartCategoryId
) {
}
