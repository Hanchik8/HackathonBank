package com.example.hackathonbank.service;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@Transactional
class AiChatContextBuilderTests {

    @Autowired
    private AiChatContextBuilder aiChatContextBuilder;

    @Test
    void buildsFinancialSnapshotForCurrentUser() {
        ObjectNode context = aiChatContextBuilder.buildContext(1L);

        assertThat(context.path("userId").asLong()).isEqualTo(1L);
        assertThat(context.path("balances").path("main").asText()).isEqualTo("15000.00");
        assertThat(context.path("balances").path("savings").asText()).isEqualTo("50000.00");
        assertThat(context.path("transactionsLast3Months").isArray()).isTrue();
        assertThat(context.path("transactionsLast3Months").size()).isPositive();
        assertThat(context.path("scheduledPayments").isArray()).isTrue();
        assertThat(context.path("dailySafeToSave").path("status").isTextual()).isTrue();
        assertThat(context.path("smartCategories").isArray()).isTrue();
    }
}
