package com.example.hackathonbank;

import com.example.hackathonbank.ai.PendingActionRegistry;
import com.example.hackathonbank.controller.dto.ExternalTransferRequest;
import com.example.hackathonbank.controller.dto.TransferRequest;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.TransferRecipientType;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class HackathonBankApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private TransactionRepository transactionRepository;

    @Autowired
    private PendingActionRegistry pendingActionRegistry;

    @AfterEach
    void tearDown() {
        pendingActionRegistry.clear();
    }

    @Test
    void accountsEndpointReturnsSeededAccounts() throws Exception {
        mockMvc.perform(get("/api/v1/accounts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].name").value("Main"))
                .andExpect(jsonPath("$[0].currency").value("KGS"))
                .andExpect(jsonPath("$[1].name").value("Savings"))
                .andExpect(jsonPath("$[1].currency").value("KGS"));
    }

    @Test
    void transactionsEndpointReturnsSeededOperations() throws Exception {
        mockMvc.perform(get("/api/v1/transactions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(21))
                .andExpect(jsonPath("$[0].title").value("Автоплатеж: Аренда"))
                .andExpect(jsonPath("$[0].status").value("SCHEDULED"));
    }

    @Test
    void transferEndpointMovesMoneyAndCreatesLedgerEntries() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();
        var savingsAccount = accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS).orElseThrow();

        mockMvc.perform(post("/api/v1/transfer")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new TransferRequest(
                                savingsAccount.getId(),
                                mainAccount.getId(),
                                new BigDecimal("5000.00"),
                                "Тестовый перевод"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Перевод выполнен."))
                .andExpect(jsonPath("$.fromAccount.balance").value(45000.00))
                .andExpect(jsonPath("$.toAccount.balance").value(20000.00));

        assertThat(transactionRepository.findByUserIdOrderByOccurredAtDesc(1L)).hasSize(23);
    }

    @Test
    void transferEndpointRejectsInsufficientFunds() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();
        var savingsAccount = accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS).orElseThrow();

        mockMvc.perform(post("/api/v1/transfer")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new TransferRequest(
                                mainAccount.getId(),
                                savingsAccount.getId(),
                                new BigDecimal("999999.00"),
                                "Проверка лимита"
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("Недостаточно средств")));
    }

    @Test
    void dashboardEndpointClampsHorizonToTenDays() throws Exception {
        mockMvc.perform(get("/api/v1/ai/dashboard?offsetDays=99"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.horizonDays").value(10))
                .andExpect(jsonPath("$.points.length()").value(11))
                .andExpect(jsonPath("$.scheduledPayments.length()").value(1));
    }

    @Test
    void externalTransferEndpointSupportsUserTransfer() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();

        mockMvc.perform(post("/api/v1/transfer/external")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ExternalTransferRequest(
                                mainAccount.getId(),
                                TransferRecipientType.USER,
                                "Aigerim",
                                new BigDecimal("1800.00"),
                                "Подарок"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recipientType").value("USER"))
                .andExpect(jsonPath("$.recipientName").value("Aigerim"))
                .andExpect(jsonPath("$.fromAccount.balance").value(13200.00));
    }

    @Test
    void analyzeReturnsAlertForUpcomingCashGapWithoutLegacyCurrency() throws Exception {
        mockMvc.perform(post("/api/v1/ai/analyze"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasAlert").value(true))
                .andExpect(jsonPath("$.message", not(containsString("KZT"))))
                .andExpect(jsonPath("$.actionToken").isNotEmpty());
    }

    @Test
    void executeUsesSuggestedActionAndUpdatesBalances() throws Exception {
        String analyzeResponse = mockMvc.perform(post("/api/v1/ai/analyze"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode analyzeJson = objectMapper.readTree(analyzeResponse);
        String actionToken = analyzeJson.get("actionToken").asText();

        mockMvc.perform(post("/api/v1/ai/execute")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"actionToken":"%s"}
                                """.formatted(actionToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();
        var savingsAccount = accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS).orElseThrow();

        assertThat(mainAccount.getBalance()).isEqualByComparingTo("25000.00");
        assertThat(savingsAccount.getBalance()).isEqualByComparingTo("40000.00");
    }

    @Test
    void executeReturnsBadRequestForUnknownToken() throws Exception {
        mockMvc.perform(post("/api/v1/ai/execute")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"actionToken":"missing-token"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Токен действия недействителен или уже истек."));
    }
}
