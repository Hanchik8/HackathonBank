package com.example.hackathonbank.controller;

import com.example.hackathonbank.dto.AiChatRequest;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.example.hackathonbank.service.AiChatClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class AiChatControllerIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AiChatClient aiChatClient;

    @Test
    void chatEndpointPrependsFreshFinancialContextAndReturnsAssistantReply() throws Exception {
        when(aiChatClient.complete(anyList())).thenReturn("Сейчас безопаснее держать ликвидность под аренду.");

        mockMvc.perform(post("/api/v1/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AiChatRequest(
                                List.of(
                                        new ChatMessageDto("user", "Покажи краткую сводку."),
                                        new ChatMessageDto("assistant", "У вас спокойный остаток.")
                                ),
                                "Что делать с деньгами до зарплаты?"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message.role").value("assistant"))
                .andExpect(jsonPath("$.message.content").value("Сейчас безопаснее держать ликвидность под аренду."));

        ArgumentCaptor<List<ChatMessageDto>> captor = ArgumentCaptor.forClass(List.class);
        verify(aiChatClient).complete(captor.capture());

        List<ChatMessageDto> messages = captor.getValue();
        assertThat(messages).hasSize(4);
        assertThat(messages.get(0).role()).isEqualTo("system");
        assertThat(messages.get(0).content()).contains("Ты персональный финансовый советник");
        assertThat(messages.get(0).content()).contains("\"balances\"");
        assertThat(messages.get(0).content()).contains("\"transactionsLast3Months\"");
        assertThat(messages.get(1).role()).isEqualTo("user");
        assertThat(messages.get(2).role()).isEqualTo("assistant");
        assertThat(messages.get(3).content()).isEqualTo("Что делать с деньгами до зарплаты?");
    }

    @Test
    void chatEndpointRejectsBlankMessage() throws Exception {
        mockMvc.perform(post("/api/v1/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"history":[],"newMessage":"   "}
                                """))
                .andExpect(status().isBadRequest());
    }
}
