package com.example.hackathonbank.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

import java.util.List;

public record AiChatRequest(
        List<@Valid ChatMessageDto> history,
        @NotBlank String newMessage
) {

    public AiChatRequest {
        history = history == null ? List.of() : List.copyOf(history);
    }
}
