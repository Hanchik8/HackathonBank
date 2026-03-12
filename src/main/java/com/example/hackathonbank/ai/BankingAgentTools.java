package com.example.hackathonbank.ai;

import com.example.hackathonbank.service.ScheduledPaymentService;
import com.example.hackathonbank.service.TransferService;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
public class BankingAgentTools {

    private final TransferService transferService;
    private final ScheduledPaymentService scheduledPaymentService;

    public BankingAgentTools(TransferService transferService, ScheduledPaymentService scheduledPaymentService) {
        this.transferService = transferService;
        this.scheduledPaymentService = scheduledPaymentService;
    }

    @Tool(description = "Перевести деньги со счета сбережений на основной счет, чтобы закрыть кассовый разрыв.")
    public ActionExecutionResult autoTransferFromSavings(double amount) {
        return transferService.autoTransferFromSavings(BigDecimal.valueOf(amount));
    }

    @Tool(description = "Перенести запланированный платеж на семь дней, чтобы избежать кассового разрыва.")
    public ActionExecutionResult postponePayment(Long paymentId) {
        return scheduledPaymentService.postponePayment(paymentId);
    }
}
