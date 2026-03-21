package com.example.hackathonbank.ai.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ScheduledPaymentSnapshot(
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
