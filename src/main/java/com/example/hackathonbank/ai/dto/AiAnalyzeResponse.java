package com.example.hackathonbank.ai.dto;

import java.util.List;

public record AiAnalyzeResponse(
        boolean hasAlert,
        String message,
        String actionToken,
        List<BalanceSuggestionResponse> suggestions
) {
}
