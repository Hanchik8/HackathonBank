package com.example.hackathonbank.ai;

import java.math.BigDecimal;

public record ActionExecutionResult(String actionType, String message, BigDecimal currentBalance, BigDecimal savingsBalance) {
}
