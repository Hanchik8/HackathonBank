package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.BooleanSettingRequest;
import com.example.hackathonbank.controller.dto.BooleanSettingResponse;
import com.example.hackathonbank.controller.dto.SmartCategoryCreateRequest;
import com.example.hackathonbank.controller.dto.SmartCategoryFavoriteRequest;
import com.example.hackathonbank.controller.dto.SmartCategoryLimitUpdateRequest;
import com.example.hackathonbank.controller.dto.SmartCategoryLinkTransactionRequest;
import com.example.hackathonbank.controller.dto.SmartCategoryResponse;
import com.example.hackathonbank.service.SmartCategoryService;
import com.example.hackathonbank.service.TransactionService;
import com.example.hackathonbank.service.UserSettingsService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/smart-categories")
public class SmartCategoryController {

    private final SmartCategoryService smartCategoryService;
    private final TransactionService transactionService;
    private final UserSettingsService userSettingsService;

    public SmartCategoryController(SmartCategoryService smartCategoryService,
                                   TransactionService transactionService,
                                   UserSettingsService userSettingsService) {
        this.smartCategoryService = smartCategoryService;
        this.transactionService = transactionService;
        this.userSettingsService = userSettingsService;
    }

    @GetMapping
    public List<SmartCategoryResponse> getCategories() {
        return smartCategoryService.getCategories();
    }

    @PostMapping
    public SmartCategoryResponse createCategory(@Valid @RequestBody SmartCategoryCreateRequest request) {
        return smartCategoryService.createCategory(request);
    }

    @PostMapping("/link-transaction")
    public SmartCategoryResponse createCategoryAndLinkTransaction(
            @Valid @RequestBody SmartCategoryLinkTransactionRequest request
    ) {
        SmartCategoryResponse category = smartCategoryService.createCategory(
                new SmartCategoryCreateRequest(request.name(), request.plannedMonthly())
        );
        transactionService.assignTransactionToSmartCategory(request.transactionId(), category.id());
        return category;
    }

    @PostMapping("/{categoryId}/favorite")
    public void setFavorite(@PathVariable Long categoryId,
                            @Valid @RequestBody SmartCategoryFavoriteRequest request) {
        smartCategoryService.setFavorite(categoryId, request.isFavorite());
    }

    @PostMapping("/{categoryId}/limit")
    public SmartCategoryResponse updateLimit(@PathVariable Long categoryId,
                                             @Valid @RequestBody SmartCategoryLimitUpdateRequest request) {
        return smartCategoryService.updateCategoryLimit(categoryId, request.plannedMonthly());
    }

    @PostMapping("/{categoryId}/delete")
    public void deleteCategory(@PathVariable Long categoryId) {
        smartCategoryService.deleteCategory(categoryId);
    }

    @GetMapping("/settings")
    public BooleanSettingResponse getSmartListSettings() {
        return new BooleanSettingResponse(userSettingsService.isSmartListEnabled());
    }

    @PostMapping("/settings")
    public void setSmartListSettings(@Valid @RequestBody BooleanSettingRequest request) {
        userSettingsService.setSmartListEnabled(request.enabled());
    }
}
