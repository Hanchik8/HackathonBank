package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.ai.BankingAgentTools;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.fasterxml.jackson.core.type.TypeReference;
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
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class OpenRouterAiChatClient implements AiChatClient {

    private final AiCallExecutor aiCallExecutor;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final BankingAgentTools tools;
    private final String apiUrl;
    private final String apiKey;
    private final String model;
    private final String httpReferer;
    private final String appTitle;

    public OpenRouterAiChatClient(AiCallExecutor aiCallExecutor,
                                  ObjectMapper objectMapper,
                                  BankingAgentTools tools,
                                  @Value("${ai.api-url:https://api.x.ai/v1/chat/completions}") String apiUrl,
                                  @Value("${ai.api-key:}") String apiKey,
                                  @Value("${ai.model:grok-4}") String model,
                                  @Value("${ai.http-referer:http://localhost:8080}") String httpReferer,
                                  @Value("${ai.app-title:HackathonBank}") String appTitle) {
        this.aiCallExecutor = aiCallExecutor;
        this.objectMapper = objectMapper;
        this.tools = tools;
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
            return aiCallExecutor.execute(() -> sendRequestAndProcessTools(messages));
        } catch (Exception exception) {
            String reason = exception.getMessage();
            if (StringUtils.hasText(reason)) {
                throw new IllegalStateException("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u043e\u043b\u0443\u0447\u0438\u0442\u044c \u043e\u0442\u0432\u0435\u0442 \u043e\u0442 \u0418\u0418 \u0430\u0441\u0441\u0438\u0441\u0442\u0435\u043d\u0442\u0430: " + reason, exception);
            }
            throw new IllegalStateException("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u043e\u043b\u0443\u0447\u0438\u0442\u044c \u043e\u0442\u0432\u0435\u0442 \u043e\u0442 \u0418\u0418 \u0430\u0441\u0441\u0438\u0441\u0442\u0435\u043d\u0442\u0430.", exception);
        }
    }

    private String sendRequestAndProcessTools(List<ChatMessageDto> messages) throws IOException, InterruptedException {
        // Prepare local list so we can append tool responses if needed
        List<ObjectNode> localMessages = new ArrayList<>();
        for (ChatMessageDto msg : messages) {
            ObjectNode node = objectMapper.createObjectNode();
            node.put("role", msg.role());
            node.put("content", msg.content());
            localMessages.add(node);
        }

        int iterations = 0;
        int maxIterations = 5;

        while (iterations < maxIterations) {
            String payload = buildPayload(localMessages);
            HttpRequest request = HttpRequest.newBuilder(URI.create(apiUrl))
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .header("HTTP-Referer", httpReferer)
                    .header("X-Title", appTitle)
                    .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("AI provider returned status %d: %s".formatted(response.statusCode(), response.body()));
            }

            JsonNode root = objectMapper.readTree(response.body());
            JsonNode messageNode = root.path("choices").path(0).path("message");

            // Check for tool calls
            JsonNode toolCalls = messageNode.path("tool_calls");
            if (toolCalls.isArray() && !toolCalls.isEmpty()) {
                // Add the assistant's message with tool calls to history
                ObjectNode assistantMessage = objectMapper.createObjectNode();
                assistantMessage.put("role", "assistant");
                if (!messageNode.path("content").isMissingNode() && !messageNode.path("content").isNull()) {
                    assistantMessage.set("content", messageNode.path("content"));
                }
                assistantMessage.set("tool_calls", toolCalls);
                localMessages.add(assistantMessage);

                // Process each tool call
                for (JsonNode toolCall : toolCalls) {
                    String toolCallId = toolCall.path("id").asText();
                    JsonNode function = toolCall.path("function");
                    String functionName = function.path("name").asText();
                    String functionArgsStr = function.path("arguments").asText("{}");

                    String toolResultStr = executeTool(functionName, functionArgsStr);

                    ObjectNode toolMessage = objectMapper.createObjectNode();
                    toolMessage.put("role", "tool");
                    toolMessage.put("tool_call_id", toolCallId);
                    toolMessage.put("content", toolResultStr);

                    localMessages.add(toolMessage);
                }
                iterations++;
                continue; // Send back to AI
            } else {
                String content = extractContent(messageNode.path("content"));
                if (!StringUtils.hasText(content)) {
                    throw new IllegalStateException("AI provider returned an empty message.");
                }
                return content.trim();
            }
        }
        throw new IllegalStateException("Exceeded maximum number of tool call iterations.");
    }

    private String executeTool(String functionName, String functionArgsStr) {
        try {
            Map<String, Object> args = objectMapper.readValue(functionArgsStr, new TypeReference<>() {});
            if ("getUpcomingScheduledPayments".equals(functionName) || "get_upcoming_scheduled_payments".equals(functionName)) {
                List<com.example.hackathonbank.model.ScheduledPayment> payments = tools.getUpcomingScheduledPayments();
                return objectMapper.writeValueAsString(payments);
            } else if ("autoTransferFromSavings".equals(functionName) || "auto_transfer_from_savings".equals(functionName)) {
                String amount = args.get("amount").toString();
                ActionExecutionResult result = tools.autoTransferFromSavings(amount);
                return objectMapper.writeValueAsString(result);
            } else if ("postponePayment".equals(functionName) || "postpone_payment".equals(functionName)) {
                Long paymentId = Long.parseLong(args.get("paymentId").toString());
                ActionExecutionResult result = tools.postponePayment(paymentId);
                return objectMapper.writeValueAsString(result);
            }
        } catch (Exception e) {
            return "Error executing tool: " + e.getMessage();
        }
        return "Tool " + functionName + " not found.";
    }

    private String buildPayload(List<ObjectNode> messages) throws IOException {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("model", model);

        ArrayNode messageArray = root.putArray("messages");
        for (ObjectNode msg : messages) {
            messageArray.add(msg);
        }

        // Add tools definition
        ArrayNode toolsArray = root.putArray("tools");

        ObjectNode tool1 = toolsArray.addObject();
        tool1.put("type", "function");
        ObjectNode func1 = tool1.putObject("function");
        func1.put("name", "get_upcoming_scheduled_payments");
        func1.put("description", "Получить список будущих (ожидающих) запланированных платежей пользователя.");
        ObjectNode params1 = func1.putObject("parameters");
        params1.put("type", "object");
        params1.putObject("properties");

        ObjectNode tool2 = toolsArray.addObject();
        tool2.put("type", "function");
        ObjectNode func2 = tool2.putObject("function");
        func2.put("name", "auto_transfer_from_savings");
        func2.put("description", "Перевести деньги со счета сбережений на основной счет, чтобы закрыть кассовый разрыв.");
        ObjectNode params2 = func2.putObject("parameters");
        params2.put("type", "object");
        ObjectNode props2 = params2.putObject("properties");
        ObjectNode amountProp = props2.putObject("amount");
        amountProp.put("type", "string");
        amountProp.put("description", "Сумма для перевода");
        params2.putArray("required").add("amount");

        ObjectNode tool3 = toolsArray.addObject();
        tool3.put("type", "function");
        ObjectNode func3 = tool3.putObject("function");
        func3.put("name", "postpone_payment");
        func3.put("description", "Перенести запланированный платеж на семь дней, чтобы избежать кассового разрыва.");
        ObjectNode params3 = func3.putObject("parameters");
        params3.put("type", "object");
        ObjectNode props3 = params3.putObject("properties");
        ObjectNode paymentIdProp = props3.putObject("paymentId");
        paymentIdProp.put("type", "integer");
        paymentIdProp.put("description", "ID платежа");
        params3.putArray("required").add("paymentId");

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
