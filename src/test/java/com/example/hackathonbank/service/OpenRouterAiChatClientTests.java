package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OpenRouterAiChatClientTests {

    @Mock
    private AiCallExecutor aiCallExecutor;

    @Test
    void completeIncludesProviderReasonWhenCallFails() throws Exception {
        OpenRouterAiChatClient client = new OpenRouterAiChatClient(
                aiCallExecutor,
                new ObjectMapper(),
                "https://openrouter.ai/api/v1/chat/completions",
                "test-key",
                "google/gemini-2.0-flash-001"
        );

        when(aiCallExecutor.execute(any()))
                .thenThrow(new IllegalStateException("AI provider returned status 400: model is not available"));

        assertThatThrownBy(() -> client.complete(List.of(new ChatMessageDto("user", "Привет"))))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Не удалось получить ответ от ИИ ассистента")
                .hasMessageContaining("status 400")
                .hasMessageContaining("model is not available");
    }

    @Test
    void completeFailsFastWhenApiKeyIsMissing() {
        OpenRouterAiChatClient client = new OpenRouterAiChatClient(
                aiCallExecutor,
                new ObjectMapper(),
                "https://openrouter.ai/api/v1/chat/completions",
                "demo-key",
                "google/gemini-2.0-flash-001"
        );

        assertThatThrownBy(() -> client.complete(List.of(new ChatMessageDto("user", "Привет"))))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("AI API key is not configured.");
    }
}
