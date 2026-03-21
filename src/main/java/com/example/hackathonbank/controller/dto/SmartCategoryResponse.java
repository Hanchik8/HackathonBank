package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;

public record SmartCategoryResponse(
        Long id,
        String name,
        BigDecimal plannedMonthly,
        BigDecimal remaining,
        boolean isFavorite
) {
}
