package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.SmartCategory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SmartCategoryRepository extends JpaRepository<SmartCategory, Long> {

    List<SmartCategory> findByUserIdOrderByIdAsc(Long userId);

    long countByUserIdAndFavoriteTrue(Long userId);

    Optional<SmartCategory> findByIdAndUserId(Long id, Long userId);
}
