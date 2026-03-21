package com.example.hackathonbank.controller.dto;

import com.example.hackathonbank.model.TransferRecipientType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record ExternalTransferRequest(
        @NotNull Long fromAccountId,
        @NotNull TransferRecipientType recipientType,
        @NotBlank String recipientName,
        @NotNull @DecimalMin("1.00") BigDecimal amount,
        String description,
        String category,
        String iconKey,
        String smartCategoryId
) {

    public ExternalTransferRequest(Long fromAccountId,
                                   TransferRecipientType recipientType,
                                   String recipientName,
                                   BigDecimal amount,
                                   String description) {
        this(fromAccountId, recipientType, recipientName, amount, description, null, null, null);
    }
}
