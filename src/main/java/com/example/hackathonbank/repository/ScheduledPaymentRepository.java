package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.PaymentStatus;
import com.example.hackathonbank.model.ScheduledPayment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface ScheduledPaymentRepository extends JpaRepository<ScheduledPayment, Long> {

    List<ScheduledPayment> findByUserIdAndStatusInOrderByDueDateAsc(Long userId, Collection<PaymentStatus> statuses);
}
