package com.example.hackathonbank.ai.dto;

import java.math.BigDecimal;

public record DashboardPoint(
        int dayOffset,
        String isoDate,
        String label,
        BigDecimal balance,
        BigDecimal projectedIncome,
        BigDecimal projectedExpense
) {
}
