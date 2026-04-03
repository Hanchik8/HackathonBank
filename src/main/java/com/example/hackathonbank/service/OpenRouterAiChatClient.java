package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;

@Service
public class OpenRouterAiChatClient implements AiChatClient {

    private final AiCallExecutor aiCallExecutor;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String apiUrl;
    private final String apiKey;
    private final String model;
    private final String httpReferer;
    private final String appTitle;

    public OpenRouterAiChatClient(AiCallExecutor aiCallExecutor,
                                  ObjectMapper objectMapper,
                                  @Value("${ai.api-url:https://openrouter.ai/api/v1/chat/completions}") String apiUrl,
                                  @Value("${ai.api-key:}") String apiKey,
                                  @Value("${ai.model:google/gemini-2.0-flash-001}") String model,
                                  @Value("${ai.http-referer:http://localhost:8080}") String httpReferer,
                                  @Value("${ai.app-title:HackathonBank}") String appTitle) {
        this.aiCallExecutor = aiCallExecutor;
        this.objectMapper = objectMapper;
        this.apiUrl = apiUrl;
        this.apiKey = apiKey;
        this.model = model;
        this.httpReferer = httpReferer;
        this.appTitle = appTitle;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    @Override
    public String complete(List<ChatMessageDto> messages) {
        if (!StringUtils.hasText(apiKey) || "demo-key".equals(apiKey)) {
            throw new IllegalStateException("AI API key is not configured.");
        }

        try {
            return aiCallExecutor.execute(() -> sendRequest(messages));
        } catch (Exception exception) {
            String reason = exception.getMessage();
            if (StringUtils.hasText(reason)) {
                throw new IllegalStateException("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u043e\u043b\u0443\u0447\u0438\u0442\u044c \u043e\u0442\u0432\u0435\u0442 \u043e\u0442 \u0418\u0418 \u0430\u0441\u0441\u0438\u0441\u0442\u0435\u043d\u0442\u0430: " + reason, exception);
            }
            throw new IllegalStateException("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u043e\u043b\u0443\u0447\u0438\u0442\u044c \u043e\u0442\u0432\u0435\u0442 \u043e\u0442 \u0418\u0418 \u0430\u0441\u0441\u0438\u0441\u0442\u0435\u043d\u0442\u0430.", exception);
        }
    }

    private String sendRequest(List<ChatMessageDto> messages) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(URI.create(apiUrl))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .header("HTTP-Referer", httpReferer)
                .header("X-Title", appTitle)
                .POST(HttpRequest.BodyPublishers.ofString(buildPayload(messages), StandardCharsets.UTF_8))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("AI provider returned status %d: %s".formatted(response.statusCode(), response.body()));
        }

        JsonNode root = objectMapper.readTree(response.body());
        JsonNode messageNode = root.path("choices").path(0).path("message");
        String content = extractContent(messageNode.path("content"));
        if (!StringUtils.hasText(content)) {
            throw new IllegalStateException("AI provider returned an empty message.");
        }
        return content.trim();
    }

    private String buildPayload(List<ChatMessageDto> messages) throws IOException {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("model", model);
        ArrayNode messageArray = root.putArray("messages");
        for (ChatMessageDto message : messages) {
            ObjectNode node = messageArray.addObject();
            node.put("role", message.role());
            node.put("content", message.content());
        }
        return objectMapper.writeValueAsString(root);
    }

    private String extractContent(JsonNode contentNode) {
        if (contentNode.isTextual()) {
            return contentNode.asText();
        }
        if (contentNode.isArray()) {
            StringBuilder builder = new StringBuilder();
            for (JsonNode part : contentNode) {
                String text = part.path("text").asText("");
                if (!text.isBlank()) {
                    if (builder.length() > 0) {
                        builder.append('\n');
                    }
                    builder.append(text.trim());
                }
            }
            return builder.toString();
        }
        return "";
    }
}
