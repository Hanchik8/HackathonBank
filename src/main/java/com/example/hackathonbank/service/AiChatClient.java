package com.example.hackathonbank.service;

import com.example.hackathonbank.dto.ChatMessageDto;

import java.util.List;

public interface AiChatClient {

    String complete(List<ChatMessageDto> messages);
}
