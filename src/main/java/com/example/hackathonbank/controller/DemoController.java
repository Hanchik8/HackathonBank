package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.AccountAdjustmentRequest;
import com.example.hackathonbank.controller.dto.BooleanSettingRequest;
import com.example.hackathonbank.controller.dto.BooleanSettingResponse;
import com.example.hackathonbank.controller.dto.DateSettingRequest;
import com.example.hackathonbank.controller.dto.DateSettingResponse;
import com.example.hackathonbank.controller.dto.TransactionResponse;
import com.example.hackathonbank.service.TransactionService;
import com.example.hackathonbank.service.UserSettingsService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/demo")
public class DemoController {

    private final UserSettingsService userSettingsService;
    private final TransactionService transactionService;

    public DemoController(UserSettingsService userSettingsService,
                          TransactionService transactionService) {
        this.userSettingsService = userSettingsService;
        this.transactionService = transactionService;
    }

    @GetMapping("/admin-mode")
    public BooleanSettingResponse getAdminMode() {
        return new BooleanSettingResponse(userSettingsService.isAdminModeEnabled());
    }

    @PostMapping("/admin-mode")
    public void setAdminMode(@Valid @RequestBody BooleanSettingRequest request) {
        userSettingsService.setAdminModeEnabled(request.enabled());
    }

    @GetMapping("/date")
    public DateSettingResponse getDate() {
        return new DateSettingResponse(userSettingsService.currentDate());
    }

    @PostMapping("/date")
    public void setDate(@Valid @RequestBody DateSettingRequest request) {
        userSettingsService.setEffectiveDate(request.date());
    }

    @PostMapping("/accounts/{accountId}/adjust")
    public TransactionResponse adjustBalance(@PathVariable Long accountId,
                                             @Valid @RequestBody AccountAdjustmentRequest request) {
        return transactionService.adjustAccountBalance(accountId, request.delta(), request.title());
    }
}
