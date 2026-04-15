package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.AiCallExecutor;
import com.example.hackathonbank.ai.BankingAgentTools;
import com.example.hackathonbank.dto.AiChatActionRequest;
import com.example.hackathonbank.dto.AiChatPendingActionDto;
import com.example.hackathonbank.dto.AiChatRequest;
import com.example.hackathonbank.dto.AiChatResponse;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.example.hackathonbank.model.ChatMessage;
import com.example.hackathonbank.repository.ChatMessageRepository;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Service
public class AiChatService {

    private static final int MAX_HISTORY_MESSAGES = 40;

    private final AiChatContextBuilder contextBuilder;
    private final ChatClient chatClient;
    private final BankingAgentTools bankingAgentTools;
    private final UserContextService userContextService;
    private final ChatMessageRepository chatMessageRepository;
    private final AiCallExecutor aiCallExecutor;
    private final PendingAiActionService pendingAiActionService;
    private final SmartCategoryService smartCategoryService;

    public AiChatService(AiChatContextBuilder contextBuilder,
                         ChatClient chatClient,
                         BankingAgentTools bankingAgentTools,
                         UserContextService userContextService,
                         ChatMessageRepository chatMessageRepository,
                         AiCallExecutor aiCallExecutor,
                         PendingAiActionService pendingAiActionService,
                         SmartCategoryService smartCategoryService) {
        this.contextBuilder = contextBuilder;
        this.chatClient = chatClient;
        this.bankingAgentTools = bankingAgentTools;
        this.userContextService = userContextService;
        this.chatMessageRepository = chatMessageRepository;
        this.aiCallExecutor = aiCallExecutor;
        this.pendingAiActionService = pendingAiActionService;
        this.smartCategoryService = smartCategoryService;
    }

    @Transactional(readOnly = true)
    public List<ChatMessageDto> history() {
        Long userId = userContextService.getCurrentUser().getId();
        return loadPersistedHistory(userId);
    }

    @Transactional
    public AiChatResponse chat(AiChatRequest request) {
        if (request == null || !StringUtils.hasText(request.newMessage())) {
            throw new IllegalArgumentException("Сообщение не должно быть пустым.");
        }

        Long userId = userContextService.getCurrentUser().getId();
        String userMessage = request.newMessage().trim();
        List<ChatMessageDto> history = normalizeHistory(request.history());
        boolean enableTools = shouldEnableTools(userMessage);

        String assistantMessage;
        try {
            assistantMessage = aiCallExecutor.execute(() -> {
                ChatClient.ChatClientRequestSpec requestSpec = chatClient.prompt()
                        .system(systemPrompt(contextBuilder.buildContextJson()))
                        .messages(toMessages(history))
                        .user(userMessage);
                if (enableTools) {
                    requestSpec = requestSpec.tools(bankingAgentTools);
                }
                return requestSpec.call().content();
            });
        } catch (Exception exception) {
            throw new IllegalStateException("Не удалось получить ответ от ИИ ассистента.", exception);
        }

        if (!StringUtils.hasText(assistantMessage)) {
            throw new IllegalStateException("Не удалось получить ответ от ИИ ассистента.");
        }
        String assistantContent = assistantMessage.trim();

        AiChatPendingActionDto pendingAction = pendingAiActionService.takeLatestForUser(userId);
        chatMessageRepository.save(new ChatMessage(userId, ChatMessage.Role.USER, userMessage));
        chatMessageRepository.save(new ChatMessage(userId, ChatMessage.Role.ASSISTANT, assistantContent));

        return new AiChatResponse(new ChatMessageDto("assistant", assistantContent), pendingAction);
    }

    @Transactional
    public AiChatResponse resolveAction(AiChatActionRequest request) {
        if (request == null || !StringUtils.hasText(request.token())) {
            throw new IllegalArgumentException("Токен действия ИИ обязателен.");
        }

        PendingAiActionService.PendingAiAction action = pendingAiActionService.consume(request.token().trim());
        String assistantMessage = switch (action.type()) {
            case DELETE_SMART_CATEGORY -> resolveDeleteSmartCategory(action, request.confirmed());
        };

        Long userId = userContextService.getCurrentUser().getId();
        chatMessageRepository.save(new ChatMessage(userId, ChatMessage.Role.ASSISTANT, assistantMessage));
        return new AiChatResponse(new ChatMessageDto("assistant", assistantMessage), null);
    }

    private String resolveDeleteSmartCategory(PendingAiActionService.PendingAiAction action, boolean confirmed) {
        if (!confirmed) {
            return "Удаление категории \"%s\" отменено.".formatted(action.categoryName());
        }
        smartCategoryService.deleteCategory(action.categoryId());
        return "Категория \"%s\" удалена. Связанные расходы теперь можно привязать заново."
                .formatted(action.categoryName());
    }

    private List<ChatMessageDto> loadPersistedHistory(Long userId) {
        List<ChatMessageDto> history = chatMessageRepository.findByUserIdOrderByCreatedAtAsc(userId).stream()
                .filter(message -> message.getRole() != null)
                .filter(message -> StringUtils.hasText(message.getContent()))
                .map(message -> new ChatMessageDto(
                        message.getRole().name().toLowerCase(Locale.ROOT),
                        message.getContent().trim()
                ))
                .toList();
        if (history.size() <= MAX_HISTORY_MESSAGES) {
            return history;
        }
        return history.subList(history.size() - MAX_HISTORY_MESSAGES, history.size());
    }

    private List<ChatMessageDto> normalizeHistory(List<ChatMessageDto> history) {
        List<ChatMessageDto> sanitized = history == null ? List.of() : history.stream()
                .filter(message -> message != null && StringUtils.hasText(message.content()))
                .map(message -> new ChatMessageDto(
                        message.role() == null ? "" : message.role().trim(),
                        message.content().trim()
                ))
                .toList();
        if (sanitized.size() <= MAX_HISTORY_MESSAGES) {
            return sanitized;
        }
        return sanitized.subList(sanitized.size() - MAX_HISTORY_MESSAGES, sanitized.size());
    }

    private List<Message> toMessages(List<ChatMessageDto> history) {
        List<Message> messages = new ArrayList<>(history.size());
        for (ChatMessageDto message : history) {
            if (!StringUtils.hasText(message.content())) {
                continue;
            }
            String role = message.role() == null ? "" : message.role().trim().toLowerCase(Locale.ROOT);
            switch (role) {
                case "assistant" -> messages.add(new AssistantMessage(message.content().trim()));
                case "user" -> messages.add(new UserMessage(message.content().trim()));
                default -> {
                }
            }
        }
        return messages;
    }

    private boolean shouldEnableTools(String userMessage) {
        String normalized = userMessage.toLowerCase(Locale.ROOT);
        return normalized.contains("smart list")
                || normalized.contains("смарт")
                || normalized.contains("категор")
                || normalized.contains("лимит")
                || normalized.contains("создай")
                || normalized.contains("добавь")
                || normalized.contains("измени")
                || normalized.contains("обнови")
                || normalized.contains("удали")
                || normalized.contains("перенеси плат")
                || normalized.contains("отложи плат")
                || normalized.contains("переведи")
                || normalized.contains("перевод")
                || normalized.contains("с накоп")
                || normalized.contains("из накоп");
    }

    private String systemPrompt(String contextJson) {
        return """
                Ты персональный финансовый советник банка.
                Опирайся строго на финансовый контекст пользователя ниже и не выдумывай факты:
                %s

                Помогай с личными финансами простым языком:
                - объясняй текущее состояние денег, баланса, трат и лимитов;
                - давай практичные советы по накоплениям, бюджету и безопасным расходам;
                - если видишь риск кассового разрыва, предупреждай об этом прямо и предлагай конкретные шаги.

                Инструменты используй только когда пользователь явно просит выполнить действие:
                - создать, изменить или удалить категорию Smart List;
                - перевести деньги из накоплений;
                - перенести ближайший платеж.

                Для удаления категории Smart List сначала инициируй действие через инструмент и дождись подтверждения пользователя.
                Если вопрос только про совет, анализ или план накопления, отвечай без вызова инструментов.
                Отвечай естественно, без шаблонных приветствий и без лишней воды.
                """.formatted(contextJson);
    }
}
