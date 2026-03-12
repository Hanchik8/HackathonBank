package com.example.hackathonbank.ai;

import com.example.hackathonbank.config.AiProperties;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AiCallExecutorTests {

    @Test
    void executeTimesOutSlowCall() {
        AiProperties aiProperties = new AiProperties();
        aiProperties.setRequestTimeoutSeconds(1);
        AiCallExecutor executor = new AiCallExecutor(aiProperties);

        assertThatThrownBy(() -> executor.execute(() -> {
            Thread.sleep(1500);
            return "late";
        }))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("timed out");
    }
}
