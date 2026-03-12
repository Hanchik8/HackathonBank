package com.example.hackathonbank.ai.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ScheduledPaymentSnapshot(Long id, String title, BigDecimal amount, LocalDate dueDate, String status) {
}
