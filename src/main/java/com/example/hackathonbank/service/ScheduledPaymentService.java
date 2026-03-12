package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.ai.AgentActionType;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ScheduledPaymentService {

    private final ScheduledPaymentRepository scheduledPaymentRepository;
    private final TransactionRepository transactionRepository;
    private final UserContextService userContextService;
    private final AccountService accountService;

    public ScheduledPaymentService(ScheduledPaymentRepository scheduledPaymentRepository,
                                   TransactionRepository transactionRepository,
                                   UserContextService userContextService,
                                   AccountService accountService) {
        this.scheduledPaymentRepository = scheduledPaymentRepository;
        this.transactionRepository = transactionRepository;
        this.userContextService = userContextService;
        this.accountService = accountService;
    }

    @Transactional(readOnly = true)
    public List<ScheduledPayment> getPendingPayments() {
        return scheduledPaymentRepository.findByUserIdAndStatusInOrderByDueDateAsc(
                userContextService.getCurrentUser().getId(),
                List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED)
        );
    }

    @Transactional
    public ActionExecutionResult postponePayment(Long paymentId) {
        ScheduledPayment payment = scheduledPaymentRepository.findById(paymentId)
                .orElseThrow(() -> new IllegalArgumentException("Автоплатеж %d не найден.".formatted(paymentId)));
        if (!payment.getUser().getId().equals(userContextService.getCurrentUser().getId())) {
            throw new IllegalArgumentException("Автоплатеж недоступен текущему пользователю.");
        }

        payment.postponeByDays(7);
        scheduledPaymentRepository.save(payment);
        transactionRepository.findByScheduledPaymentId(paymentId).ifPresent(transaction -> transaction.reschedule(payment.getDueDate()));

        return new ActionExecutionResult(
                AgentActionType.POSTPONE_PAYMENT.name(),
                "Аренда перенесена на %s.".formatted(payment.getDueDate()),
                accountService.getAccountByType(AccountType.MAIN).getBalance(),
                accountService.getAccountByType(AccountType.SAVINGS).getBalance()
        );
    }
}
