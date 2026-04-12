package com.example.hackathonbank.ai;

import com.example.hackathonbank.service.PendingAiActionService;
import com.example.hackathonbank.service.ScheduledPaymentService;
import com.example.hackathonbank.service.SmartCategoryService;
import com.example.hackathonbank.service.TransferService;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
public class BankingAgentTools {

    private final TransferService transferService;
    private final ScheduledPaymentService scheduledPaymentService;
    private final SmartCategoryService smartCategoryService;
    private final PendingAiActionService pendingAiActionService;

    public BankingAgentTools(TransferService transferService,
                             ScheduledPaymentService scheduledPaymentService,
                             SmartCategoryService smartCategoryService,
                             PendingAiActionService pendingAiActionService) {
        this.transferService = transferService;
        this.scheduledPaymentService = scheduledPaymentService;
        this.smartCategoryService = smartCategoryService;
        this.pendingAiActionService = pendingAiActionService;
    }

    @Tool(description = "Transfer money from savings to the main account to cover a cash gap.")
    public ActionExecutionResult autoTransferFromSavings(String amount) {
        return transferService.autoTransferFromSavings(new BigDecimal(amount));
    }

    @Tool(description = "Postpone a scheduled payment by seven days to avoid a cash gap.")
    public ActionExecutionResult postponePayment(Long paymentId) {
        return scheduledPaymentService.postponePayment(paymentId);
    }

    @Tool(description = "Create a Smart List category with a monthly spending limit in KGS.")
    public SmartCategoryToolResult createSmartCategory(String name, String limit) {
        var category = smartCategoryService.createCategory(name, new BigDecimal(limit));
        return new SmartCategoryToolResult(
                "create",
                category.id(),
                category.name(),
                category.plannedMonthly(),
                category.remaining(),
                "Smart List category created.",
                null
        );
    }

    @Tool(description = "Update the monthly limit of an existing Smart List category in KGS.")
    public SmartCategoryToolResult updateSmartCategoryLimit(Long categoryId, String newLimit) {
        var category = smartCategoryService.updateCategoryLimit(categoryId, new BigDecimal(newLimit));
        return new SmartCategoryToolResult(
                "update_limit",
                category.id(),
                category.name(),
                category.plannedMonthly(),
                category.remaining(),
                "Smart List category limit updated.",
                null
        );
    }

    @Tool(description = "Request deletion of an existing Smart List category. The user must confirm before removal.")
    public SmartCategoryToolResult deleteSmartCategory(Long categoryId) {
        var category = smartCategoryService.getOwnedCategory(categoryId);
        var pendingAction = pendingAiActionService.registerDeleteSmartCategory(category);
        return new SmartCategoryToolResult(
                "delete_pending_confirmation",
                categoryId,
                category.getName(),
                category.getPlannedMonthly(),
                category.getPlannedMonthly(),
                "Deletion requires user confirmation.",
                pendingAction.token()
        );
    }
}
