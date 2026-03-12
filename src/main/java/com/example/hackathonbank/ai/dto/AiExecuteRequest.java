package com.example.hackathonbank.ai.dto;

import jakarta.validation.constraints.NotBlank;

public record AiExecuteRequest(@NotBlank String actionToken) {
}
