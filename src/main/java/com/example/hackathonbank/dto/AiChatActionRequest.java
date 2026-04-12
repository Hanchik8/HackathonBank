package com.example.hackathonbank.dto;

import jakarta.validation.constraints.NotBlank;

public record AiChatActionRequest(
        @NotBlank String token,
        boolean confirmed
) {
}
