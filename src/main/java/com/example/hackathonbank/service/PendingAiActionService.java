package com.example.hackathonbank.service;

import com.example.hackathonbank.dto.AiChatPendingActionDto;
import com.example.hackathonbank.model.SmartCategory;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class PendingAiActionService {

    private final Map<String, PendingAiAction> actionsByToken = new ConcurrentHashMap<>();
    private final Map<Long, String> latestTokenByUser = new ConcurrentHashMap<>();
    private final UserContextService userContextService;

    public PendingAiActionService(UserContextService userContextService) {
        this.userContextService = userContextService;
    }

    public AiChatPendingActionDto registerDeleteSmartCategory(SmartCategory category) {
        Long userId = userContextService.getCurrentUser().getId();
        String token = UUID.randomUUID().toString();
        PendingAiAction action = new PendingAiAction(
                token,
                userId,
                PendingActionType.DELETE_SMART_CATEGORY,
                category.getId(),
                category.getName(),
                LocalDateTime.now()
        );
        actionsByToken.put(token, action);
        latestTokenByUser.put(userId, token);
        return toDto(action);
    }

    public AiChatPendingActionDto takeLatestForUser(Long userId) {
        String token = latestTokenByUser.remove(userId);
        if (token == null) {
            return null;
        }
        PendingAiAction action = actionsByToken.get(token);
        return action == null ? null : toDto(action);
    }

    public PendingAiAction consume(String token) {
        Long userId = userContextService.getCurrentUser().getId();
        PendingAiAction action = actionsByToken.remove(token);
        if (action == null || !action.userId().equals(userId)) {
            throw new IllegalArgumentException("Ожидаемое действие AI не найдено.");
        }
        latestTokenByUser.remove(userId, token);
        return action;
    }

    private AiChatPendingActionDto toDto(PendingAiAction action) {
        return new AiChatPendingActionDto(
                action.type().apiValue,
                action.token(),
                action.categoryId().toString(),
                action.categoryName(),
                "Подтвердите удаление категории",
                "Вы уверены, что хотите удалить категорию \"%s\"? Это повлияет на историю привязок."
                        .formatted(action.categoryName())
        );
    }

    public record PendingAiAction(
            String token,
            Long userId,
            PendingActionType type,
            Long categoryId,
            String categoryName,
            LocalDateTime createdAt
    ) {
    }

    public enum PendingActionType {
        DELETE_SMART_CATEGORY("deleteSmartCategory");

        private final String apiValue;

        PendingActionType(String apiValue) {
            this.apiValue = apiValue;
        }
    }
}
