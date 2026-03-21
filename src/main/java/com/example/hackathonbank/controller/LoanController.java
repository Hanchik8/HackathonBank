package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.CreateLoanRequest;
import com.example.hackathonbank.service.LoanService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/loans")
public class LoanController {

    private final LoanService loanService;

    public LoanController(LoanService loanService) {
        this.loanService = loanService;
    }

    @PostMapping
    public void createLoan(@Valid @RequestBody CreateLoanRequest request) {
        loanService.createLoan(request);
    }
}
