package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AccountRepository extends JpaRepository<Account, Long> {

    List<Account> findByUserIdOrderByTypeAsc(Long userId);

    Optional<Account> findByUserIdAndType(Long userId, AccountType type);
}
