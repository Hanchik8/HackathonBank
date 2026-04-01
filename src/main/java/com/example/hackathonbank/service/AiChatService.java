package com.example.hackathonbank.service;

import com.example.hackathonbank.dto.AiChatRequest;
import com.example.hackathonbank.dto.AiChatResponse;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.example.hackathonbank.model.ChatMessage;
import com.example.hackathonbank.repository.ChatMessageRepository;
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
    private final AiChatClient aiChatClient;
    private final UserContextService userContextService;
    private final ChatMessageRepository chatMessageRepository;

    public AiChatService(AiChatContextBuilder contextBuilder,
                         AiChatClient aiChatClient,
                         UserContextService userContextService,
                         ChatMessageRepository chatMessageRepository) {
        this.contextBuilder = contextBuilder;
        this.aiChatClient = aiChatClient;
        this.userContextService = userContextService;
        this.chatMessageRepository = chatMessageRepository;
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

        List<ChatMessageDto> messages = new ArrayList<>();
        messages.add(new ChatMessageDto("system", systemPrompt(contextBuilder.buildContextJson())));
        messages.addAll(loadPersistedHistory(userId));
        messages.add(new ChatMessageDto("user", userMessage));

        String assistantMessage = aiChatClient.complete(messages);

        chatMessageRepository.save(new ChatMessage(userId, ChatMessage.Role.USER, userMessage));
        chatMessageRepository.save(new ChatMessage(userId, ChatMessage.Role.ASSISTANT, assistantMessage));

        return new AiChatResponse(new ChatMessageDto("assistant", assistantMessage));
    }

    private List<ChatMessageDto> loadPersistedHistory(Long userId) {
        List<ChatMessageDto> history = chatMessageRepository.findTop100ByUserIdOrderByCreatedAtAsc(userId).stream()
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

    private String systemPrompt(String contextJson) {
        return """
                Ты персональный финансовый советник. Опирайся строго на переданный контекст: %s
                Предупреждай о кассовых разрывах, если сумма будущих scheduled_payment превышает баланс основного счета.
                Рекомендуй суммы для перевода в копилку на основе daily_safe_to_save.
                Отвечай естественно, без роботизированных приветствий и шаблонов.
                """.formatted(contextJson);
    }
}
