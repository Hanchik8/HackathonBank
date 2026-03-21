package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record DemoSimulateDayResponse(
        LocalDate currentDate,
        BigDecimal currentBalance,
        BigDecimal savingsBalance,
        BigDecimal savedAmount,
        boolean autoSaveExecuted,
        String notification
) {
}
