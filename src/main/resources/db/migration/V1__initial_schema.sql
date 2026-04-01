-- Initial schema for HackathonBank
-- This migration is provided for future use when switching from H2 ddl-auto to a managed database.
-- Enable Flyway by setting spring.flyway.enabled=true and spring.jpa.hibernate.ddl-auto=validate.

CREATE TABLE IF NOT EXISTS bank_users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS user_settings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    smart_list_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    admin_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    auto_daily_save_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    effective_date DATE,
    CONSTRAINT fk_user_settings_user FOREIGN KEY (user_id) REFERENCES bank_users(id)
);

CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    balance DECIMAL(19,2) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'KGS',
    CONSTRAINT fk_accounts_user FOREIGN KEY (user_id) REFERENCES bank_users(id)
);

CREATE TABLE IF NOT EXISTS smart_categories (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    planned_monthly DECIMAL(19,2) NOT NULL DEFAULT 0,
    favorite BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_smart_categories_user FOREIGN KEY (user_id) REFERENCES bank_users(id)
);

CREATE TABLE IF NOT EXISTS scheduled_payments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    counterparty VARCHAR(255),
    category VARCHAR(255),
    icon_key VARCHAR(100),
    amount DECIMAL(19,2) NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'SCHEDULED',
    reminder BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_scheduled_payments_user FOREIGN KEY (user_id) REFERENCES bank_users(id),
    CONSTRAINT fk_scheduled_payments_account FOREIGN KEY (account_id) REFERENCES accounts(id)
);

CREATE TABLE IF NOT EXISTS bank_transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    scheduled_payment_id BIGINT,
    smart_category_id BIGINT,
    title VARCHAR(255) NOT NULL,
    counterparty VARCHAR(255),
    amount DECIMAL(19,2) NOT NULL,
    category VARCHAR(255),
    icon_key VARCHAR(100),
    type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED',
    occurred_at TIMESTAMP NOT NULL,
    CONSTRAINT fk_transactions_user FOREIGN KEY (user_id) REFERENCES bank_users(id),
    CONSTRAINT fk_transactions_account FOREIGN KEY (account_id) REFERENCES accounts(id),
    CONSTRAINT fk_transactions_payment FOREIGN KEY (scheduled_payment_id) REFERENCES scheduled_payments(id),
    CONSTRAINT fk_transactions_smart_category FOREIGN KEY (smart_category_id) REFERENCES smart_categories(id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    role VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_chat_messages_user FOREIGN KEY (user_id) REFERENCES bank_users(id)
);
