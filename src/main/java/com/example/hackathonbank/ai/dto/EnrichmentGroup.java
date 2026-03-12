package com.example.hackathonbank.ai.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.math.BigDecimal;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record EnrichmentGroup(String name, BigDecimal total, List<String> patterns) {
}
