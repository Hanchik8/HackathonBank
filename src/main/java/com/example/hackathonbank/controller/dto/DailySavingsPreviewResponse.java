package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record DailySavingsPreviewResponse(
        boolean enabled,
        BigDecimal suggestedAmount,
        BigDecimal safeBalance,
        BigDecimal currentBalance,
        BigDecimal requiredPayments,
        BigDecimal lifeBuffer,
        LocalDate nextIncomeDate,
        int daysToNextIncome,
        String status,
        BigDecimal guardReserve,
        BigDecimal projectedMinimumBalanceAfterTransfer,
        boolean overdraftGuardTriggered,
        int incomeConfidence,
        BigDecimal expectedIncomeAmount,
        String expectedIncomeType
) {
}
