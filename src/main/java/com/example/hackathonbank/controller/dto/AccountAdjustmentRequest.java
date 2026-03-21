package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record AccountAdjustmentRequest(
        @NotNull BigDecimal delta,
        @NotBlank String title
) {
}
