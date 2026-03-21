package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ScheduledPaymentResponse(
        Long id,
        Long accountId,
        String accountName,
        String title,
        String counterparty,
        String category,
        String iconKey,
        BigDecimal amount,
        LocalDate dueDate,
        String status,
        boolean isReminder
) {
}
