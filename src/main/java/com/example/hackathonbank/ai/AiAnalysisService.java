package com.example.hackathonbank.ai;

import com.example.hackathonbank.ai.dto.AiAnalyzeResponse;
import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.AiExecuteRequest;
import com.example.hackathonbank.ai.dto.AiExecuteResponse;
import com.example.hackathonbank.ai.dto.EnrichmentSummary;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.service.AccountService;
import com.example.hackathonbank.service.ForecastService;
import com.example.hackathonbank.service.ScheduledPaymentService;
import com.example.hackathonbank.service.TransactionService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class AiAnalysisService {

    private static final Logger log = LoggerFactory.getLogger(AiAnalysisService.class);

    private final ForecastService forecastService;
    private final TransactionService transactionService;
    private final ScheduledPaymentService scheduledPaymentService;
    private final TransactionEnrichmentService transactionEnrichmentService;
    private final PendingActionRegistry pendingActionRegistry;
    private final AccountService accountService;
    private final BankingAgentTools bankingAgentTools;
    private final AiCapabilityService aiCapabilityService;
    private final ChatClient aiChatClient;
    private final AiCallExecutor aiCallExecutor;

    public AiAnalysisService(ForecastService forecastService,
                             TransactionService transactionService,
                             ScheduledPaymentService scheduledPaymentService,
                             TransactionEnrichmentService transactionEnrichmentService,
                             PendingActionRegistry pendingActionRegistry,
                             AccountService accountService,
                             BankingAgentTools bankingAgentTools,
                             AiCapabilityService aiCapabilityService,
                             ChatClient aiChatClient,
                             AiCallExecutor aiCallExecutor) {
        this.forecastService = forecastService;
        this.transactionService = transactionService;
        this.scheduledPaymentService = scheduledPaymentService;
        this.transactionEnrichmentService = transactionEnrichmentService;
        this.pendingActionRegistry = pendingActionRegistry;
        this.accountService = accountService;
        this.bankingAgentTools = bankingAgentTools;
        this.aiCapabilityService = aiCapabilityService;
        this.aiChatClient = aiChatClient;
        this.aiCallExecutor = aiCallExecutor;
    }

    @Transactional(readOnly = true)
    public AiAnalyzeResponse analyze() {
        AiDashboardResponse dashboard = forecastService.buildDashboard(10);
        List<Transaction> transactions = transactionService.getTransactionsForCurrentUser();
        List<ScheduledPayment> pendingPayments = scheduledPaymentService.getPendingPayments();
        EnrichmentSummary enrichmentSummary = transactionEnrichmentService.enrich(
                transactions,
                pendingPayments,
                dashboard.minimumProjectedBalance()
        );
        if (enrichmentSummary == null) {
            throw new IllegalStateException("AI enrichment summary was not generated.");
        }

        if (dashboard.minimumProjectedBalance().compareTo(BigDecimal.ZERO) >= 0) {
            return new AiAnalyzeResponse(false, enrichmentSummary.reasoning(), null);
        }

        BigDecimal gapAmount = dashboard.minimumProjectedBalance().abs();
        BigDecimal savingsBalance = accountService.getAccountByType(AccountType.SAVINGS).getBalance();
        ScheduledPayment nextPayment = pendingPayments.stream().findFirst().orElse(null);

        PendingAiAction action;
        if (savingsBalance.compareTo(gapAmount) >= 0) {
            action = new PendingAiAction(
                    UUID.randomUUID().toString(),
                    AgentActionType.AUTO_TRANSFER,
                    buildTransferMessage(gapAmount, nextPayment, enrichmentSummary),
                    gapAmount,
                    null,
                    LocalDateTime.now()
            );
        } else if (nextPayment != null) {
            action = new PendingAiAction(
                    UUID.randomUUID().toString(),
                    AgentActionType.POSTPONE_PAYMENT,
                    buildPostponeMessage(nextPayment, enrichmentSummary),
                    null,
                    nextPayment.getId(),
                    LocalDateTime.now()
            );
        } else {
            return new AiAnalyzeResponse(true, "Найден риск кассового разрыва, но подходящее действие не определено.", null);
        }

        pendingActionRegistry.register(action);
        return new AiAnalyzeResponse(true, action.message(), action.actionToken());
    }

    @Transactional
    public AiExecuteResponse execute(AiExecuteRequest request) {
        PendingAiAction action = pendingActionRegistry.require(request.actionToken());
        ActionExecutionResult executionResult = executeApprovedAction(action);
        pendingActionRegistry.remove(request.actionToken());
        return new AiExecuteResponse(
                true,
                executionResult.message(),
                executionResult.currentBalance(),
                executionResult.savingsBalance()
        );
    }

    private ActionExecutionResult executeApprovedAction(PendingAiAction action) {
        if (aiCapabilityService.isLiveAiEnabled()) {
            try {
                String message = aiCallExecutor.execute(() -> aiChatClient.prompt()
                        .system("""
                                Ты zero-click банковский агент исполнения.
                                Пользователь уже подтвердил действие.
                                Обязательно вызови ровно один подходящий инструмент и затем кратко подтверди результат на русском.
                                """)
                        .tools(bankingAgentTools)
                        .user(executionPrompt(action))
                        .call()
                        .content());

                return new ActionExecutionResult(
                        action.actionType().name(),
                        message == null || message.isBlank() ? fallbackExecutionMessage(action) : message,
                        accountService.getAccountByType(AccountType.MAIN).getBalance(),
                        accountService.getAccountByType(AccountType.SAVINGS).getBalance()
                );
            } catch (Exception exception) {
                log.warn("Live tool execution failed, using direct execution: {}", exception.getMessage());
            }
        }
        return directExecute(action);
    }

    private ActionExecutionResult directExecute(PendingAiAction action) {
        return switch (action.actionType()) {
            case AUTO_TRANSFER -> bankingAgentTools.autoTransferFromSavings(action.amount().doubleValue());
            case POSTPONE_PAYMENT -> bankingAgentTools.postponePayment(action.paymentId());
        };
    }

    private String executionPrompt(PendingAiAction action) {
        return switch (action.actionType()) {
            case AUTO_TRANSFER ->
                    "Подтвержденное действие: вызови autoTransferFromSavings с amount=%s и закрой кассовый разрыв."
                            .formatted(action.amount().toPlainString());
            case POSTPONE_PAYMENT ->
                    "Подтвержденное действие: вызови postponePayment с paymentId=%d и отложи ближайший обязательный платеж."
                            .formatted(action.paymentId());
        };
    }

    private String fallbackExecutionMessage(PendingAiAction action) {
        return switch (action.actionType()) {
            case AUTO_TRANSFER -> "AI-резерв выполнен.";
            case POSTPONE_PAYMENT -> "Платеж перенесен.";
        };
    }

    private String buildTransferMessage(BigDecimal gapAmount,
                                        ScheduledPayment nextPayment,
                                        EnrichmentSummary enrichmentSummary) {
        String reasoning = enrichmentSummary != null && enrichmentSummary.reasoning() != null
                ? enrichmentSummary.reasoning()
                : "Обнаружен риск кассового разрыва по регулярным расходам.";
        String paymentPart = nextPayment == null
                ? "Ближайшая просадка уводит основной счет в минус."
                : "Платеж \"%s\" на %s KGS через %s дн. уводит основной счет в минус."
                .formatted(nextPayment.getTitle(), nextPayment.getAmount().toPlainString(), nextPayment.getDueDate().toEpochDay() - LocalDate.now().toEpochDay());
        return "%s %s Рекомендую перевести %s KGS со счета сбережений."
                .formatted(paymentPart, reasoning, gapAmount.toPlainString());
    }

    private String buildPostponeMessage(ScheduledPayment nextPayment, EnrichmentSummary enrichmentSummary) {
        String reasoning = enrichmentSummary != null && enrichmentSummary.reasoning() != null
                ? enrichmentSummary.reasoning()
                : "Обнаружен риск кассового разрыва по регулярным расходам.";
        return "На счете сбережений уже недостаточно средств, чтобы покрыть \"%s\" на %s KGS. %s Рекомендую перенести платеж."
                .formatted(nextPayment.getTitle(), nextPayment.getAmount().toPlainString(), reasoning);
    }
}
