package com.example.hackathonbank.controller;

import com.example.hackathonbank.ai.AiAnalysisService;
import com.example.hackathonbank.ai.dto.AiAnalyzeResponse;
import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.AiExecuteRequest;
import com.example.hackathonbank.ai.dto.AiExecuteResponse;
import com.example.hackathonbank.controller.dto.BooleanSettingRequest;
import com.example.hackathonbank.controller.dto.BooleanSettingResponse;
import com.example.hackathonbank.controller.dto.DailySavingsPreviewResponse;
import com.example.hackathonbank.controller.dto.SaveSuggestionResponse;
import com.example.hackathonbank.service.ForecastService;
import com.example.hackathonbank.service.DailySavingsService;
import com.example.hackathonbank.service.UserSettingsService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final ForecastService forecastService;
    private final AiAnalysisService aiAnalysisService;
    private final DailySavingsService dailySavingsService;
    private final UserSettingsService userSettingsService;

    public AiController(ForecastService forecastService,
                        AiAnalysisService aiAnalysisService,
                        DailySavingsService dailySavingsService,
                        UserSettingsService userSettingsService) {
        this.forecastService = forecastService;
        this.aiAnalysisService = aiAnalysisService;
        this.dailySavingsService = dailySavingsService;
        this.userSettingsService = userSettingsService;
    }

    @GetMapping("/dashboard")
    public AiDashboardResponse dashboard(@RequestParam(defaultValue = "10") int offsetDays) {
        return forecastService.buildDashboard(offsetDays);
    }

    @PostMapping("/analyze")
    public AiAnalyzeResponse analyze(@RequestBody(required = false) Map<String, Integer> request) {
        Map<String, Integer> payload = request == null ? Map.of() : request;
        return aiAnalysisService.analyze(payload.getOrDefault("offsetDays", 10));
    }

    @PostMapping("/execute")
    public AiExecuteResponse execute(@Valid @RequestBody AiExecuteRequest request) {
        return aiAnalysisService.execute(request);
    }

    @GetMapping("/daily-safe-to-save")
    public DailySavingsPreviewResponse dailySafeToSave() {
        return dailySavingsService.previewForCurrentUser();
    }

    @GetMapping("/save-suggestion")
    public SaveSuggestionResponse saveSuggestion() {
        DailySavingsPreviewResponse preview = dailySavingsService.previewForCurrentUser();
        return new SaveSuggestionResponse(
                preview.suggestedAmount(),
                preview.status(),
                preview.lifeBuffer()
        );
    }

    @GetMapping("/auto-daily-save")
    public BooleanSettingResponse getAutoDailySave() {
        return new BooleanSettingResponse(userSettingsService.isAutoDailySaveEnabled());
    }

    @PostMapping("/auto-daily-save")
    public void setAutoDailySave(@Valid @RequestBody BooleanSettingRequest request) {
        userSettingsService.setAutoDailySaveEnabled(request.enabled());
    }
}
