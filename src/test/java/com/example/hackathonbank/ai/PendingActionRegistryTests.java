package com.example.hackathonbank.ai;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PendingActionRegistryTests {

    private final PendingActionRegistry registry = new PendingActionRegistry();

    @Test
    void registerRequireRemoveAndClearWorkAsExpected() {
        PendingAiAction first = new PendingAiAction(
                "token-1",
                AgentActionType.AUTO_TRANSFER,
                "Перевести деньги",
                null,
                null,
                LocalDateTime.now()
        );
        PendingAiAction second = new PendingAiAction(
                "token-2",
                AgentActionType.POSTPONE_PAYMENT,
                "Перенести платеж",
                null,
                10L,
                LocalDateTime.now()
        );

        registry.register(first);
        registry.register(second);

        assertThat(registry.require("token-1")).isEqualTo(first);
        registry.remove("token-1");
        assertThatThrownBy(() -> registry.require("token-1"))
                .isInstanceOf(IllegalArgumentException.class);

        registry.clear();
        assertThatThrownBy(() -> registry.require("token-2"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
