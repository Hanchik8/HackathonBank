package com.example.hackathonbank.controller.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record DateSettingRequest(@NotNull LocalDate date) {
}
