package com.example.hackathonbank.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

import java.time.LocalDate;

@Entity
@Table(name = "user_settings")
public class UserSettings {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", unique = true)
    private User user;

    @Column(nullable = false)
    private boolean smartListEnabled;

    @Column(nullable = false)
    private boolean adminModeEnabled;

    @Column(nullable = false)
    private boolean autoDailySaveEnabled;

    @Column(nullable = false)
    private LocalDate effectiveDate;

    protected UserSettings() {
    }

    public UserSettings(User user, boolean smartListEnabled, boolean adminModeEnabled, LocalDate effectiveDate) {
        this(user, smartListEnabled, adminModeEnabled, false, effectiveDate);
    }

    public UserSettings(User user,
                        boolean smartListEnabled,
                        boolean adminModeEnabled,
                        boolean autoDailySaveEnabled,
                        LocalDate effectiveDate) {
        this.user = user;
        this.smartListEnabled = smartListEnabled;
        this.adminModeEnabled = adminModeEnabled;
        this.autoDailySaveEnabled = autoDailySaveEnabled;
        this.effectiveDate = effectiveDate;
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public boolean isSmartListEnabled() {
        return smartListEnabled;
    }

    public void setSmartListEnabled(boolean smartListEnabled) {
        this.smartListEnabled = smartListEnabled;
    }

    public boolean isAdminModeEnabled() {
        return adminModeEnabled;
    }

    public void setAdminModeEnabled(boolean adminModeEnabled) {
        this.adminModeEnabled = adminModeEnabled;
    }

    public boolean isAutoDailySaveEnabled() {
        return autoDailySaveEnabled;
    }

    public void setAutoDailySaveEnabled(boolean autoDailySaveEnabled) {
        this.autoDailySaveEnabled = autoDailySaveEnabled;
    }

    public LocalDate getEffectiveDate() {
        return effectiveDate;
    }

    public void setEffectiveDate(LocalDate effectiveDate) {
        this.effectiveDate = effectiveDate;
    }
}
