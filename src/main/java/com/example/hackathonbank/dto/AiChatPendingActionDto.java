package com.example.hackathonbank.dto;

public record AiChatPendingActionDto(
        String type,
        String token,
        String categoryId,
        String categoryName,
        String title,
        String description
) {
}
