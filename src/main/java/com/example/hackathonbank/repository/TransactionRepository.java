package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.model.TransactionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    List<Transaction> findByUserIdOrderByOccurredAtDesc(Long userId);

    List<Transaction> findByUserIdAndStatusAndOccurredAtBetweenOrderByOccurredAtDesc(Long userId,
                                                                                     TransactionStatus status,
                                                                                     LocalDateTime windowStart,
                                                                                     LocalDateTime windowEnd);

    List<Transaction> findByUserIdAndSmartCategoryId(Long userId, Long smartCategoryId);

    Optional<Transaction> findByScheduledPaymentId(Long scheduledPaymentId);

    @Query("""
            select t.smartCategory.id as smartCategoryId,
                   coalesce(sum(abs(t.amount)), 0) as spent
            from Transaction t
            where t.user.id = :userId
              and t.smartCategory is not null
              and t.status = com.example.hackathonbank.model.TransactionStatus.COMPLETED
              and t.amount < 0
              and t.occurredAt between :windowStart and :windowEnd
            group by t.smartCategory.id
            """)
    List<SmartCategorySpendProjection> sumSpentBySmartCategory(@Param("userId") Long userId,
                                                               @Param("windowStart") LocalDateTime windowStart,
                                                               @Param("windowEnd") LocalDateTime windowEnd);
}
