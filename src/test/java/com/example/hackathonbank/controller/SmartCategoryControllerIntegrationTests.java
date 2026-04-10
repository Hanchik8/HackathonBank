package com.example.hackathonbank.controller;

import com.example.hackathonbank.controller.dto.SmartCategoryLinkTransactionRequest;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.repository.TransactionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class SmartCategoryControllerIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private TransactionRepository transactionRepository;

    @Test
    void linkTransactionCreatesSmartCategoryAndAttachesExpense() throws Exception {
        var transaction = transactionRepository.findByUserIdOrderByOccurredAtDesc(1L).stream()
                .filter(item -> item.getStatus() == TransactionStatus.COMPLETED)
                .filter(item -> item.getAmount().signum() < 0)
                .findFirst()
                .orElseThrow();

        mockMvc.perform(post("/api/v1/smart-categories/link-transaction")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SmartCategoryLinkTransactionRequest(
                                transaction.getId(),
                                "Еда из уведомления",
                                new BigDecimal("6500.00")
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Еда из уведомления"))
                .andExpect(jsonPath("$.plannedMonthly").value(6500.00));

        var updated = transactionRepository.findById(transaction.getId()).orElseThrow();
        assertThat(updated.getSmartCategory()).isNotNull();
        assertThat(updated.getSmartCategory().getName()).isEqualTo("Еда из уведомления");
    }
}
