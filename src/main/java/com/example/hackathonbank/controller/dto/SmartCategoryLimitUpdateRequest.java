package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record SmartCategoryLimitUpdateRequest(
        @NotNull @DecimalMin("1.00") BigDecimal plannedMonthly
) {
}
