package com.example.hackathonbank.ai;

import com.example.hackathonbank.ai.dto.EnrichmentSummary;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.User;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ai.chat.client.ChatClient;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TransactionEnrichmentServiceTests {

    @Mock
    private ChatClient aiChatClient;

    @Mock
    private AiCapabilityService aiCapabilityService;

    @Mock
    private AiCallExecutor aiCallExecutor;

    private TransactionEnrichmentService transactionEnrichmentService;

    @BeforeEach
    void setUp() throws Exception {
        transactionEnrichmentService = new TransactionEnrichmentService(
                aiChatClient,
                aiCapabilityService,
                new ObjectMapper(),
                aiCallExecutor
        );
        lenient().doThrow(new IllegalStateException("AI timeout"))
                .when(aiCallExecutor)
                .execute(any());
    }

    @Test
    void fallbackEnrichmentBuildsThreeGroupsAndHighRiskReasoning() {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        List<Transaction> transactions = List.of(
                new Transaction(
                        user,
                        main,
                        null,
                        "Продукты",
                        "Green",
                        new BigDecimal("-1200.00"),
                        "Еда",
                        "food",
                        TransactionType.PURCHASE,
                        TransactionStatus.COMPLETED,
                        LocalDateTime.now()
                ),
                new Transaction(
                        user,
                        main,
                        null,
                        "Стриминг",
                        "Movie+",
                        new BigDecimal("-990.00"),
                        "Подписки",
                        "subscription",
                        TransactionType.PURCHASE,
                        TransactionStatus.COMPLETED,
                        LocalDateTime.now()
                ),
                new Transaction(
                        user,
                        main,
                        null,
                        "Кино",
                        "Cinema",
                        new BigDecimal("-1500.00"),
                        "Развлечения",
                        "entertainment",
                        TransactionType.PURCHASE,
                        TransactionStatus.COMPLETED,
                        LocalDateTime.now()
                )
        );
        List<ScheduledPayment> payments = List.of(
                new ScheduledPayment(
                        user,
                        main,
                        "Аренда",
                        new BigDecimal("25000.00"),
                        "Аренда",
                        LocalDate.now().plusDays(4),
                        PaymentStatus.SCHEDULED
                )
        );

        when(aiCapabilityService.isLiveAiEnabled()).thenReturn(false);

        EnrichmentSummary summary = transactionEnrichmentService.enrich(
                transactions,
                payments,
                new BigDecimal("-10000.00")
        );

        assertThat(summary.groups()).hasSize(3);
        assertThat(summary.riskLevel()).isEqualTo("HIGH");
        assertThat(summary.reasoning()).contains("Регулярные расходы");
        assertThat(summary.groups().get(0).name()).isEqualTo("Базовые потребности");
        assertThat(summary.groups().get(1).total()).isEqualByComparingTo("25990.00");
        assertThat(summary.groups().get(2).total()).isEqualByComparingTo("1500.00");
    }

    @Test
    void nullLiveSummaryFallsBackToDeterministicEnrichment() throws Exception {
        User user = new User("Azizkhan");
        Account main = new Account(user, AccountType.MAIN, "Main", new BigDecimal("15000.00"), "KGS");
        List<Transaction> transactions = List.of(
                new Transaction(
                        user,
                        main,
                        null,
                        "Такси",
                        "Yandex Go",
                        new BigDecimal("-1500.00"),
                        "Транспорт",
                        "transport",
                        TransactionType.PURCHASE,
                        TransactionStatus.COMPLETED,
                        LocalDateTime.now()
                )
        );

        when(aiCapabilityService.isLiveAiEnabled()).thenReturn(true);
        doReturn(null).when(aiCallExecutor).execute(any());

        EnrichmentSummary summary = transactionEnrichmentService.enrich(
                transactions,
                List.of(),
                new BigDecimal("-5000.00")
        );

        assertThat(summary).isNotNull();
        assertThat(summary.reasoning()).contains("Регулярные расходы");
        assertThat(summary.groups()).hasSize(3);
    }
}
