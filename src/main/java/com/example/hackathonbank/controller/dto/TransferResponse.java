package com.example.hackathonbank.controller.dto;

public record TransferResponse(String message, AccountResponse fromAccount, AccountResponse toAccount) {
}
