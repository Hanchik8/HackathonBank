package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.Account;
import com.example.hackathonbank.model.AccountType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface AccountRepository extends JpaRepository<Account, Long> {

    @Query("SELECT a FROM Account a WHERE a.user.id = :userId ORDER BY a.type ASC")
    List<Account> findByUserIdOrderByTypeAsc(Long userId);

    @Query("SELECT a FROM Account a WHERE a.user.id = :userId AND a.type = :type")
    Optional<Account> findByUserIdAndType(Long userId, AccountType type);
}
