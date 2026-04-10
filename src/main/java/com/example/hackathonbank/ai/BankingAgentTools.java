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
    public ActionExecutionResult autoTransferFromSavings(String amount) {
        return transferService.autoTransferFromSavings(new BigDecimal(amount));
    }

    @Tool(description = "Перенести запланированный платеж на семь дней, чтобы избежать кассового разрыва.")
    public ActionExecutionResult postponePayment(Long paymentId) {
        return scheduledPaymentService.postponePayment(paymentId);
    }

    @Tool(description = "Получить список будущих (ожидающих) запланированных платежей пользователя.")
    public java.util.List<com.example.hackathonbank.model.ScheduledPayment> getUpcomingScheduledPayments() {
        return scheduledPaymentService.getPendingPayments();
    }
}
