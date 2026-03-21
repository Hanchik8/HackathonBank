package com.example.hackathonbank.service;

import com.example.hackathonbank.controller.dto.SmartCategoryCreateRequest;
import com.example.hackathonbank.controller.dto.SmartCategoryResponse;
import com.example.hackathonbank.model.SmartCategory;
import com.example.hackathonbank.model.Transaction;
import com.example.hackathonbank.repository.SmartCategorySpendProjection;
import com.example.hackathonbank.repository.SmartCategoryRepository;
import com.example.hackathonbank.repository.TransactionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class SmartCategoryService {

    private final SmartCategoryRepository smartCategoryRepository;
    private final TransactionRepository transactionRepository;
    private final UserContextService userContextService;
    private final UserSettingsService userSettingsService;

    public SmartCategoryService(SmartCategoryRepository smartCategoryRepository,
                                TransactionRepository transactionRepository,
                                UserContextService userContextService,
                                UserSettingsService userSettingsService) {
        this.smartCategoryRepository = smartCategoryRepository;
        this.transactionRepository = transactionRepository;
        this.userContextService = userContextService;
        this.userSettingsService = userSettingsService;
    }

    @Transactional(readOnly = true)
    public List<SmartCategoryResponse> getCategories() {
        LocalDate currentDate = userSettingsService.currentDate();
        LocalDateTime windowStart = currentDate.withDayOfMonth(1).atStartOfDay();
        LocalDateTime windowEnd = currentDate.atTime(23, 59, 59);
        Map<Long, BigDecimal> spentByCategory = loadSpentByCategory(windowStart, windowEnd);

        return smartCategoryRepository.findByUserIdOrderByIdAsc(userContextService.getCurrentUser().getId())
                .stream()
                .map(category -> toResponse(category, spentByCategory.getOrDefault(category.getId(), BigDecimal.ZERO)))
                .toList();
    }

    @Transactional
    public SmartCategoryResponse createCategory(SmartCategoryCreateRequest request) {
        SmartCategory category = smartCategoryRepository.save(
                new SmartCategory(userContextService.getCurrentUser(), request.name().trim(), request.plannedMonthly(), false)
        );
        return toResponse(category, BigDecimal.ZERO);
    }

    @Transactional
    public void setFavorite(Long categoryId, boolean favorite) {
        SmartCategory category = getOwnedCategory(categoryId);
        if (favorite && !category.isFavorite()) {
            long favoriteCount = smartCategoryRepository.countByUserIdAndFavoriteTrue(
                    userContextService.getCurrentUser().getId()
            );
            if (favoriteCount >= 3) {
                throw new IllegalArgumentException("Можно выбрать не больше трех избранных категорий.");
            }
        }
        category.setFavorite(favorite);
        smartCategoryRepository.save(category);
    }

    @Transactional
    public void deleteCategory(Long categoryId) {
        SmartCategory category = getOwnedCategory(categoryId);
        List<Transaction> linkedTransactions = transactionRepository.findByUserIdAndSmartCategoryId(
                userContextService.getCurrentUser().getId(),
                category.getId()
        );
        linkedTransactions.forEach(transaction -> transaction.setSmartCategory(null));
        transactionRepository.saveAll(linkedTransactions);
        smartCategoryRepository.delete(category);
    }

    @Transactional(readOnly = true)
    public SmartCategory getOwnedCategory(String categoryId) {
        try {
            return getOwnedCategory(Long.parseLong(categoryId));
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Некорректный идентификатор smart-категории.");
        }
    }

    @Transactional(readOnly = true)
    public SmartCategory getOwnedCategory(Long categoryId) {
        return smartCategoryRepository.findByIdAndUserId(categoryId, userContextService.getCurrentUser().getId())
                .orElseThrow(() -> new IllegalArgumentException("Smart-категория не найдена."));
    }

    @Transactional(readOnly = true)
    public BigDecimal positiveRemainingReserve(LocalDate currentDate) {
        LocalDateTime windowStart = currentDate.withDayOfMonth(1).atStartOfDay();
        LocalDateTime windowEnd = currentDate.atTime(23, 59, 59);
        Map<Long, BigDecimal> spentByCategory = loadSpentByCategory(windowStart, windowEnd);

        return smartCategoryRepository.findByUserIdOrderByIdAsc(userContextService.getCurrentUser().getId())
                .stream()
                .map(category -> toResponse(category, spentByCategory.getOrDefault(category.getId(), BigDecimal.ZERO)).remaining())
                .filter(remaining -> remaining.compareTo(BigDecimal.ZERO) > 0)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private SmartCategoryResponse toResponse(SmartCategory category, BigDecimal spent) {
        return new SmartCategoryResponse(
                category.getId(),
                category.getName(),
                category.getPlannedMonthly(),
                category.getPlannedMonthly().subtract(spent),
                category.isFavorite()
        );
    }

    private Map<Long, BigDecimal> loadSpentByCategory(LocalDateTime windowStart, LocalDateTime windowEnd) {
        return transactionRepository.sumSpentBySmartCategory(
                        userContextService.getCurrentUser().getId(),
                        windowStart,
                        windowEnd
                ).stream()
                .collect(Collectors.toMap(
                        SmartCategorySpendProjection::getSmartCategoryId,
                        projection -> projection.getSpent() == null ? BigDecimal.ZERO : projection.getSpent(),
                        BigDecimal::add
                ));
    }

    private LocalDateTime currentMonthStart() {
        LocalDate currentDate = userSettingsService.currentDate();
        return currentDate.withDayOfMonth(1).atStartOfDay();
    }

    private LocalDateTime currentMonthEnd() {
        LocalDate currentDate = userSettingsService.currentDate();
        return currentDate.atTime(23, 59, 59);
    }
}
