ALTER TABLE bank_transactions
    ADD COLUMN IF NOT EXISTS normalized_counterparty VARCHAR(255) NOT NULL DEFAULT 'unknown';

ALTER TABLE bank_transactions
    ADD COLUMN IF NOT EXISTS income_type VARCHAR(50) NOT NULL DEFAULT 'OTHER';

ALTER TABLE bank_transactions
    ADD COLUMN IF NOT EXISTS essentiality VARCHAR(50) NOT NULL DEFAULT 'UNKNOWN';

CREATE INDEX IF NOT EXISTS idx_transactions_user_status_occurred_at
    ON bank_transactions (user_id, status, occurred_at);

CREATE INDEX IF NOT EXISTS idx_transactions_user_normalized_counterparty
    ON bank_transactions (user_id, normalized_counterparty);
