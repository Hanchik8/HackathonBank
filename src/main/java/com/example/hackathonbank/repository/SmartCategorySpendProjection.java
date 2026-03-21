package com.example.hackathonbank.repository;

import java.math.BigDecimal;

public interface SmartCategorySpendProjection {

    Long getSmartCategoryId();

    BigDecimal getSpent();
}
