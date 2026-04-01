package com.example.hackathonbank.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

public record AiChatResponse(
        @NotNull @Valid ChatMessageDto message
) {
}
