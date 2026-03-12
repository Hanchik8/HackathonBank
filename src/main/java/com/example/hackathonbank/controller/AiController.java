package com.example.hackathonbank.controller;

import com.example.hackathonbank.ai.AiAnalysisService;
import com.example.hackathonbank.ai.dto.AiAnalyzeResponse;
import com.example.hackathonbank.ai.dto.AiDashboardResponse;
import com.example.hackathonbank.ai.dto.AiExecuteRequest;
import com.example.hackathonbank.ai.dto.AiExecuteResponse;
import com.example.hackathonbank.service.ForecastService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final ForecastService forecastService;
    private final AiAnalysisService aiAnalysisService;

    public AiController(ForecastService forecastService, AiAnalysisService aiAnalysisService) {
        this.forecastService = forecastService;
        this.aiAnalysisService = aiAnalysisService;
    }

    @GetMapping("/dashboard")
    public AiDashboardResponse dashboard(@RequestParam(defaultValue = "10") int offsetDays) {
        return forecastService.buildDashboard(offsetDays);
    }

    @PostMapping("/analyze")
    public AiAnalyzeResponse analyze() {
        return aiAnalysisService.analyze();
    }

    @PostMapping("/execute")
    public AiExecuteResponse execute(@Valid @RequestBody AiExecuteRequest request) {
        return aiAnalysisService.execute(request);
    }
}
