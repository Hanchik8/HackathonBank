package com.example.hackathonbank.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;

@Entity
@Table(name = "smart_categories")
public class SmartCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal plannedMonthly;

    @Column(nullable = false)
    private boolean favorite;

    protected SmartCategory() {
    }

    public SmartCategory(User user, String name, BigDecimal plannedMonthly, boolean favorite) {
        this.user = user;
        this.name = name;
        this.plannedMonthly = plannedMonthly;
        this.favorite = favorite;
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public String getName() {
        return name;
    }

    public BigDecimal getPlannedMonthly() {
        return plannedMonthly;
    }

    public void setPlannedMonthly(BigDecimal plannedMonthly) {
        this.plannedMonthly = plannedMonthly;
    }

    public boolean isFavorite() {
        return favorite;
    }

    public void setFavorite(boolean favorite) {
        this.favorite = favorite;
    }
}
