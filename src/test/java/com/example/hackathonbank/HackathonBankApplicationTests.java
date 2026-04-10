package com.example.hackathonbank;

import com.example.hackathonbank.controller.dto.ExternalTransferRequest;
import com.example.hackathonbank.controller.dto.ScheduledPaymentRequest;
import com.example.hackathonbank.controller.dto.TransferRequest;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.TransferRecipientType;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

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
                .andExpect(jsonPath("$.length()").value(48))
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

        assertThat(transactionRepository.findByUserIdOrderByOccurredAtDesc(1L)).hasSize(50);
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
    void dashboardEndpointUsesRequestedHorizon() throws Exception {
        mockMvc.perform(get("/api/v1/ai/dashboard?offsetDays=99"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.horizonDays").value(99))
                .andExpect(jsonPath("$.points.length()").value(100))
                .andExpect(jsonPath("$.scheduledPayments.length()").value(3));
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
    void createScheduledPaymentEndpointCreatesPaymentAndLedgerEntry() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();

        mockMvc.perform(post("/api/v1/scheduled-payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ScheduledPaymentRequest(
                                mainAccount.getId(),
                                "Интернет",
                                "HomeNet",
                                "Подписки",
                                new BigDecimal("3900.00"),
                                LocalDate.now().plusDays(5)
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Интернет"))
                .andExpect(jsonPath("$.counterparty").value("HomeNet"))
                .andExpect(jsonPath("$.iconKey").value("subscription"))
                .andExpect(jsonPath("$.status").value("SCHEDULED"));

        assertThat(transactionRepository.findByUserIdOrderByOccurredAtDesc(1L))
                .extracting(transaction -> transaction.getTitle())
                .contains("Автоплатеж: Интернет");
    }

    @Test
    void analyzeReturnsAlertForUpcomingCashGapWithoutLegacyCurrency() throws Exception {
        mockMvc.perform(post("/api/v1/ai/analyze")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"offsetDays":10}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasAlert").value(true))
                .andExpect(jsonPath("$.message", not(containsString("KZT"))))
                .andExpect(jsonPath("$.actionToken").isNotEmpty());
    }

    @Test
    void analyzeUsesFirstNegativeDateInsteadOfWindowEnd() throws Exception {
        String expectedDate = shortDateLabel(LocalDate.now().plusDays(4));

        mockMvc.perform(post("/api/v1/ai/analyze")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"offsetDays":10}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasAlert").value(true))
                .andExpect(jsonPath("$.message", containsString(expectedDate)));
    }

    @Test
    void analyzeExplainsMultiplePaymentDatesBeforeMinimumDeficit() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();
        LocalDate firstPaymentDate = LocalDate.now().plusDays(4);
        LocalDate secondPaymentDate = LocalDate.now().plusDays(6);

        mockMvc.perform(post("/api/v1/scheduled-payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ScheduledPaymentRequest(
                                mainAccount.getId(),
                                "Долг",
                                "Друг",
                                "Покупки",
                                new BigDecimal("10000.00"),
                                secondPaymentDate
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/ai/analyze")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"offsetDays":10}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("25000.00 KGS")))
                .andExpect(jsonPath("$.message", containsString("Аренда")))
                .andExpect(jsonPath("$.message", containsString("10000.00 KGS")))
                .andExpect(jsonPath("$.message", containsString("Долг")))
                .andExpect(jsonPath("$.message", containsString("В сумме к")))
                .andExpect(jsonPath("$.message", containsString("дефицит составит")));
    }

    @Test
    void analyzeRespectsOffsetDaysAndSkipsAlertOutsidePaymentWindow() throws Exception {
        mockMvc.perform(post("/api/v1/ai/analyze")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"offsetDays":0}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasAlert").value(false))
                .andExpect(jsonPath("$.actionToken").isEmpty());
    }

    @Test
    void analyzeReactsToNonRentScheduledPayment() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();

        mockMvc.perform(post("/api/v1/scheduled-payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ScheduledPaymentRequest(
                                mainAccount.getId(),
                                "Страховка авто",
                                "Insurance Co",
                                "Страховка",
                                new BigDecimal("48000.00"),
                                LocalDate.now().plusDays(3)
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/ai/analyze")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"offsetDays":10}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasAlert").value(true))
                .andExpect(jsonPath("$.message", containsString("Страховка авто")));
    }

    @Test
    void executeUsesSuggestedActionAndUpdatesBalances() throws Exception {
        String analyzeResponse = mockMvc.perform(post("/api/v1/ai/analyze")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"offsetDays":10}
                                """))
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

        assertThat(mainAccount.getBalance()).isEqualByComparingTo("65000.00");
        assertThat(savingsAccount.getBalance()).isEqualByComparingTo("0.00");
    }

    @Test
    void externalTransferRejectsSavingsAccountAsSource() throws Exception {
        var savingsAccount = accountRepository.findByUserIdAndType(1L, AccountType.SAVINGS).orElseThrow();

        mockMvc.perform(post("/api/v1/transfer/external")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ExternalTransferRequest(
                                savingsAccount.getId(),
                                TransferRecipientType.USER,
                                "Aigerim",
                                new BigDecimal("1000.00"),
                                "Проверка"
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("накопительного депозита")));
    }

    @Test
    void autoDailySaveSettingCanBeEnabledAndReadBack() throws Exception {
        mockMvc.perform(get("/api/v1/ai/auto-daily-save"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(false));

        mockMvc.perform(post("/api/v1/ai/auto-daily-save")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"enabled":true}
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/ai/auto-daily-save"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(true));
    }

    @Test
    void dailySafeToSavePreviewReturnsCalculationBreakdown() throws Exception {
        mockMvc.perform(get("/api/v1/ai/daily-safe-to-save"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(false))
                .andExpect(jsonPath("$.suggestedAmount").exists())
                .andExpect(jsonPath("$.safeBalance").exists())
                .andExpect(jsonPath("$.currentBalance").exists())
                .andExpect(jsonPath("$.requiredPayments").exists())
                .andExpect(jsonPath("$.lifeBuffer").exists())
                .andExpect(jsonPath("$.nextIncomeDate").exists())
                .andExpect(jsonPath("$.daysToNextIncome").isNumber())
                .andExpect(jsonPath("$.status").isString());
    }

    @Test
    void saveSuggestionEndpointReturnsCompatibilityPayload() throws Exception {
        mockMvc.perform(get("/api/v1/ai/save-suggestion"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount").exists())
                .andExpect(jsonPath("$.reason").isString())
                .andExpect(jsonPath("$.safetyReserve").exists());
    }

    @Test
    void missingRouteReturnsNotFoundInsteadOfInternalServerError() throws Exception {
        mockMvc.perform(get("/api/v1/ai/route-that-does-not-exist"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value("Ресурс не найден."));
    }

    @Test
    void simulateDayAdvancesVirtualDateAndExecutesDailySaveWhenEnabled() throws Exception {
        var mainAccount = accountRepository.findByUserIdAndType(1L, AccountType.MAIN).orElseThrow();

        mockMvc.perform(post("/api/v1/demo/accounts/{accountId}/adjust", mainAccount.getId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"delta":60000.00,"title":"Демо пополнение"}
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/ai/auto-daily-save")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"enabled":true}
                                """))
                .andExpect(status().isOk());

        String body = mockMvc.perform(post("/api/v1/demo/simulate-day"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currentDate").exists())
                .andExpect(jsonPath("$.autoSaveExecuted").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode json = objectMapper.readTree(body);
        assertThat(json.get("savedAmount").decimalValue()).isPositive();
        assertThat(json.get("notification").asText()).isNotBlank();
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

    private String shortDateLabel(LocalDate value) {
        return "%d %s".formatted(value.getDayOfMonth(), switch (value.getMonthValue()) {
            case 1 -> "янв.";
            case 2 -> "фев.";
            case 3 -> "мар.";
            case 4 -> "апр.";
            case 5 -> "мая";
            case 6 -> "июн.";
            case 7 -> "июл.";
            case 8 -> "авг.";
            case 9 -> "сент.";
            case 10 -> "окт.";
            case 11 -> "нояб.";
            default -> "дек.";
        });
    }
}
