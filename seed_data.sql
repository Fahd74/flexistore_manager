-- Seed data based on the provided UI screenshots
-- This script clears existing data and populates it with everything from the mock-up screens.

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE installment_payments;
TRUNCATE TABLE installments;
TRUNCATE TABLE invoice_items;
TRUNCATE TABLE invoices;
TRUNCATE TABLE products;
TRUNCATE TABLE clients;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. Ensure a user exists for logging transactions
INSERT IGNORE INTO users (id, name, username, password_hash, role) 
VALUES (1, 'Admin', 'admin1', 'admin123', 'admin');

-- 2. Add Clients
INSERT INTO clients (id, name, phone, total_debt) VALUES 
(1, 'Sarah Smith',  '+1 555-001', 800.00),
(2, 'David Brown',  '+1 555-002', 1600.00),
(3, 'Emma Wilson',  '+1 555-003', 150.00),
(4, 'Mike Johnson', '+1 555-006', 0.00),
(5, 'John Doe',     '+1 555-007', 350.00);

-- 3. Add Products from POS Screenshot
INSERT INTO products (id, barcode, name, selling_price, stock_quantity, status) VALUES
(1,  'SAM-GS24-128', 'Samsung Galaxy S24',   999.99,  15, 'active'),
(2,  'APL-MBA-M2',   'MacBook Air M2',      1299.99,  8,  'active'),
(3,  'APL-APP-2',    'AirPods Pro',         249.99,   24, 'active'),
(4,  'APL-IPP-129',  'iPad Pro 12.9',       1099.99, 12, 'active'),
(5,  'APL-AWU-2',    'Apple Watch Ultra',   799.99,  10, 'active'),
(6,  'APL-MK-US',    'Magic Keyboard',      349.99,  18, 'active'),
(7,  'SAM-GS23-256', 'Samsung Galaxy S23',   899.99,  20, 'active'),
(8,  'SNY-WH-1000',  'Sony WH-1000XM5',     399.99,  14, 'active'),
(9,  'LOG-MXM-3',    'Logitech MX Master 3', 99.99,   32, 'active'),
(10, 'DEL-US-27',    'Dell UltraSharp Monitor', 549.99, 7, 'active');

-- 4. Create Invoices for existing installments
INSERT INTO invoices (id, client_id, user_id, total_amount, payment_type) VALUES 
(1, 1, 1, 1200.00, 'installment'),
(2, 2, 1, 3200.00, 'installment'),
(3, 3, 1, 450.00,  'installment'),
(4, 4, 1, 900.00,  'installment'),
(5, 5, 1, 350.00,  'installment');

-- 5. Create Installment Plans
INSERT INTO installments (id, client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment, status) VALUES
(1, 1, 1, 1200.00, 800.00, 6, 200.00, 'active'),
(2, 2, 2, 3200.00, 1600.00, 8, 400.00, 'active'),
(3, 3, 3, 450.00,  150.00, 3, 150.00, 'active'),
(4, 4, 4, 900.00,  0.00, 3, 300.00, 'completed'),
(5, 5, 5, 350.00,  350.00, 1, 350.00, 'active');

-- 6. Add Payment History
INSERT INTO installment_payments (installment_id, user_id, amount_paid, payment_date) VALUES
(1, 1, 200.00, '2026-03-15 10:00:00'),
(1, 1, 200.00, '2026-04-15 10:00:00'),
(2, 1, 400.00, '2026-01-10 10:00:00'),
(2, 1, 400.00, '2026-02-10 10:00:00'),
(2, 1, 400.00, '2026-03-10 10:00:00'),
(2, 1, 400.00, '2026-04-10 10:00:00'),
(3, 1, 150.00, '2026-02-08 10:00:00'),
(3, 1, 150.00, '2026-03-08 10:00:00'),
(4, 1, 300.00, '2026-01-01 10:00:00'),
(4, 1, 300.00, '2026-02-01 10:00:00'),
(4, 1, 300.00, '2026-03-01 10:00:00');
