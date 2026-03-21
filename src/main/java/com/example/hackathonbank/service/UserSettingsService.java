package com.example.hackathonbank.service;

import com.example.hackathonbank.model.User;
import com.example.hackathonbank.model.UserSettings;
import com.example.hackathonbank.repository.UserSettingsRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
public class UserSettingsService {

    private final UserSettingsRepository userSettingsRepository;
    private final UserContextService userContextService;

    public UserSettingsService(UserSettingsRepository userSettingsRepository,
                               UserContextService userContextService) {
        this.userSettingsRepository = userSettingsRepository;
        this.userContextService = userContextService;
    }

    @Transactional(readOnly = true)
    public boolean isSmartListEnabled() {
        return getSettings().isSmartListEnabled();
    }

    @Transactional
    public boolean setSmartListEnabled(boolean enabled) {
        UserSettings settings = getSettings();
        settings.setSmartListEnabled(enabled);
        return userSettingsRepository.save(settings).isSmartListEnabled();
    }

    @Transactional(readOnly = true)
    public boolean isAdminModeEnabled() {
        return getSettings().isAdminModeEnabled();
    }

    @Transactional
    public boolean setAdminModeEnabled(boolean enabled) {
        UserSettings settings = getSettings();
        settings.setAdminModeEnabled(enabled);
        if (!enabled) {
            settings.setEffectiveDate(LocalDate.now());
        }
        return userSettingsRepository.save(settings).isAdminModeEnabled();
    }

    @Transactional(readOnly = true)
    public LocalDate getEffectiveDate() {
        return getSettings().getEffectiveDate();
    }

    @Transactional
    public LocalDate setEffectiveDate(LocalDate date) {
        UserSettings settings = getSettings();
        settings.setEffectiveDate(date);
        return userSettingsRepository.save(settings).getEffectiveDate();
    }

    @Transactional(readOnly = true)
    public LocalDate getCurrentDate() {
        UserSettings settings = getSettings();
        return settings.isAdminModeEnabled() ? settings.getEffectiveDate() : LocalDate.now();
    }

    @Transactional(readOnly = true)
    public LocalDate currentDate() {
        return getCurrentDate();
    }

    @Transactional
    public UserSettings getSettings() {
        User user = userContextService.getCurrentUser();
        return userSettingsRepository.findByUserId(user.getId())
                .orElseGet(() -> userSettingsRepository.save(
                        new UserSettings(user, true, false, LocalDate.now())
                ));
    }
}
