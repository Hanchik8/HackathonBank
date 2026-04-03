package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    List<ChatMessage> findByUserIdOrderByCreatedAtAsc(Long userId);

    List<ChatMessage> findTop100ByUserIdOrderByCreatedAtAsc(Long userId);
}
