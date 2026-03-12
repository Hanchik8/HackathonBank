package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.ScheduledPaymentRequest;
import com.example.hackathonbank.controller.dto.ScheduledPaymentResponse;
import com.example.hackathonbank.service.ScheduledPaymentService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/scheduled-payments")
public class ScheduledPaymentController {

    private final ScheduledPaymentService scheduledPaymentService;

    public ScheduledPaymentController(ScheduledPaymentService scheduledPaymentService) {
        this.scheduledPaymentService = scheduledPaymentService;
    }

    @GetMapping
    public List<ScheduledPaymentResponse> getScheduledPayments() {
        return scheduledPaymentService.getScheduledPayments();
    }

    @PostMapping
    public ScheduledPaymentResponse createScheduledPayment(@Valid @RequestBody ScheduledPaymentRequest request) {
        return scheduledPaymentService.createScheduledPayment(request);
    }
}
