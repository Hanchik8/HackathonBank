package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CreateLoanRequest(
        @NotNull Long accountId,
        @NotBlank String title,
        @NotNull @DecimalMin("1.00") BigDecimal amount,
        @NotNull @FutureOrPresent LocalDate dueDate
) {
}
