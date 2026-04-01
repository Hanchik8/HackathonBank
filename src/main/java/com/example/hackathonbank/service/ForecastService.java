package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.DashboardPoint;
import com.example.hackathonbank.ai.dto.ScheduledPaymentSnapshot;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.ScheduledPayment;
import org.springframework.beans.factory.annotation.Autowired;
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
    private final UserSettingsService userSettingsService;

    @Autowired
    public ForecastService(AccountService accountService,
                           ScheduledPaymentService scheduledPaymentService,
                           UserSettingsService userSettingsService) {
        this.accountService = accountService;
        this.scheduledPaymentService = scheduledPaymentService;
        this.userSettingsService = userSettingsService;
    }

    public AiDashboardResponse buildDashboard(int offsetDays) {
        int horizonDays = Math.max(0, offsetDays);
        Account mainAccount = accountService.getAccountByType(AccountType.MAIN);
        Account savingsAccount = accountService.getAccountByType(AccountType.SAVINGS);
        List<ScheduledPayment> pendingPayments = scheduledPaymentService.getPendingPayments();

        LocalDate today = currentDate();
        BigDecimal minimumProjectedBalance = mainAccount.getBalance();
        List<DashboardPoint> points = new ArrayList<>();
        List<ScheduledPayment> paymentsInWindow = pendingPayments.stream()
                .filter(payment -> !payment.getDueDate().isBefore(today))
                .filter(payment -> !payment.getDueDate().isAfter(today.plusDays(horizonDays)))
                .toList();

        BigDecimal runningBalance = mainAccount.getBalance();
        for (int day = 0; day <= horizonDays; day++) {
            LocalDate targetDate = today.plusDays(day);
            if (day > 0) {
                BigDecimal dailyOutflow = paymentsInWindow.stream()
                        .filter(payment -> payment.getDueDate().isEqual(targetDate))
                        .map(ScheduledPayment::getAmount)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);
                runningBalance = runningBalance.subtract(dailyOutflow);
            }
            if (runningBalance.compareTo(minimumProjectedBalance) < 0) {
                minimumProjectedBalance = runningBalance;
            }
            points.add(new DashboardPoint(day, targetDate.toString(), targetDate.format(LABEL_FORMATTER), runningBalance));
        }

        List<ScheduledPaymentSnapshot> paymentSnapshots = paymentsInWindow.stream()
                .map(payment -> new ScheduledPaymentSnapshot(
                        payment.getId(),
                        payment.getAccount().getId(),
                        payment.getAccount().getName(),
                        payment.getTitle(),
                        payment.getCounterparty(),
                        payment.getCategory(),
                        payment.getIconKey(),
                        payment.getAmount(),
                        payment.getDueDate(),
                        payment.getStatus().name(),
                        payment.isReminder()
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

    private LocalDate currentDate() {
        return userSettingsService.currentDate();
    }
}
