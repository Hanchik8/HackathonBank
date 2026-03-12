package com.example.hackathonbank.ai.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record EnrichmentSummary(List<EnrichmentGroup> groups, String riskLevel, String reasoning) {
}
