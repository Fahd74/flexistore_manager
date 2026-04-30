CREATE DATABASE IF NOT EXISTS flexistore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE flexistore;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'cashier','manager') NOT NULL DEFAULT 'cashier',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    total_debt DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    barcode VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    purchase_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    selling_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    stock_quantity INT NOT NULL DEFAULT 0,
    status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS invoices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT DEFAULT NULL,
    user_id INT NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    net_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_type ENUM(
        'cash',
        'installment',
        'return'
    ) NOT NULL DEFAULT 'cash',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_invoices_client FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    CONSTRAINT fk_invoices_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS invoice_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    CONSTRAINT fk_items_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS installments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    invoice_id INT NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    remaining_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    months INT NOT NULL DEFAULT 1,
    monthly_installment DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    status ENUM(
        'active',
        'completed',
        'cancelled'
    ) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_inst_client FOREIGN KEY (client_id) REFERENCES clients (id),
    CONSTRAINT fk_inst_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS installment_payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    installment_id INT NOT NULL,
    user_id INT NOT NULL,
    amount_paid DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_inst FOREIGN KEY (installment_id) REFERENCES installments (id) ON DELETE CASCADE,
    CONSTRAINT fk_payment_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS inventory_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    user_id INT NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    quantity_changed INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_invlog_product FOREIGN KEY (product_id) REFERENCES products (id),
    CONSTRAINT fk_invlog_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS transaction_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_txlog_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

USE flexistore;
ALTER TABLE users MODIFY COLUMN role ENUM('admin', 'cashier', 'manager') NOT NULL DEFAULT 'cashier';
INSERT INTO users (name, username, password_hash, role) VALUES 
('System Admin', 'admin1', 'admin123', 'admin'),
('Cashier One', 'cashier1', '123456', 'cashier'),
('Inventory Manager', 'store_mng', 'store123', 'manager');
INSERT IGNORE INTO users (id, name, username, password_hash, role) 
VALUES (1, 'Admin', 'admin1', 'admin123', 'admin');

-- 2. Add Clients
INSERT INTO clients (name, phone, total_debt) VALUES 
('Sarah Smith', '+1 555-001', 800.00),
('David Brown', '+1 555-002', 1600.00),
('Emma Wilson', '+1 555-003', 150.00),
('Mike Johnson', '+1 555-006', 0.00);

-- 3. Add Placeholder Products (to link to invoices if needed)
INSERT INTO products (barcode, name, selling_price, stock_quantity, status) VALUES
('P001', 'iPhone 14 Pro', 1200.00, 50, 'active'),
('P002', 'MacBook Air M2', 3200.00, 20, 'active'),
('P003', 'iPad Pro', 450.00, 30, 'active'),
('P004', 'Samsung Galaxy S23', 900.00, 40, 'active');

-- 4. Create Invoices
-- Sarah Smith (iPhone 14 Pro)
INSERT INTO invoices (client_id, user_id, total_amount, payment_type) VALUES 
(1, 1, 1200.00, 'installments');
SET @inv1 = LAST_INSERT_ID();

-- David Brown (MacBook Air M2)
INSERT INTO invoices (client_id, user_id, total_amount, payment_type) VALUES 
(2, 1, 3200.00, 'installments');
SET @inv2 = LAST_INSERT_ID();

-- Emma Wilson (iPad Pro)
INSERT INTO invoices (client_id, user_id, total_amount, payment_type) VALUES 
(3, 1, 450.00, 'installments');
SET @inv3 = LAST_INSERT_ID();

-- Mike Johnson (Samsung Galaxy S23)
INSERT INTO invoices (client_id, user_id, total_amount, payment_type) VALUES 
(4, 1, 900.00, 'installments');
SET @inv4 = LAST_INSERT_ID();

-- 5. Create Installment Plans
-- Sarah Smith: $1200 total, $400 paid, $800 remaining, $200 monthly, 6 months
INSERT INTO installments (client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment, status) VALUES
(1, @inv1, 1200.00, 800.00, 6, 200.00, 'active');
SET @inst1 = LAST_INSERT_ID();

-- David Brown: $3200 total, $1600 paid, $1600 remaining, $400 monthly, 8 months
INSERT INTO installments (client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment, status) VALUES
(2, @inv2, 3200.00, 1600.00, 8, 400.00, 'active');
SET @inst2 = LAST_INSERT_ID();

-- Emma Wilson: $450 total, $300 paid, $150 remaining, $150 monthly, 3 months
INSERT INTO installments (client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment, status) VALUES
(3, @inv3, 450.00, 150.00, 3, 150.00, 'active');
SET @inst3 = LAST_INSERT_ID();

-- Mike Johnson: $900 total, $900 paid, $0 remaining, $300 monthly, 3 months
INSERT INTO installments (client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment, status) VALUES
(4, @inv4, 900.00, 0.00, 3, 300.00, 'completed');
SET @inst4 = LAST_INSERT_ID();

-- 6. Add Payment History (to match 'Paid' amounts)
INSERT INTO installment_payments (installment_id, user_id, amount_paid, payment_date) VALUES
(@inst1, 1, 200.00, '2026-03-15 10:00:00'),
(@inst1, 1, 200.00, '2026-04-15 10:00:00'),
(@inst2, 1, 400.00, '2026-01-10 10:00:00'),
(@inst2, 1, 400.00, '2026-02-10 10:00:00'),
(@inst2, 1, 400.00, '2026-03-10 10:00:00'),
(@inst2, 1, 400.00, '2026-04-10 10:00:00'),
(@inst3, 1, 150.00, '2026-02-08 10:00:00'),
(@inst3, 1, 150.00, '2026-03-08 10:00:00'),
(@inst4, 1, 300.00, '2026-01-01 10:00:00'),
(@inst4, 1, 300.00, '2026-02-01 10:00:00'),
(@inst4, 1, 300.00, '2026-03-01 10:00:00');
