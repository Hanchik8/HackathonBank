package com.example.hackathonbank.model;

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

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private String counterparty;

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
        this.user = user;
        this.account = account;
        this.scheduledPayment = scheduledPayment;
        this.title = title;
        this.counterparty = counterparty;
        this.amount = amount;
        this.category = category;
        this.iconKey = iconKey;
        this.type = type;
        this.status = status;
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

    public String getTitle() {
        return title;
    }

    public String getCounterparty() {
        return counterparty;
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

    public LocalDateTime getOccurredAt() {
        return occurredAt;
    }

    public void reschedule(LocalDate newDate) {
        this.occurredAt = newDate.atTime(9, 0);
        this.status = TransactionStatus.POSTPONED;
    }
}
