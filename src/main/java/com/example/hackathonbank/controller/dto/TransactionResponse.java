package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record TransactionResponse(
        Long id,
        String title,
        String counterparty,
        BigDecimal amount,
        String category,
        String iconKey,
        String type,
        String status,
        String accountName,
        LocalDateTime occurredAt,
        Long smartCategoryId,
        String smartCategoryName
) {
}
