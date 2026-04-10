package com.example.hackathonbank.service;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class CashFlowProjectionService {

    private final AccountRepository accountRepository;
    private final ScheduledPaymentRepository scheduledPaymentRepository;
    private final IncomeCalendarService incomeCalendarService;
    private final SpendProfileService spendProfileService;
    private final RecurringObligationService recurringObligationService;

    public CashFlowProjectionService(AccountRepository accountRepository,
                                     ScheduledPaymentRepository scheduledPaymentRepository,
                                     IncomeCalendarService incomeCalendarService,
                                     SpendProfileService spendProfileService,
                                     RecurringObligationService recurringObligationService) {
        this.accountRepository = accountRepository;
        this.scheduledPaymentRepository = scheduledPaymentRepository;
        this.incomeCalendarService = incomeCalendarService;
        this.spendProfileService = spendProfileService;
        this.recurringObligationService = recurringObligationService;
    }

    public CashFlowProjection buildProjection(Long userId, LocalDate currentDate, int horizonDays) {
        return buildProjection(userId, currentDate, currentDate.plusDays(Math.max(0, horizonDays)), BigDecimal.ZERO);
    }

    public CashFlowProjection buildProjection(Long userId,
                                              LocalDate currentDate,
                                              LocalDate horizonEnd,
                                              BigDecimal immediateTransferAmount) {
        Account mainAccount = accountRepository.findByUserIdAndType(userId, AccountType.MAIN)
                .orElseThrow(() -> new IllegalStateException("Main account not found."));
        Account savingsAccount = accountRepository.findByUserIdAndType(userId, AccountType.SAVINGS)
                .orElseThrow(() -> new IllegalStateException("Savings account not found."));

        LocalDate resolvedHorizonEnd = horizonEnd.isBefore(currentDate) ? currentDate : horizonEnd;

        List<ScheduledPayment> confirmedPayments = scheduledPaymentRepository
                .findByUserIdAndStatusInOrderByDueDateAsc(
                        userId,
                        List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED)
                ).stream()
                .filter(payment -> payment.getAccount().getType() == AccountType.MAIN)
                .filter(payment -> !payment.getDueDate().isBefore(currentDate))
                .filter(payment -> !payment.getDueDate().isAfter(resolvedHorizonEnd))
                .sorted(Comparator.comparing(ScheduledPayment::getDueDate))
                .toList();

        RecurringObligationService.RecurringObligationForecast recurringForecast =
                recurringObligationService.buildForecast(userId, currentDate, resolvedHorizonEnd, confirmedPayments);
        SpendProfileService.SpendProfile spendProfile = spendProfileService.buildProfile(
                userId,
                currentDate,
                recurringForecast.recurringKeys()
        );
        IncomeCalendarService.IncomeCalendar incomeCalendar = incomeCalendarService.buildCalendar(userId, currentDate);
        List<IncomeCalendarService.ProjectedIncomeEvent> incomeEvents = incomeCalendarService.projectedIncomeEvents(
                incomeCalendar,
                currentDate.plusDays(1),
                resolvedHorizonEnd,
                50
        );

        Map<LocalDate, BigDecimal> confirmedPaymentsByDate = confirmedPayments.stream()
                .collect(Collectors.groupingBy(
                        ScheduledPayment::getDueDate,
                        LinkedHashMap::new,
                        Collectors.reducing(BigDecimal.ZERO, ScheduledPayment::getAmount, BigDecimal::add)
                ));
        Map<LocalDate, BigDecimal> inferredPaymentsByDate = recurringForecast.events().stream()
                .collect(Collectors.groupingBy(
                        RecurringObligationService.ProjectedObligationEvent::date,
                        LinkedHashMap::new,
                        Collectors.reducing(BigDecimal.ZERO, RecurringObligationService.ProjectedObligationEvent::weightedAmount, BigDecimal::add)
                ));
        Map<LocalDate, BigDecimal> incomeByDate = incomeEvents.stream()
                .collect(Collectors.groupingBy(
                        IncomeCalendarService.ProjectedIncomeEvent::conservativeDate,
                        LinkedHashMap::new,
                        Collectors.reducing(BigDecimal.ZERO, IncomeCalendarService.ProjectedIncomeEvent::expectedAmount, BigDecimal::add)
                ));

        BigDecimal startingMainBalance = mainAccount.getBalance().subtract(immediateTransferAmount);
        BigDecimal runningBalance = startingMainBalance;
        BigDecimal minimumBalance = runningBalance;
        LocalDate firstNegativeDate = null;
        List<ProjectedCashFlowDay> days = new ArrayList<>();

        int horizonDays = (int) ChronoUnit.DAYS.between(currentDate, resolvedHorizonEnd);
        for (int offset = 0; offset <= horizonDays; offset++) {
            LocalDate date = currentDate.plusDays(offset);
            BigDecimal essentialSpend = BigDecimal.ZERO;
            BigDecimal discretionarySpend = BigDecimal.ZERO;
            BigDecimal confirmedOutflow = BigDecimal.ZERO;
            BigDecimal inferredOutflow = BigDecimal.ZERO;
            BigDecimal projectedIncome = BigDecimal.ZERO;

            if (offset > 0) {
                essentialSpend = spendProfile.projectedEssentialSpend(date.getDayOfWeek());
                discretionarySpend = spendProfile.projectedDiscretionarySpend(date.getDayOfWeek());
                confirmedOutflow = confirmedPaymentsByDate.getOrDefault(date, BigDecimal.ZERO);
                inferredOutflow = inferredPaymentsByDate.getOrDefault(date, BigDecimal.ZERO);
                projectedIncome = incomeByDate.getOrDefault(date, BigDecimal.ZERO);
                runningBalance = runningBalance
                        .subtract(essentialSpend)
                        .subtract(discretionarySpend)
                        .subtract(confirmedOutflow)
                        .subtract(inferredOutflow)
                        .add(projectedIncome);
            }

            if (runningBalance.compareTo(minimumBalance) < 0) {
                minimumBalance = runningBalance;
            }
            if (firstNegativeDate == null && runningBalance.compareTo(BigDecimal.ZERO) < 0) {
                firstNegativeDate = date;
            }
            days.add(new ProjectedCashFlowDay(
                    offset,
                    date,
                    runningBalance,
                    projectedIncome,
                    essentialSpend,
                    discretionarySpend,
                    confirmedOutflow,
                    inferredOutflow
            ));
        }

        BigDecimal confirmedOutflowsTotal = confirmedPayments.stream()
                .map(ScheduledPayment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal inferredOutflowsTotal = recurringForecast.events().stream()
                .map(RecurringObligationService.ProjectedObligationEvent::weightedAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal livingSpendTotal = days.stream()
                .skip(1)
                .map(day -> day.essentialSpend().add(day.discretionarySpend()))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new CashFlowProjection(
                currentDate,
                resolvedHorizonEnd,
                mainAccount,
                savingsAccount,
                startingMainBalance,
                incomeCalendar,
                incomeEvents,
                spendProfile,
                confirmedPayments,
                recurringForecast,
                days,
                minimumBalance,
                firstNegativeDate,
                confirmedOutflowsTotal,
                inferredOutflowsTotal,
                livingSpendTotal
        );
    }

    public record ProjectedCashFlowDay(
            int dayOffset,
            LocalDate date,
            BigDecimal balance,
            BigDecimal projectedIncome,
            BigDecimal essentialSpend,
            BigDecimal discretionarySpend,
            BigDecimal confirmedOutflow,
            BigDecimal inferredOutflow
    ) {
        public BigDecimal totalOutflow() {
            return essentialSpend
                    .add(discretionarySpend)
                    .add(confirmedOutflow)
                    .add(inferredOutflow);
        }
    }

    public record CashFlowProjection(
            LocalDate currentDate,
            LocalDate horizonEnd,
            Account mainAccount,
            Account savingsAccount,
            BigDecimal startingMainBalance,
            IncomeCalendarService.IncomeCalendar incomeCalendar,
            List<IncomeCalendarService.ProjectedIncomeEvent> incomeEvents,
            SpendProfileService.SpendProfile spendProfile,
            List<ScheduledPayment> confirmedPayments,
            RecurringObligationService.RecurringObligationForecast recurringForecast,
            List<ProjectedCashFlowDay> days,
            BigDecimal minimumBalance,
            LocalDate firstNegativeDate,
            BigDecimal confirmedOutflowsTotal,
            BigDecimal inferredOutflowsTotal,
            BigDecimal livingSpendTotal
    ) {
        public Set<String> excludedRecurringKeys() {
            return recurringForecast.recurringKeys();
        }
    }
}
