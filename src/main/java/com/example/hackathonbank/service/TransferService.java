package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.ai.AgentActionType;
import com.example.hackathonbank.controller.dto.ExternalTransferRequest;
import com.example.hackathonbank.controller.dto.ExternalTransferResponse;
import com.example.hackathonbank.controller.dto.TransferRequest;
import com.example.hackathonbank.controller.dto.TransferResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.TransferRecipientType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class TransferService {

    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;
    private final AccountService accountService;
    private final UserContextService userContextService;

    public TransferService(AccountRepository accountRepository,
                           TransactionRepository transactionRepository,
                           AccountService accountService,
                           UserContextService userContextService) {
        this.accountRepository = accountRepository;
        this.transactionRepository = transactionRepository;
        this.accountService = accountService;
        this.userContextService = userContextService;
    }

    @Transactional
    public TransferResponse transfer(TransferRequest request) {
        Account fromAccount = accountService.getOwnedAccount(request.fromAccountId());
        Account toAccount = accountService.getOwnedAccount(request.toAccountId());
        if (fromAccount.getId().equals(toAccount.getId())) {
            throw new IllegalArgumentException("Для перевода нужны два разных счета.");
        }

        String description = StringUtils.hasText(request.description())
                ? request.description()
                : "Внутренний перевод";
        executeTransfer(fromAccount, toAccount, request.amount(), description);

        return new TransferResponse(
                "Перевод выполнен.",
                accountService.toResponse(fromAccount),
                accountService.toResponse(toAccount)
        );
    }

    @Transactional
    public ExternalTransferResponse transferExternal(ExternalTransferRequest request) {
        Account fromAccount = accountService.getOwnedAccount(request.fromAccountId());
        validateAmount(fromAccount, request.amount());

        String description = StringUtils.hasText(request.description())
                ? request.description()
                : defaultDescription(request.recipientType(), request.recipientName());

        fromAccount.setBalance(fromAccount.getBalance().subtract(request.amount()));
        accountRepository.save(fromAccount);

        User user = userContextService.getCurrentUser();
        LocalDateTime now = LocalDateTime.now().withSecond(0).withNano(0);
        transactionRepository.save(new Transaction(
                user,
                fromAccount,
                null,
                description,
                request.recipientName().trim(),
                request.amount().negate(),
                externalCategory(request.recipientType()),
                externalIconKey(request.recipientType()),
                externalTransactionType(request.recipientType()),
                TransactionStatus.COMPLETED,
                now
        ));

        return new ExternalTransferResponse(
                externalSuccessMessage(request.recipientType(), request.recipientName(), request.amount()),
                accountService.toResponse(fromAccount),
                request.recipientType().name(),
                request.recipientName().trim(),
                request.amount()
        );
    }

    @Transactional
    public ActionExecutionResult autoTransferFromSavings(BigDecimal amount) {
        Account savings = accountService.getAccountByType(AccountType.SAVINGS);
        Account main = accountService.getAccountByType(AccountType.MAIN);
        executeTransfer(savings, main, amount, "AI резерв");

        return new ActionExecutionResult(
                AgentActionType.AUTO_TRANSFER.name(),
                "Со счета сбережений переведено %s KGS, чтобы закрыть кассовый разрыв.".formatted(amount.toPlainString()),
                main.getBalance(),
                savings.getBalance()
        );
    }

    private void executeTransfer(Account fromAccount, Account toAccount, BigDecimal amount, String description) {
        validateAmount(fromAccount, amount);

        fromAccount.setBalance(fromAccount.getBalance().subtract(amount));
        toAccount.setBalance(toAccount.getBalance().add(amount));
        accountRepository.saveAll(List.of(fromAccount, toAccount));

        User user = userContextService.getCurrentUser();
        LocalDateTime now = LocalDateTime.now().withSecond(0).withNano(0);

        Transaction debit = new Transaction(
                user,
                fromAccount,
                null,
                description,
                toAccount.getName(),
                amount.negate(),
                "Переводы",
                "transfer",
                TransactionType.TRANSFER,
                TransactionStatus.COMPLETED,
                now
        );
        Transaction credit = new Transaction(
                user,
                toAccount,
                null,
                description,
                fromAccount.getName(),
                amount,
                "Переводы",
                "transfer",
                TransactionType.TRANSFER,
                TransactionStatus.COMPLETED,
                now.plusSeconds(1)
        );
        transactionRepository.saveAll(List.of(debit, credit));
    }

    private void validateAmount(Account fromAccount, BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Сумма перевода должна быть положительной.");
        }
        if (fromAccount.getBalance().compareTo(amount) < 0) {
            throw new IllegalArgumentException("Недостаточно средств на счете \"%s\".".formatted(fromAccount.getName()));
        }
    }

    private String defaultDescription(TransferRecipientType recipientType, String recipientName) {
        return switch (recipientType) {
            case USER -> "Перевод пользователю %s".formatted(recipientName.trim());
            case MERCHANT -> "Оплата магазину %s".formatted(recipientName.trim());
        };
    }

    private String externalCategory(TransferRecipientType recipientType) {
        return switch (recipientType) {
            case USER -> "Переводы";
            case MERCHANT -> "Покупки";
        };
    }

    private String externalIconKey(TransferRecipientType recipientType) {
        return switch (recipientType) {
            case USER -> "transfer";
            case MERCHANT -> "shopping";
        };
    }

    private TransactionType externalTransactionType(TransferRecipientType recipientType) {
        return switch (recipientType) {
            case USER -> TransactionType.TRANSFER;
            case MERCHANT -> TransactionType.PURCHASE;
        };
    }

    private String externalSuccessMessage(TransferRecipientType recipientType, String recipientName, BigDecimal amount) {
        return switch (recipientType) {
            case USER -> "Перевод пользователю %s на %s KGS выполнен.".formatted(recipientName.trim(), amount.toPlainString());
            case MERCHANT -> "Оплата магазину %s на %s KGS выполнена.".formatted(recipientName.trim(), amount.toPlainString());
        };
    }
}
