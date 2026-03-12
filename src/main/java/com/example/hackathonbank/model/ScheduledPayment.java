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
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "scheduled_payments")
public class ScheduledPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "account_id")
    private Account account;

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

    @Column(nullable = false)
    private LocalDate dueDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentStatus status;

    protected ScheduledPayment() {
    }

    public ScheduledPayment(User user,
                            Account account,
                            String title,
                            BigDecimal amount,
                            String category,
                            LocalDate dueDate,
                            PaymentStatus status) {
        this(user, account, title, title, amount, category, "calendar", dueDate, status);
    }

    public ScheduledPayment(User user,
                            Account account,
                            String title,
                            String counterparty,
                            BigDecimal amount,
                            String category,
                            String iconKey,
                            LocalDate dueDate,
                            PaymentStatus status) {
        this.user = user;
        this.account = account;
        this.title = title;
        this.counterparty = counterparty;
        this.amount = amount;
        this.category = category;
        this.iconKey = iconKey;
        this.dueDate = dueDate;
        this.status = status;
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

    public LocalDate getDueDate() {
        return dueDate;
    }

    public PaymentStatus getStatus() {
        return status;
    }

    public void postponeByDays(long days) {
        this.dueDate = this.dueDate.plusDays(days);
        this.status = PaymentStatus.POSTPONED;
    }
}
