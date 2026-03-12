package com.example.hackathonbank.controller.dto;

import java.math.BigDecimal;

public record AccountResponse(Long id, String name, String type, BigDecimal balance, String currency) {
}
