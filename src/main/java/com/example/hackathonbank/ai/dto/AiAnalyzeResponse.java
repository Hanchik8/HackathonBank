package com.example.hackathonbank.ai.dto;

public record AiAnalyzeResponse(boolean hasAlert, String message, String actionToken) {
}
