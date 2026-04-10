package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record SmartCategoryLinkTransactionRequest(
        @NotNull Long transactionId,
        @NotBlank String name,
        @NotNull @DecimalMin("1.00") BigDecimal plannedMonthly
) {
}
