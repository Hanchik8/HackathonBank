package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.DashboardPoint;
import com.example.hackathonbank.ai.dto.ScheduledPaymentSnapshot;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

@Service
@Transactional(readOnly = true)
public class ForecastService {

    private static final DateTimeFormatter LABEL_FORMATTER =
            DateTimeFormatter.ofPattern("dd MMM", Locale.forLanguageTag("ru-RU"));

    private final CashFlowProjectionService cashFlowProjectionService;
    private final UserSettingsService userSettingsService;
    private final UserContextService userContextService;

    public ForecastService(CashFlowProjectionService cashFlowProjectionService,
                           UserSettingsService userSettingsService,
                           UserContextService userContextService) {
        this.cashFlowProjectionService = cashFlowProjectionService;
        this.userSettingsService = userSettingsService;
        this.userContextService = userContextService;
    }

    public AiDashboardResponse buildDashboard(int offsetDays) {
        int horizonDays = Math.max(0, offsetDays);
        Long userId = userContextService.getCurrentUser().getId();
        LocalDate today = userSettingsService.currentDate();

        CashFlowProjectionService.CashFlowProjection projection =
                cashFlowProjectionService.buildProjection(userId, today, horizonDays);

        List<DashboardPoint> points = projection.days().stream()
                .map(day -> new DashboardPoint(
                        day.dayOffset(),
                        day.date().toString(),
                        day.date().format(LABEL_FORMATTER),
                        day.balance(),
                        day.projectedIncome(),
                        day.totalOutflow()
                ))
                .toList();

        List<ScheduledPaymentSnapshot> paymentSnapshots = projection.confirmedPayments().stream()
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
                        payment.isReminder(),
                        payment.isFlexible()
                ))
                .toList();

        return new AiDashboardResponse(
                projection.mainAccount().getBalance(),
                projection.savingsAccount().getBalance(),
                projection.minimumBalance(),
                horizonDays,
                points,
                paymentSnapshots
        );
    }
}
