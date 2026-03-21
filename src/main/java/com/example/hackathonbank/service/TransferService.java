package com.example.hackathonbank.service;

import com.example.hackathonbank.ai.ActionExecutionResult;
import com.example.hackathonbank.ai.AgentActionType;
import com.example.hackathonbank.controller.dto.ExternalTransferRequest;
import com.example.hackathonbank.controller.dto.ExternalTransferResponse;
import com.example.hackathonbank.controller.dto.TransferRequest;
import com.example.hackathonbank.controller.dto.TransferResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.model.SmartCategory;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import com.example.hackathonbank.model.TransactionType;
import com.example.hackathonbank.model.TransferRecipientType;
import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.AccountRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
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
    private final SmartCategoryService smartCategoryService;
    private final UserSettingsService userSettingsService;

    @Autowired
    public TransferService(AccountRepository accountRepository,
                           TransactionRepository transactionRepository,
                           AccountService accountService,
                           UserContextService userContextService,
                           SmartCategoryService smartCategoryService,
                           UserSettingsService userSettingsService) {
        this.accountRepository = accountRepository;
        this.transactionRepository = transactionRepository;
        this.accountService = accountService;
        this.userContextService = userContextService;
        this.smartCategoryService = smartCategoryService;
        this.userSettingsService = userSettingsService;
    }

    public TransferService(AccountRepository accountRepository,
                           TransactionRepository transactionRepository,
                           AccountService accountService,
                           UserContextService userContextService) {
        this(accountRepository, transactionRepository, accountService, userContextService, null, null);
    }

    @Transactional
    public TransferResponse transfer(TransferRequest request) {
        Account fromAccount = accountService.getOwnedAccount(request.fromAccountId());
        Account toAccount = accountService.getOwnedAccount(request.toAccountId());
        if (fromAccount.getId().equals(toAccount.getId())) {
            throw new IllegalArgumentException("Для перевода нужны два разных счета.");
        }

        String description = StringUtils.hasText(request.description())
                ? request.description().trim()
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
        validateExternalSourceAccount(fromAccount);
        validateAmount(fromAccount, request.amount());

        String recipientName = request.recipientName().trim();
        String description = StringUtils.hasText(request.description())
                ? request.description().trim()
                : defaultDescription(request.recipientType(), recipientName);
        String category = StringUtils.hasText(request.category())
                ? request.category().trim()
                : externalCategory(request.recipientType());
        String iconKey = StringUtils.hasText(request.iconKey())
                ? request.iconKey().trim()
                : externalIconKey(request.recipientType());
        SmartCategory smartCategory = resolveSmartCategory(request.smartCategoryId());

        fromAccount.setBalance(fromAccount.getBalance().subtract(request.amount()));
        accountRepository.save(fromAccount);

        User user = userContextService.getCurrentUser();
        transactionRepository.save(new Transaction(
                user,
                fromAccount,
                null,
                smartCategory,
                description,
                recipientName,
                request.amount().negate(),
                category,
                iconKey,
                externalTransactionType(request.recipientType()),
                TransactionStatus.COMPLETED,
                currentDateTime()
        ));

        return new ExternalTransferResponse(
                externalSuccessMessage(request.recipientType(), recipientName, request.amount()),
                accountService.toResponse(fromAccount),
                request.recipientType().name(),
                recipientName,
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
        LocalDateTime now = currentDateTime();

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

    private SmartCategory resolveSmartCategory(String smartCategoryId) {
        if (!StringUtils.hasText(smartCategoryId) || smartCategoryService == null) {
            return null;
        }
        return smartCategoryService.getOwnedCategory(smartCategoryId.trim());
    }

    private void validateExternalSourceAccount(Account fromAccount) {
        if (fromAccount.getType() == AccountType.SAVINGS) {
            throw new IllegalArgumentException("Переводы с накопительного депозита недоступны.");
        }
    }

    private LocalDateTime currentDateTime() {
        if (userSettingsService == null) {
            return LocalDateTime.now().withSecond(0).withNano(0);
        }
        return userSettingsService.currentDate().atTime(12, 0);
    }

    private String defaultDescription(TransferRecipientType recipientType, String recipientName) {
        return switch (recipientType) {
            case USER -> "Перевод пользователю %s".formatted(recipientName);
            case MERCHANT -> "Оплата магазину %s".formatted(recipientName);
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
            case USER -> "Перевод пользователю %s на %s KGS выполнен.".formatted(recipientName, amount.toPlainString());
            case MERCHANT -> "Оплата магазину %s на %s KGS выполнена.".formatted(recipientName, amount.toPlainString());
        };
    }
}
