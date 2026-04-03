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

    @MockBean
    private AiChatClient aiChatClient;

    @Test
    void chatEndpointPrependsFreshFinancialContextAndReturnsAssistantReply() throws Exception {
        when(aiChatClient.complete(anyList())).thenReturn("РЎРµР№С‡Р°СЃ Р±РµР·РѕРїР°СЃРЅРµРµ РґРµСЂР¶Р°С‚СЊ Р»РёРєРІРёРґРЅРѕСЃС‚СЊ РїРѕРґ Р°СЂРµРЅРґСѓ.");

        mockMvc.perform(post("/api/v1/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AiChatRequest(
                                List.of(
                                        new ChatMessageDto("user", "РџРѕРєР°Р¶Рё РєСЂР°С‚РєСѓСЋ СЃРІРѕРґРєСѓ."),
                                        new ChatMessageDto("assistant", "РЈ РІР°СЃ СЃРїРѕРєРѕР№РЅС‹Р№ РѕСЃС‚Р°С‚РѕРє.")
                                ),
                                "Р§С‚Рѕ РґРµР»Р°С‚СЊ СЃ РґРµРЅСЊРіР°РјРё РґРѕ Р·Р°СЂРїР»Р°С‚С‹?"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message.role").value("assistant"))
                .andExpect(jsonPath("$.message.content").value("РЎРµР№С‡Р°СЃ Р±РµР·РѕРїР°СЃРЅРµРµ РґРµСЂР¶Р°С‚СЊ Р»РёРєРІРёРґРЅРѕСЃС‚СЊ РїРѕРґ Р°СЂРµРЅРґСѓ."));

        ArgumentCaptor<List<ChatMessageDto>> captor = ArgumentCaptor.forClass(List.class);
        verify(aiChatClient).complete(captor.capture());

        List<ChatMessageDto> messages = captor.getValue();
        assertThat(messages).hasSize(2);
        assertThat(messages.get(0).role()).isEqualTo("system");
        assertThat(messages.get(0).content()).contains("Ты персональный финансовый советник");
        assertThat(messages.get(0).content()).contains("\"balances\"");
        assertThat(messages.get(0).content()).contains("\"transactionsLast3Months\"");
        assertThat(messages.get(1).role()).isEqualTo("user");
        assertThat(messages.get(1).content()).isEqualTo("Р§С‚Рѕ РґРµР»Р°С‚СЊ СЃ РґРµРЅСЊРіР°РјРё РґРѕ Р·Р°СЂРїР»Р°С‚С‹?");
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
        when(aiChatClient.complete(anyList())).thenReturn("Р’Р°Р¶РЅРѕ РґРµСЂР¶Р°С‚СЊ СЂРµР·РµСЂРІ РїРѕРґ Р±Р»РёР¶Р°Р№С€РёР№ РїР»Р°С‚РµР¶.");

        mockMvc.perform(post("/api/v1/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AiChatRequest(
                                List.of(),
                                "Р§С‚Рѕ Сѓ РјРµРЅСЏ СЃ Р»РёРєРІРёРґРЅРѕСЃС‚СЊСЋ РґРѕ Р·Р°СЂРїР»Р°С‚С‹?"
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/ai/chat/history"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].role").value("user"))
                .andExpect(jsonPath("$[0].content").value("Р§С‚Рѕ Сѓ РјРµРЅСЏ СЃ Р»РёРєРІРёРґРЅРѕСЃС‚СЊСЋ РґРѕ Р·Р°СЂРїР»Р°С‚С‹?"))
                .andExpect(jsonPath("$[1].role").value("assistant"))
                .andExpect(jsonPath("$[1].content").value("Р’Р°Р¶РЅРѕ РґРµСЂР¶Р°С‚СЊ СЂРµР·РµСЂРІ РїРѕРґ Р±Р»РёР¶Р°Р№С€РёР№ РїР»Р°С‚РµР¶."));
    }
}
