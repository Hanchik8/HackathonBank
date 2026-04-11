package com.example.hackathonbank.ai;

import java.math.BigDecimal;

public record SmartCategoryToolResult(
        String operation,
        Long categoryId,
        String name,
        BigDecimal plannedMonthly,
        BigDecimal remaining,
        String message,
        String confirmationToken
) {
}
