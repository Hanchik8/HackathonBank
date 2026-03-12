package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    List<Transaction> findByUserIdOrderByOccurredAtDesc(Long userId);

    Optional<Transaction> findByScheduledPaymentId(Long scheduledPaymentId);
}
