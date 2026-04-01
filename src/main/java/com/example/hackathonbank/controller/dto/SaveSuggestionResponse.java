package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;

public record SaveSuggestionResponse(
        BigDecimal amount,
        String reason,
        BigDecimal safetyReserve
) {
}
