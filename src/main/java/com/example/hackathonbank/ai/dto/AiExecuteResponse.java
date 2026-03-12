package com.example.hackathonbank.ai.dto;

import java.math.BigDecimal;

public record AiExecuteResponse(boolean success, String message, BigDecimal currentBalance, BigDecimal savingsBalance) {
}
