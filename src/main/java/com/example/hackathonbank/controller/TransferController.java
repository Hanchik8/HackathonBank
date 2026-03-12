package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.ExternalTransferRequest;
import com.example.hackathonbank.controller.dto.ExternalTransferResponse;
import com.example.hackathonbank.controller.dto.TransferRequest;
import com.example.hackathonbank.controller.dto.TransferResponse;
import com.example.hackathonbank.service.TransferService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/transfer")
public class TransferController {

    private final TransferService transferService;

    public TransferController(TransferService transferService) {
        this.transferService = transferService;
    }

    @PostMapping
    public TransferResponse transfer(@Valid @RequestBody TransferRequest request) {
        return transferService.transfer(request);
    }

    @PostMapping("/external")
    public ExternalTransferResponse transferExternal(@Valid @RequestBody ExternalTransferRequest request) {
        return transferService.transferExternal(request);
    }
}
