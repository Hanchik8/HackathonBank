package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ScheduledPaymentRequest(
        @NotNull Long accountId,
        @NotBlank String title,
        String counterparty,
        @NotBlank String category,
        @NotNull @DecimalMin("1.00") BigDecimal amount,
        @NotNull LocalDate dueDate,
        Boolean isReminder,
        Boolean flexible
) {

    public ScheduledPaymentRequest(Long accountId,
                                   String title,
                                   String counterparty,
                                   String category,
                                   BigDecimal amount,
                                   LocalDate dueDate) {
        this(accountId, title, counterparty, category, amount, dueDate, true, null);
    }

    public ScheduledPaymentRequest(Long accountId,
                                   String title,
                                   String counterparty,
                                   String category,
                                   BigDecimal amount,
                                   LocalDate dueDate,
                                   Boolean isReminder) {
        this(accountId, title, counterparty, category, amount, dueDate, isReminder, null);
    }
}
