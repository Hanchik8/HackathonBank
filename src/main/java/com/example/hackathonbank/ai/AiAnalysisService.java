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
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

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
    public AiAnalyzeResponse analyze(int offsetDays) {
        AiDashboardResponse dashboard = forecastService.buildDashboard(offsetDays);
        List<Transaction> transactions = transactionService.getTransactionsForCurrentUser();
        List<ScheduledPayment> pendingPayments = scheduledPaymentService.getPendingPayments();
        EnrichmentSummary enrichmentSummary = transactionEnrichmentService.enrich(
                transactions,
                pendingPayments,
                dashboard.minimumProjectedBalance()
        );

        if (dashboard.minimumProjectedBalance().compareTo(BigDecimal.ZERO) >= 0) {
            return new AiAnalyzeResponse(false, enrichmentSummary.reasoning(), null);
        }

        BigDecimal gapAmount = dashboard.minimumProjectedBalance().abs();
        BigDecimal savingsBalance = accountService.getAccountByType(AccountType.SAVINGS).getBalance();
        List<ScheduledPayment> riskyPayments = selectRiskyPayments(pendingPayments, dashboard.horizonDays());
        ScheduledPayment criticalPayment = selectCriticalPayment(riskyPayments, dashboard.currentBalance());

        PendingAiAction action;
        if (savingsBalance.compareTo(gapAmount) >= 0) {
            action = new PendingAiAction(
                    UUID.randomUUID().toString(),
                    AgentActionType.AUTO_TRANSFER,
                    buildTransferMessage(gapAmount, criticalPayment, riskyPayments, enrichmentSummary),
                    gapAmount,
                    null,
                    LocalDateTime.now()
            );
        } else if (criticalPayment != null) {
            action = new PendingAiAction(
                    UUID.randomUUID().toString(),
                    AgentActionType.POSTPONE_PAYMENT,
                    buildPostponeMessage(criticalPayment, riskyPayments, enrichmentSummary),
                    null,
                    criticalPayment.getId(),
                    LocalDateTime.now()
            );
        } else {
            return new AiAnalyzeResponse(
                    true,
                    "Найден риск кассового разрыва, но подходящее действие не определено.",
                    null
            );
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
                    "Подтвержденное действие: вызови postponePayment с paymentId=%d и перенеси критичный обязательный платеж."
                            .formatted(action.paymentId());
        };
    }

    private String fallbackExecutionMessage(PendingAiAction action) {
        return switch (action.actionType()) {
            case AUTO_TRANSFER -> "Перевод из сбережений выполнен.";
            case POSTPONE_PAYMENT -> "Платеж перенесен.";
        };
    }

    private List<ScheduledPayment> selectRiskyPayments(List<ScheduledPayment> pendingPayments, int horizonDays) {
        LocalDate horizonDate = LocalDate.now().plusDays(Math.max(0, horizonDays));
        return pendingPayments.stream()
                .filter(payment -> !payment.getDueDate().isAfter(horizonDate))
                .sorted(
                        Comparator.comparing(ScheduledPayment::getDueDate)
                                .thenComparing(ScheduledPayment::getAmount, Comparator.reverseOrder())
                )
                .toList();
    }

    private ScheduledPayment selectCriticalPayment(List<ScheduledPayment> riskyPayments, BigDecimal currentBalance) {
        if (riskyPayments.isEmpty()) {
            return null;
        }

        BigDecimal runningBalance = currentBalance;
        ScheduledPayment latestCandidate = riskyPayments.get(0);
        for (ScheduledPayment payment : riskyPayments) {
            runningBalance = runningBalance.subtract(payment.getAmount());
            latestCandidate = payment;
            if (runningBalance.compareTo(BigDecimal.ZERO) < 0) {
                return payment;
            }
        }
        return latestCandidate;
    }

    private String buildTransferMessage(BigDecimal gapAmount,
                                        ScheduledPayment criticalPayment,
                                        List<ScheduledPayment> riskyPayments,
                                        EnrichmentSummary enrichmentSummary) {
        String reasoning = normalizeReasoning(enrichmentSummary);
        String paymentPart = criticalPayment == null
                ? "В ближайшем горизонте есть обязательные списания, которые уводят основной счет в минус."
                : "Критичное списание \"%s\" на %s KGS назначено на %s."
                .formatted(
                        criticalPayment.getTitle(),
                        criticalPayment.getAmount().toPlainString(),
                        criticalPayment.getDueDate()
                );
        String stackPart = summarizePayments(riskyPayments, criticalPayment);
        return "%s %s %s Рекомендую перевести %s KGS со счета сбережений."
                .formatted(paymentPart, stackPart, reasoning, gapAmount.toPlainString())
                .trim();
    }

    private String buildPostponeMessage(ScheduledPayment criticalPayment,
                                        List<ScheduledPayment> riskyPayments,
                                        EnrichmentSummary enrichmentSummary) {
        String reasoning = normalizeReasoning(enrichmentSummary);
        String stackPart = summarizePayments(riskyPayments, criticalPayment);
        return "Подушки на счете сбережений уже недостаточно, чтобы покрыть \"%s\" на %s KGS. %s %s Рекомендую перенести именно этот платеж."
                .formatted(
                        criticalPayment.getTitle(),
                        criticalPayment.getAmount().toPlainString(),
                        stackPart,
                        reasoning
                )
                .trim();
    }

    private String summarizePayments(List<ScheduledPayment> riskyPayments, ScheduledPayment criticalPayment) {
        List<ScheduledPayment> supportingPayments = riskyPayments.stream()
                .filter(payment -> criticalPayment == null || !payment.getId().equals(criticalPayment.getId()))
                .limit(2)
                .toList();
        if (supportingPayments.isEmpty()) {
            return "";
        }
        String summary = supportingPayments.stream()
                .map(payment -> "\"%s\" %s KGS %s".formatted(
                        payment.getTitle(),
                        payment.getAmount().toPlainString(),
                        payment.getDueDate()))
                .collect(Collectors.joining(", "));
        return "Следом идут: %s.".formatted(summary);
    }

    private String normalizeReasoning(EnrichmentSummary enrichmentSummary) {
        if (enrichmentSummary == null || enrichmentSummary.reasoning() == null || enrichmentSummary.reasoning().isBlank()) {
            return "Регулярные расходы и запланированные списания создают риск кассового разрыва.";
        }
        return enrichmentSummary.reasoning();
    }
}
