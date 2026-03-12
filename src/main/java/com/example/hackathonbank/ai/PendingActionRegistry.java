package com.example.hackathonbank.ai;

import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class PendingActionRegistry {

    private final Map<String, PendingAiAction> pendingActions = new ConcurrentHashMap<>();

    public void register(PendingAiAction action) {
        pendingActions.put(action.actionToken(), action);
    }

    public PendingAiAction require(String token) {
        PendingAiAction action = pendingActions.get(token);
        if (action == null) {
            throw new IllegalArgumentException("Токен действия недействителен или уже истек.");
        }
        return action;
    }

    public void remove(String token) {
        pendingActions.remove(token);
    }

    public void clear() {
        pendingActions.clear();
    }
}
