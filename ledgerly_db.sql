-- ==============================
-- EXTENSIONS
-- ==============================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================
-- ENUMS
-- ==============================
CREATE TYPE user_role AS ENUM ('ADMIN', 'STAFF');

CREATE TYPE invoice_status AS ENUM ('DRAFT', 'SENT', 'PAID', 'OVERDUE');

CREATE TYPE payment_method AS ENUM ('CARD', 'UPI', 'BANK');

CREATE TYPE payment_status AS ENUM ('SUCCESS', 'FAILED');

CREATE TYPE subscription_status AS ENUM ('ACTIVE', 'CANCELLED', 'EXPIRED');

CREATE TYPE insight_severity AS ENUM ('LOW', 'MEDIUM', 'HIGH');

-- ==============================
-- TABLE: subscription_plans
-- ==============================
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    max_invoices INT,
    max_users INT,
    features JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==============================
-- TABLE: tenants
-- ==============================
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255),
    subscription_plan_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_tenant_plan
        FOREIGN KEY (subscription_plan_id)
        REFERENCES subscription_plans(id)
        ON DELETE SET NULL
);

-- ==============================
-- TABLE: users
-- ==============================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    name VARCHAR(255),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'STAFF',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_user_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: customers
-- ==============================
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_customer_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: invoices
-- ==============================
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    invoice_number VARCHAR(100) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    status invoice_status DEFAULT 'DRAFT',
    total_amount DECIMAL(12,2) NOT NULL,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_invoice_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_invoice_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: invoice_items
-- ==============================
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL,
    description TEXT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12,2) NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,

    CONSTRAINT fk_item_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES invoices(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: payments
-- ==============================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    invoice_id UUID NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    payment_method payment_method,
    payment_status payment_status DEFAULT 'SUCCESS',
    transaction_id VARCHAR(255),
    paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payment_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_payment_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES invoices(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: revenue_metrics
-- ==============================
CREATE TABLE revenue_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    month DATE NOT NULL,
    total_revenue DECIMAL(12,2) DEFAULT 0,
    total_invoices INT DEFAULT 0,
    paid_invoices INT DEFAULT 0,
    overdue_invoices INT DEFAULT 0,

    CONSTRAINT fk_metrics_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: ai_insights
-- ==============================
CREATE TABLE ai_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    insight_type VARCHAR(100),
    message TEXT,
    severity insight_severity,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ai_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: subscriptions
-- ==============================
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID UNIQUE NOT NULL,
    plan_id UUID NOT NULL,
    status subscription_status DEFAULT 'ACTIVE',
    start_date DATE,
    end_date DATE,

    CONSTRAINT fk_subscription_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_subscription_plan
        FOREIGN KEY (plan_id)
        REFERENCES subscription_plans(id)
        ON DELETE CASCADE
);

-- ==============================
-- TABLE: api_keys
-- ==============================
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    key_value TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_apikey_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE
);

-- ==============================
-- INDEXES 
-- ==============================

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_customers_tenant ON customers(tenant_id);
CREATE INDEX idx_invoices_tenant ON invoices(tenant_id);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_metrics_tenant_month ON revenue_metrics(tenant_id, month);
CREATE INDEX idx_ai_tenant ON ai_insights(tenant_id);

-- ==============================
-- SAMPLE DATA (OPTIONAL)
-- ==============================

INSERT INTO subscription_plans (name, price, max_invoices, max_users)
VALUES 
('FREE', 0, 50, 2),
('PRO', 999, 1000, 10),
('ENTERPRISE', 4999, NULL, NULL);
