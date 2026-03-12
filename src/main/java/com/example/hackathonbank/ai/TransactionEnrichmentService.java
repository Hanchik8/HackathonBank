package com.example.hackathonbank.ai;

import com.example.hackathonbank.ai.dto.EnrichmentGroup;
import com.example.hackathonbank.ai.dto.EnrichmentSummary;
import com.example.hackathonbank.model.ScheduledPayment;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;

@Service
public class TransactionEnrichmentService {

    private static final Logger log = LoggerFactory.getLogger(TransactionEnrichmentService.class);
    private static final String BASIC = "Базовые потребности";
    private static final String REGULAR = "Регулярные/Обязательные";
    private static final String DYNAMIC = "Динамические";

    private final ChatClient aiChatClient;
    private final AiCapabilityService aiCapabilityService;
    private final ObjectMapper objectMapper;
    private final AiCallExecutor aiCallExecutor;

    public TransactionEnrichmentService(ChatClient aiChatClient,
                                        AiCapabilityService aiCapabilityService,
                                        ObjectMapper objectMapper,
                                        AiCallExecutor aiCallExecutor) {
        this.aiChatClient = aiChatClient;
        this.aiCapabilityService = aiCapabilityService;
        this.objectMapper = objectMapper;
        this.aiCallExecutor = aiCallExecutor;
    }

    public EnrichmentSummary enrich(List<Transaction> transactions,
                                    List<ScheduledPayment> scheduledPayments,
                                    BigDecimal minimumProjectedBalance) {
        if (aiCapabilityService.isLiveAiEnabled()) {
            try {
                EnrichmentSummary liveSummary = aiCallExecutor.execute(
                        () -> liveEnrichment(transactions, scheduledPayments, minimumProjectedBalance)
                );
                if (isValidSummary(liveSummary)) {
                    return liveSummary;
                }
                log.warn("Live AI enrichment returned empty or invalid summary, using fallback mode.");
            } catch (Exception exception) {
                log.warn("Live AI enrichment failed, using fallback mode: {}", exception.getMessage());
            }
        }
        return fallbackEnrichment(transactions, scheduledPayments, minimumProjectedBalance);
    }

    private EnrichmentSummary liveEnrichment(List<Transaction> transactions,
                                             List<ScheduledPayment> scheduledPayments,
                                             BigDecimal minimumProjectedBalance) throws JsonProcessingException {
        String transactionsPayload = objectMapper.writeValueAsString(
                transactions.stream()
                        .filter(transaction -> transaction.getStatus() == TransactionStatus.COMPLETED)
                        .map(transaction -> new PromptTransaction(
                                transaction.getTitle(),
                                transaction.getAmount(),
                                transaction.getCategory(),
                                transaction.getCounterparty(),
                                transaction.getOccurredAt().toString()
                        ))
                        .toList()
        );
        String scheduledPayload = objectMapper.writeValueAsString(
                scheduledPayments.stream()
                        .map(payment -> new PromptPayment(
                                payment.getId(),
                                payment.getTitle(),
                                payment.getCounterparty(),
                                payment.getCategory(),
                                payment.getAmount(),
                                payment.getDueDate().toString()
                        ))
                        .toList()
        );

        return aiChatClient.prompt()
                .system("""
                        Ты аналитик мобильного банка.
                        Верни только JSON с полями groups, riskLevel и reasoning.
                        В groups верни ровно 3 объекта.
                        Используй названия групп: Базовые потребности, Регулярные/Обязательные, Динамические.
                        Указывай total как сумму расхода по группе.
                        В patterns верни 2-4 коротких паттерна, по которым ты объединил операции.
                        """)
                .user("""
                        Раздели транзакции пользователя на 3 группы: 1. Базовые потребности (еда, транспорт), 2. Регулярные/Обязательные (аренда, подписки), 3. Динамические (развлечения). Оцени риск кассового разрыва на основе этих групп.
                        Минимальный прогноз по основному счету: %s
                        Транзакции: %s
                        Запланированные платежи: %s
                        """.formatted(minimumProjectedBalance.toPlainString(), transactionsPayload, scheduledPayload))
                .call()
                .entity(EnrichmentSummary.class);
    }

    private boolean isValidSummary(EnrichmentSummary summary) {
        return summary != null
                && summary.groups() != null
                && summary.groups().size() == 3
                && summary.reasoning() != null
                && !summary.reasoning().isBlank()
                && summary.riskLevel() != null
                && !summary.riskLevel().isBlank();
    }

    private EnrichmentSummary fallbackEnrichment(List<Transaction> transactions,
                                                 List<ScheduledPayment> scheduledPayments,
                                                 BigDecimal minimumProjectedBalance) {
        GroupAccumulator basic = new GroupAccumulator(List.of("еда", "транспорт"));
        GroupAccumulator regular = new GroupAccumulator(List.of("аренда", "подписки"));
        GroupAccumulator dynamic = new GroupAccumulator(List.of("развлечения", "импульсные покупки"));

        for (Transaction transaction : transactions) {
            if (transaction.getStatus() != TransactionStatus.COMPLETED
                    || transaction.getAmount().compareTo(BigDecimal.ZERO) >= 0) {
                continue;
            }
            String normalized = (transaction.getTitle() + " " + transaction.getCategory()).toLowerCase(Locale.ROOT);
            BigDecimal absoluteAmount = transaction.getAmount().abs();

            if (containsAny(normalized, "продукт", "еда", "кофе", "такси", "автобус", "транспорт", "азс", "аптек")) {
                basic.add(absoluteAmount, transaction.getCategory());
            } else if (containsAny(normalized, "аренда", "подпис", "интернет", "мобиль", "коммун", "страхов")) {
                regular.add(absoluteAmount, transaction.getCategory());
            } else {
                dynamic.add(absoluteAmount, transaction.getCategory());
            }
        }

        for (ScheduledPayment scheduledPayment : scheduledPayments) {
            String normalized = (scheduledPayment.getTitle() + " " + scheduledPayment.getCategory()).toLowerCase(Locale.ROOT);
            if (containsAny(normalized, "еда", "такси", "транспорт")) {
                basic.add(scheduledPayment.getAmount(), scheduledPayment.getTitle());
            } else if (containsAny(normalized, "аренда", "подпис", "интернет", "коммун", "страхов", "кредит", "ипотек")) {
                regular.add(scheduledPayment.getAmount(), scheduledPayment.getTitle());
            } else {
                dynamic.add(scheduledPayment.getAmount(), scheduledPayment.getTitle());
            }
        }

        String riskLevel = minimumProjectedBalance.compareTo(BigDecimal.ZERO) < 0 ? "HIGH" : "LOW";
        String reasoning = minimumProjectedBalance.compareTo(BigDecimal.ZERO) < 0
                ? "Регулярные расходы и ближайшие запланированные списания уводят основной счет в минус. Нужен перенос платежа или подпитка сбережениями."
                : "Даже с учетом запланированных списаний основной счет остается положительным.";

        List<EnrichmentGroup> groups = List.of(
                basic.toGroup(BASIC),
                regular.toGroup(REGULAR),
                dynamic.toGroup(DYNAMIC)
        );
        return new EnrichmentSummary(groups, riskLevel, reasoning);
    }

    private boolean containsAny(String value, String... candidates) {
        for (String candidate : candidates) {
            if (value.contains(candidate)) {
                return true;
            }
        }
        return false;
    }

    private record PromptTransaction(
            String title,
            BigDecimal amount,
            String category,
            String counterparty,
            String occurredAt
    ) {
    }

    private record PromptPayment(
            Long id,
            String title,
            String counterparty,
            String category,
            BigDecimal amount,
            String dueDate
    ) {
    }

    private static final class GroupAccumulator {

        private final List<String> fallbackPatterns;
        private final LinkedHashSet<String> patterns = new LinkedHashSet<>();
        private BigDecimal total = BigDecimal.ZERO;

        private GroupAccumulator(List<String> fallbackPatterns) {
            this.fallbackPatterns = fallbackPatterns;
        }

        private void add(BigDecimal amount, String pattern) {
            total = total.add(amount);
            if (pattern != null && !pattern.isBlank()) {
                patterns.add(pattern);
            }
        }

        private EnrichmentGroup toGroup(String name) {
            List<String> resultPatterns = new ArrayList<>(patterns);
            if (resultPatterns.isEmpty()) {
                resultPatterns.addAll(fallbackPatterns);
            }
            return new EnrichmentGroup(
                    name,
                    total.setScale(2, RoundingMode.HALF_UP),
                    resultPatterns.stream().limit(4).toList()
            );
        }
    }
}
