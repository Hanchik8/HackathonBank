package com.example.hackathonbank.controller;

import com.example.hackathonbank.dto.AiChatActionRequest;
import com.example.hackathonbank.dto.AiChatRequest;
import com.example.hackathonbank.dto.AiChatResponse;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.example.hackathonbank.service.AiChatService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/ai")
public class AiChatController {

    private final AiChatService aiChatService;

    public AiChatController(AiChatService aiChatService) {
        this.aiChatService = aiChatService;
    }

    @GetMapping("/chat/history")
    public List<ChatMessageDto> history() {
        return aiChatService.history();
    }

    @PostMapping("/chat")
    public AiChatResponse chat(@Valid @RequestBody AiChatRequest request) {
        return aiChatService.chat(request);
    }

    @PostMapping("/chat/action")
    public AiChatResponse resolveAction(@Valid @RequestBody AiChatActionRequest request) {
        return aiChatService.resolveAction(request);
    }
}
