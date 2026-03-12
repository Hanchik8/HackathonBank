package com.example.hackathonbank.service;

import com.example.hackathonbank.controller.dto.AccountResponse;
import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import com.example.hackathonbank.repository.AccountRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional(readOnly = true)
public class AccountService {

    private final AccountRepository accountRepository;
    private final UserContextService userContextService;

    public AccountService(AccountRepository accountRepository, UserContextService userContextService) {
        this.accountRepository = accountRepository;
        this.userContextService = userContextService;
    }

    public List<AccountResponse> getAccounts() {
        return accountRepository.findByUserIdOrderByTypeAsc(userContextService.getCurrentUser().getId())
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public Account getAccountByType(AccountType type) {
        return accountRepository.findByUserIdAndType(userContextService.getCurrentUser().getId(), type)
                .orElseThrow(() -> new IllegalStateException("Счет типа %s не найден.".formatted(type)));
    }

    public Account getOwnedAccount(Long accountId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Счет %d не найден.".formatted(accountId)));
        if (!account.getUser().getId().equals(userContextService.getCurrentUser().getId())) {
            throw new IllegalArgumentException("Счет недоступен текущему пользователю.");
        }
        return account;
    }

    public AccountResponse toResponse(Account account) {
        return new AccountResponse(
                account.getId(),
                account.getName(),
                account.getType().name(),
                account.getBalance(),
                account.getCurrency()
        );
    }
}
