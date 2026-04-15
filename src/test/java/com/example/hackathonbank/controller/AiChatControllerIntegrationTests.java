package com.example.hackathonbank.controller;

import com.example.hackathonbank.dto.AiChatActionRequest;
import com.example.hackathonbank.dto.AiChatRequest;
import com.example.hackathonbank.dto.ChatMessageDto;
import com.example.hackathonbank.model.SmartCategory;
import com.example.hackathonbank.repository.SmartCategoryRepository;
import com.example.hackathonbank.service.PendingAiActionService;
import com.example.hackathonbank.service.UserContextService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.Message;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

    @Autowired
    private PendingAiActionService pendingAiActionService;

    @Autowired
    private SmartCategoryRepository smartCategoryRepository;

    @Autowired
    private UserContextService userContextService;

    @MockBean
    private ChatClient chatClient;

    @MockBean
    private ChatClient.ChatClientRequestSpec requestSpec;

    @MockBean
    private ChatClient.CallResponseSpec responseSpec;

    @BeforeEach
    void setUpChatClient() {
        when(chatClient.prompt()).thenReturn(requestSpec);
        when(requestSpec.system(any(String.class))).thenReturn(requestSpec);
        when(requestSpec.messages(anyList())).thenReturn(requestSpec);
        when(requestSpec.user(any(String.class))).thenReturn(requestSpec);
        when(requestSpec.tools(any(Object[].class))).thenReturn(requestSpec);
        when(requestSpec.call()).thenReturn(responseSpec);
    }

    @Test
    void chatEndpointPrependsFreshFinancialContextAndReturnsAssistantReply() throws Exception {
        when(responseSpec.content()).thenReturn("Держите ликвидность под аренду и не увеличивайте необязательные траты.");

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
                .andExpect(jsonPath("$.message.content").value("Держите ликвидность под аренду и не увеличивайте необязательные траты."))
                .andExpect(jsonPath("$.pendingAction").isEmpty());

        ArgumentCaptor<List> captor = ArgumentCaptor.forClass(List.class);
        verify(requestSpec).messages(captor.capture());

        @SuppressWarnings("unchecked")
        List<Message> messages = captor.getValue();
        assertThat(messages).hasSize(2);
        verify(requestSpec).system(org.mockito.ArgumentMatchers.contains("финансовый контекст пользователя"));
        verify(requestSpec).system(org.mockito.ArgumentMatchers.contains("\"balances\""));
        verify(requestSpec).user("Что делать с деньгами до зарплаты?");
        verify(requestSpec, never()).tools(any(Object[].class));
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

    @Test
    void historyEndpointReturnsPersistedConversation() throws Exception {
        when(responseSpec.content()).thenReturn("Важно держать резерв под ближайший платеж.");

        mockMvc.perform(post("/api/v1/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AiChatRequest(
                                List.of(),
                                "Что у меня с ликвидностью до зарплаты?"
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/ai/chat/history"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].role").value("user"))
                .andExpect(jsonPath("$[0].content").value("Что у меня с ликвидностью до зарплаты?"))
                .andExpect(jsonPath("$[1].role").value("assistant"))
                .andExpect(jsonPath("$[1].content").value("Важно держать резерв под ближайший платеж."));
    }

    @Test
    void resolveActionEndpointDeletesSmartCategoryAfterConfirmation() throws Exception {
        SmartCategory category = smartCategoryRepository.save(new SmartCategory(
                userContextService.getCurrentUser(),
                "Тестовая категория",
                new BigDecimal("5000.00"),
                false
        ));
        var pendingAction = pendingAiActionService.registerDeleteSmartCategory(category);

        mockMvc.perform(post("/api/v1/ai/chat/action")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AiChatActionRequest(
                                pendingAction.token(),
                                true
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message.role").value("assistant"))
                .andExpect(jsonPath("$.message.content").value(containsString(category.getName())))
                .andExpect(jsonPath("$.pendingAction").isEmpty());

        assertThat(smartCategoryRepository.findById(category.getId())).isEmpty();
    }
}
