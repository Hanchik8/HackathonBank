package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.controller.dto.ScheduledPaymentRequest;
import com.example.hackathonbank.controller.dto.ScheduledPaymentResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.ScheduledPaymentRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Locale;
import java.util.Objects;

@Service
public class ScheduledPaymentService {

    private final ScheduledPaymentRepository scheduledPaymentRepository;
    private final TransactionRepository transactionRepository;
    private final UserContextService userContextService;
    private final AccountService accountService;
    private final UserSettingsService userSettingsService;

    @Autowired
    public ScheduledPaymentService(ScheduledPaymentRepository scheduledPaymentRepository,
                                   TransactionRepository transactionRepository,
                                   UserContextService userContextService,
                                   AccountService accountService,
                                   UserSettingsService userSettingsService) {
        this.scheduledPaymentRepository = scheduledPaymentRepository;
        this.transactionRepository = transactionRepository;
        this.userContextService = userContextService;
        this.accountService = accountService;
        this.userSettingsService = userSettingsService;
    }

    public ScheduledPaymentService(ScheduledPaymentRepository scheduledPaymentRepository,
                                   TransactionRepository transactionRepository,
                                   UserContextService userContextService,
                                   AccountService accountService) {
        this(scheduledPaymentRepository, transactionRepository, userContextService, accountService, null);
    }

    @Transactional(readOnly = true)
    public List<ScheduledPayment> getPendingPayments() {
        return scheduledPaymentRepository.findByUserIdAndStatusInOrderByDueDateAsc(
                userContextService.getCurrentUser().getId(),
                List.of(PaymentStatus.SCHEDULED, PaymentStatus.POSTPONED)
        );
    }

    @Transactional(readOnly = true)
    public List<ScheduledPaymentResponse> getScheduledPayments() {
        return getPendingPayments().stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public ScheduledPaymentResponse createScheduledPayment(ScheduledPaymentRequest request) {
        User user = userContextService.getCurrentUser();
        Account account = accountService.getOwnedAccount(request.accountId());
        String counterparty = normalizeCounterparty(request.counterparty(), request.title());
        String iconKey = resolveIconKey(request.category(), request.title(), counterparty);

        boolean flexible = request.flexible() != null
                ? request.flexible()
                : ScheduledPayment.classifyFlexibility(request.title(), request.category());

        ScheduledPayment payment = scheduledPaymentRepository.save(new ScheduledPayment(
                user,
                account,
                request.title().trim(),
                counterparty,
                request.amount(),
                request.category().trim(),
                iconKey,
                request.dueDate(),
                Boolean.TRUE.equals(request.isReminder()),
                PaymentStatus.SCHEDULED,
                flexible
        ));

        transactionRepository.save(new Transaction(
                user,
                account,
                payment,
                "Автоплатеж: %s".formatted(payment.getTitle()),
                payment.getCounterparty(),
                payment.getAmount().negate(),
                payment.getCategory(),
                payment.getIconKey(),
                TransactionType.AUTO_PAYMENT,
                TransactionStatus.SCHEDULED,
                payment.getDueDate().atTime(9, 0)
        ));

        return toResponse(payment);
    }

    @Transactional
    public ActionExecutionResult postponePayment(Long paymentId) {
        ScheduledPayment payment = getOwnedPayment(paymentId);
        return postponePaymentTo(paymentId, payment.getDueDate().plusDays(7));
    }

    @Transactional
    public ActionExecutionResult postponePaymentTo(Long paymentId, LocalDate targetDate) {
        ScheduledPayment payment = getOwnedPayment(paymentId);
        validateTargetDate(targetDate);
        payment.postponeTo(targetDate);
        scheduledPaymentRepository.save(payment);
        transactionRepository.findByScheduledPaymentId(paymentId)
                .ifPresent(transaction -> transaction.reschedule(payment.getDueDate()));

        return new ActionExecutionResult(
                "POSTPONE_PAYMENT",
                "Платеж \"%s\" перенесен на %s.".formatted(payment.getTitle(), payment.getDueDate()),
                accountService.getAccountByType(AccountType.MAIN).getBalance(),
                accountService.getAccountByType(AccountType.SAVINGS).getBalance()
        );
    }

    @Transactional
    public ActionExecutionResult postponePaymentsTo(List<Long> paymentIds, LocalDate targetDate) {
        validateTargetDate(targetDate);
        List<ScheduledPayment> payments = paymentIds.stream()
                .map(this::getOwnedPayment)
                .toList();
        if (payments.isEmpty()) {
            throw new IllegalArgumentException("Не найдено ни одного платежа для переноса.");
        }

        payments.forEach(payment -> payment.postponeTo(targetDate));
        scheduledPaymentRepository.saveAll(payments);
        payments.forEach(payment -> transactionRepository.findByScheduledPaymentId(payment.getId())
                .ifPresent(transaction -> transaction.reschedule(targetDate)));

        return new ActionExecutionResult(
                "POSTPONE_PAYMENT",
                "Перенесено %d платежей на %s.".formatted(payments.size(), targetDate),
                accountService.getAccountByType(AccountType.MAIN).getBalance(),
                accountService.getAccountByType(AccountType.SAVINGS).getBalance()
        );
    }

    @Transactional
    public void deleteScheduledPayment(Long paymentId) {
        ScheduledPayment payment = getOwnedPayment(paymentId);
        transactionRepository.findByScheduledPaymentId(paymentId)
                .ifPresent(transactionRepository::delete);
        scheduledPaymentRepository.delete(payment);
    }

    public ScheduledPaymentResponse toResponse(ScheduledPayment payment) {
        return new ScheduledPaymentResponse(
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
        );
    }

    private ScheduledPayment getOwnedPayment(Long paymentId) {
        ScheduledPayment payment = scheduledPaymentRepository.findById(paymentId)
                .orElseThrow(() -> new IllegalArgumentException("Автоплатеж %d не найден.".formatted(paymentId)));
        if (!Objects.equals(payment.getUser().getId(), userContextService.getCurrentUser().getId())) {
            throw new IllegalArgumentException("Автоплатеж недоступен текущему пользователю.");
        }
        return payment;
    }

    private void validateTargetDate(LocalDate targetDate) {
        if (!targetDate.isAfter(currentDate())) {
            throw new IllegalArgumentException("Новая дата платежа должна быть позже текущей даты.");
        }
    }

    private LocalDate currentDate() {
        return userSettingsService == null ? LocalDate.now() : userSettingsService.currentDate();
    }

    private String normalizeCounterparty(String counterparty, String title) {
        if (counterparty == null || counterparty.isBlank()) {
            return title.trim();
        }
        return counterparty.trim();
    }

    private String resolveIconKey(String category, String title, String counterparty) {
        String normalized = "%s %s %s".formatted(title, category, counterparty).toLowerCase(Locale.ROOT);
        if (containsAny(normalized, "аренд", "ипотек", "дом", "квартир")) {
            return "home";
        }
        if (containsAny(normalized, "подпис", "internet", "интернет", "mobile", "beeline", "movie", "stream")) {
            return "subscription";
        }
        if (containsAny(normalized, "еда", "маркет", "магазин", "globus", "magnum", "shopping")) {
            return "shopping";
        }
        if (containsAny(normalized, "такси", "транспорт", "bus", "onay", "yandex")) {
            return "transport";
        }
        if (containsAny(normalized, "ресторан", "кафе", "coffee", "food")) {
            return "food";
        }
        if (containsAny(normalized, "электр", "газ", "вода", "коммун", "utility")) {
            return "utilities";
        }
        return "calendar";
    }

    private boolean containsAny(String value, String... candidates) {
        for (String candidate : candidates) {
            if (value.contains(candidate)) {
                return true;
            }
        }
        return false;
    }
}
