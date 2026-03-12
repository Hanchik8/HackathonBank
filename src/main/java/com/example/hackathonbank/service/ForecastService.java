package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.DashboardPoint;
import com.example.hackathonbank.ai.dto.ScheduledPaymentSnapshot;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.ScheduledPayment;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
@Service
@Transactional(readOnly = true)
public class ForecastService {

    private static final DateTimeFormatter LABEL_FORMATTER = DateTimeFormatter.ofPattern("dd MMM", java.util.Locale.forLanguageTag("ru-RU"));

    private final AccountService accountService;
    private final ScheduledPaymentService scheduledPaymentService;

    public ForecastService(AccountService accountService, ScheduledPaymentService scheduledPaymentService) {
        this.accountService = accountService;
        this.scheduledPaymentService = scheduledPaymentService;
    }

    public AiDashboardResponse buildDashboard(int offsetDays) {
        int horizonDays = Math.max(0, Math.min(offsetDays, 10));
        Account mainAccount = accountService.getAccountByType(AccountType.MAIN);
        Account savingsAccount = accountService.getAccountByType(AccountType.SAVINGS);
        List<ScheduledPayment> pendingPayments = scheduledPaymentService.getPendingPayments();

        LocalDate today = LocalDate.now();
        BigDecimal minimumProjectedBalance = mainAccount.getBalance();
        List<DashboardPoint> points = new ArrayList<>();

        for (int day = 0; day <= horizonDays; day++) {
            LocalDate targetDate = today.plusDays(day);
            BigDecimal projectedBalance = mainAccount.getBalance().subtract(totalDueByDate(pendingPayments, targetDate));
            if (projectedBalance.compareTo(minimumProjectedBalance) < 0) {
                minimumProjectedBalance = projectedBalance;
            }
            points.add(new DashboardPoint(day, targetDate.toString(), targetDate.format(LABEL_FORMATTER), projectedBalance));
        }

        List<ScheduledPaymentSnapshot> paymentSnapshots = pendingPayments.stream()
                .map(payment -> new ScheduledPaymentSnapshot(
                        payment.getId(),
                        payment.getTitle(),
                        payment.getAmount(),
                        payment.getDueDate(),
                        payment.getStatus().name()
                ))
                .toList();

        return new AiDashboardResponse(
                mainAccount.getBalance(),
                savingsAccount.getBalance(),
                minimumProjectedBalance,
                horizonDays,
                points,
                paymentSnapshots
        );
    }

    private BigDecimal totalDueByDate(List<ScheduledPayment> pendingPayments, LocalDate targetDate) {
        return pendingPayments.stream()
                .filter(payment -> !payment.getDueDate().isAfter(targetDate))
                .map(ScheduledPayment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
