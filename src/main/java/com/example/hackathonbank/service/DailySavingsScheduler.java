package com.example.hackathonbank.service;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class DailySavingsScheduler {

    private final DailySavingsService dailySavingsService;

    public DailySavingsScheduler(DailySavingsService dailySavingsService) {
        this.dailySavingsService = dailySavingsService;
    }

    @Scheduled(cron = "${app.daily-savings.cron:0 0 9 * * *}")
    public void runDailySafeToSave() {
        dailySavingsService.runDailyAutoSaveForAllEnabledUsers();
    }
}
