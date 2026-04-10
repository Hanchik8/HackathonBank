package com.example.hackathonbank.model;

import com.example.hackathonbank.service.IncomeType;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "bank_transactions")
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "account_id")
    private Account account;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "scheduled_payment_id")
    private ScheduledPayment scheduledPayment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "smart_category_id")
    private SmartCategory smartCategory;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private String counterparty;

    @Column(nullable = false)
    private String normalizedCounterparty;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false)
    private String category;

    @Column(nullable = false)
    private String iconKey;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TransactionType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TransactionStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private IncomeType incomeType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SpendEssentiality essentiality;

    @Column(nullable = false)
    private LocalDateTime occurredAt;

    protected Transaction() {
    }

    public Transaction(User user,
                       Account account,
                       ScheduledPayment scheduledPayment,
                       String title,
                       String counterparty,
                       BigDecimal amount,
                       String category,
                       String iconKey,
                       TransactionType type,
                       TransactionStatus status,
                       LocalDateTime occurredAt) {
        this(user, account, scheduledPayment, null, title, counterparty, amount, category, iconKey, type, status, occurredAt);
    }

    public Transaction(User user,
                       Account account,
                       ScheduledPayment scheduledPayment,
                       SmartCategory smartCategory,
                       String title,
                       String counterparty,
                       BigDecimal amount,
                       String category,
                       String iconKey,
                       TransactionType type,
                       TransactionStatus status,
                       LocalDateTime occurredAt) {
        this.user = user;
        this.account = account;
        this.scheduledPayment = scheduledPayment;
        this.smartCategory = smartCategory;
        this.title = title;
        this.counterparty = counterparty;
        this.normalizedCounterparty = normalizeCounterparty(counterparty, title);
        this.amount = amount;
        this.category = category;
        this.iconKey = iconKey;
        this.type = type;
        this.status = status;
        this.incomeType = classifyIncomeType(title, category, counterparty, type, amount);
        this.essentiality = classifyEssentiality(title, category, counterparty, type, amount);
        this.occurredAt = occurredAt;
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public Account getAccount() {
        return account;
    }

    public ScheduledPayment getScheduledPayment() {
        return scheduledPayment;
    }

    public SmartCategory getSmartCategory() {
        return smartCategory;
    }

    public String getTitle() {
        return title;
    }

    public String getCounterparty() {
        return counterparty;
    }

    public String getNormalizedCounterparty() {
        return normalizedCounterparty;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCategory() {
        return category;
    }

    public String getIconKey() {
        return iconKey;
    }

    public TransactionType getType() {
        return type;
    }

    public TransactionStatus getStatus() {
        return status;
    }

    public IncomeType getIncomeType() {
        return incomeType;
    }

    public SpendEssentiality getEssentiality() {
        return essentiality;
    }

    public LocalDateTime getOccurredAt() {
        return occurredAt;
    }

    public void setSmartCategory(SmartCategory smartCategory) {
        this.smartCategory = smartCategory;
    }

    public void reschedule(LocalDate newDate) {
        this.occurredAt = newDate.atTime(9, 0);
        this.status = TransactionStatus.POSTPONED;
    }

    private static String normalizeCounterparty(String counterparty, String title) {
        String source = counterparty != null && !counterparty.isBlank() ? counterparty : title;
        if (source == null || source.isBlank()) {
            return "unknown";
        }
        String normalized = source
                .toLowerCase(java.util.Locale.ROOT)
                .replaceAll("[^\\p{IsAlphabetic}\\p{IsDigit}]+", " ")
                .trim()
                .replaceAll("\\s{2,}", " ");
        return normalized.isBlank() ? "unknown" : normalized;
    }

    private static IncomeType classifyIncomeType(String title,
                                                 String category,
                                                 String counterparty,
                                                 TransactionType type,
                                                 BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0 || type == TransactionType.TRANSFER) {
            return IncomeType.OTHER;
        }
        String normalized = normalizeCounterparty(counterparty, title) + " " + safe(category);
        if (containsAny(normalized, "возврат", "кэшбэк", "cashback", "refund", "bonus", "бонус")) {
            return IncomeType.REFUND;
        }
        if (containsAny(normalized, "пополнение", "top up", "topup", "deposit", "внесен", "терминал")) {
            return IncomeType.TOPUP;
        }
        if (containsAny(normalized, "зарплат", "salary", "оклад", "аванс") || amount.compareTo(new BigDecimal("30000.00")) >= 0) {
            return IncomeType.SALARY;
        }
        if (amount.compareTo(new BigDecimal("5000.00")) >= 0) {
            return IncomeType.FREELANCE;
        }
        return IncomeType.OTHER;
    }

    private static SpendEssentiality classifyEssentiality(String title,
                                                          String category,
                                                          String counterparty,
                                                          TransactionType type,
                                                          BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) >= 0 || type == TransactionType.TRANSFER) {
            return SpendEssentiality.UNKNOWN;
        }
        String normalized = normalizeCounterparty(counterparty, title) + " " + safe(category);
        if (containsAny(normalized,
                "продукт", "еда", "food", "grocery", "супермаркет", "магазин",
                "аптек", "здоров", "health",
                "транспорт", "такси", "автобус", "метро", "бензин", "азс", "transport",
                "аренд", "коммун", "жкх", "электр", "газ", "вода",
                "мобиль", "связь", "интернет", "подпис")) {
            return SpendEssentiality.ESSENTIAL;
        }
        return SpendEssentiality.DISCRETIONARY;
    }

    private static boolean containsAny(String value, String... candidates) {
        for (String candidate : candidates) {
            if (value.contains(candidate)) {
                return true;
            }
        }
        return false;
    }

    private static String safe(String value) {
        return value == null ? "" : value.toLowerCase(java.util.Locale.ROOT);
    }
}
