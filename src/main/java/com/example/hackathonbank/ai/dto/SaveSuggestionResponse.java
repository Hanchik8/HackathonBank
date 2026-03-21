package com.example.hackathonbank.ai.dto;

import java.math.BigDecimal;

public record SaveSuggestionResponse(
        BigDecimal amount,
        String reason,
        BigDecimal safetyReserve,
        BigDecimal currentBalance,
        BigDecimal scheduledOutflow,
        BigDecimal smartListReserve,
        BigDecimal freeAmount
) {
}
