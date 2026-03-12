package com.example.hackathonbank.ai.dto;

import java.math.BigDecimal;
import java.util.List;

public record AiDashboardResponse(
        BigDecimal currentBalance,
        BigDecimal savingsBalance,
        BigDecimal minimumProjectedBalance,
        int horizonDays,
        List<DashboardPoint> points,
        List<ScheduledPaymentSnapshot> scheduledPayments
) {
}
