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
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class ForecastService {

    private static final DateTimeFormatter LABEL_FORMATTER =
            DateTimeFormatter.ofPattern("dd MMM", Locale.forLanguageTag("ru-RU"));

    private final AccountService accountService;
    private final ScheduledPaymentService scheduledPaymentService;
    private final UserSettingsService userSettingsService;
    private final UserContextService userContextService;
    private final IncomeCalendarService incomeCalendarService;
    private final SpendProfileService spendProfileService;

    public ForecastService(AccountService accountService,
                           ScheduledPaymentService scheduledPaymentService,
                           UserSettingsService userSettingsService,
                           UserContextService userContextService,
                           IncomeCalendarService incomeCalendarService,
                           SpendProfileService spendProfileService) {
        this.accountService = accountService;
        this.scheduledPaymentService = scheduledPaymentService;
        this.userSettingsService = userSettingsService;
        this.userContextService = userContextService;
        this.incomeCalendarService = incomeCalendarService;
        this.spendProfileService = spendProfileService;
    }

    public AiDashboardResponse buildDashboard(int offsetDays) {
        int horizonDays = Math.max(0, offsetDays);
        Long userId = userContextService.getCurrentUser().getId();
        Account mainAccount = accountService.getAccountByType(AccountType.MAIN);
        Account savingsAccount = accountService.getAccountByType(AccountType.SAVINGS);
        List<ScheduledPayment> pendingPayments = scheduledPaymentService.getPendingPayments();

        LocalDate today = currentDate();
        IncomeCalendarService.IncomeCalendar incomeCalendar = incomeCalendarService.buildCalendar(userId, today);
        SpendProfileService.SpendProfile spendProfile = spendProfileService.buildProfile(userId, today);

        List<ScheduledPayment> paymentsInWindow = pendingPayments.stream()
                .filter(payment -> !payment.getDueDate().isBefore(today))
                .filter(payment -> !payment.getDueDate().isAfter(today.plusDays(horizonDays)))
                .sorted(Comparator.comparing(ScheduledPayment::getDueDate))
                .toList();
        Map<LocalDate, BigDecimal> paymentsByDate = paymentsInWindow.stream()
                .collect(Collectors.groupingBy(
                        ScheduledPayment::getDueDate,
                        Collectors.reducing(BigDecimal.ZERO, ScheduledPayment::getAmount, BigDecimal::add)
                ));

        BigDecimal minimumProjectedBalance = mainAccount.getBalance();
        List<DashboardPoint> points = new ArrayList<>();
        BigDecimal runningBalance = mainAccount.getBalance();

        for (int day = 0; day <= horizonDays; day++) {
            LocalDate targetDate = today.plusDays(day);
            if (day > 0) {
                BigDecimal dailySpend = spendProfile.projectedSpend(targetDate.getDayOfWeek());
                BigDecimal scheduledOutflow = paymentsByDate.getOrDefault(targetDate, BigDecimal.ZERO);
                BigDecimal projectedIncome = projectedIncomeForDate(incomeCalendar, targetDate);
                runningBalance = runningBalance
                        .subtract(dailySpend)
                        .subtract(scheduledOutflow)
                        .add(projectedIncome);
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
                        payment.isReminder(),
                        payment.isFlexible()
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

    private BigDecimal projectedIncomeForDate(IncomeCalendarService.IncomeCalendar calendar, LocalDate date) {
        BigDecimal income = BigDecimal.ZERO;
        for (IncomeCalendarService.IncomeCluster cluster : calendar.clusters()) {
            if (cluster.confidence() < 50.0) {
                continue;
            }
            if (matchesClusterDay(date, cluster)) {
                income = income.add(cluster.averageAmount());
            }
        }
        return income;
    }

    private boolean matchesClusterDay(LocalDate date, IncomeCalendarService.IncomeCluster cluster) {
        int normalizedDay = Math.min(cluster.dayOfMonth(), date.lengthOfMonth());
        int tolerance = cluster.confidence() >= 100.0 ? 1 : 2;
        int actualDay = date.getDayOfMonth();
        return Math.abs(actualDay - normalizedDay) <= tolerance;
    }

    private LocalDate currentDate() {
        return userSettingsService.currentDate();
    }
}
