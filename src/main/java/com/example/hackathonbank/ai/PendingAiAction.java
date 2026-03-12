package com.example.hackathonbank.ai;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PendingAiAction(
        String actionToken,
        AgentActionType actionType,
        String message,
        BigDecimal amount,
        Long paymentId,
        LocalDateTime createdAt
) {
}
