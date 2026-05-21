-- =====================================================
-- T-SQL Demo Databases: Hotel Booking, E-Commerce,
-- ERP System, HRM Tool, Department Store
-- =====================================================

PRINT 'Creating databases...';

IF DB_ID('hotel_booking') IS NULL CREATE DATABASE hotel_booking;
IF DB_ID('e_commerce') IS NULL CREATE DATABASE e_commerce;
IF DB_ID('erp_system') IS NULL CREATE DATABASE erp_system;
IF DB_ID('hrm_tool') IS NULL CREATE DATABASE hrm_tool;
IF DB_ID('department_store') IS NULL CREATE DATABASE department_store;
GO

-- #############################################################################
-- HOTEL BOOKING DATABASE
-- #############################################################################
USE hotel_booking;
GO
PRINT '=== Database: hotel_booking ===';

CREATE TABLE guests (
    guest_id INT IDENTITY(1,1) PRIMARY KEY, first_name NVARCHAR(50), last_name NVARCHAR(50),
    email NVARCHAR(100) UNIQUE, phone NVARCHAR(20), dob DATE,
    nationality NVARCHAR(50), id_type NVARCHAR(20), id_number NVARCHAR(50),
    address NVARCHAR(MAX), created_at DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE room_types (
    room_type_id INT IDENTITY(1,1) PRIMARY KEY, name NVARCHAR(50), description NVARCHAR(MAX),
    max_occupancy INT, base_price DECIMAL(10,2), amenities NVARCHAR(MAX)
);

CREATE TABLE rooms (
    room_id INT IDENTITY(1,1) PRIMARY KEY, room_number NVARCHAR(10) UNIQUE,
    room_type_id INT REFERENCES room_types(room_type_id), floor INT,
    status NVARCHAR(20) DEFAULT 'available', notes NVARCHAR(MAX)
);

CREATE TABLE reservations (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    check_in DATE NOT NULL, check_out DATE NOT NULL,
    status NVARCHAR(20) DEFAULT 'confirmed',
    booking_date DATETIME2 DEFAULT SYSDATETIME(), num_guests INT, special_requests NVARCHAR(MAX),
    source NVARCHAR(30) DEFAULT 'direct', cancel_reason NVARCHAR(MAX)
);

CREATE TABLE reservation_rooms (
    res_room_id INT IDENTITY(1,1) PRIMARY KEY, reservation_id INT REFERENCES reservations(reservation_id),
    room_id INT REFERENCES rooms(room_id), nightly_rate DECIMAL(10,2)
);

CREATE TABLE bookings (
    booking_id INT IDENTITY(1,1) PRIMARY KEY, reservation_id INT REFERENCES reservations(reservation_id),
    total_amount DECIMAL(12,2), paid_amount DECIMAL(12,2), balance DECIMAL(12,2),
    payment_status NVARCHAR(20) DEFAULT 'pending', booking_ref NVARCHAR(20) UNIQUE
);

CREATE TABLE payments (
    payment_id INT IDENTITY(1,1) PRIMARY KEY, booking_id INT REFERENCES bookings(booking_id),
    payment_date DATETIME2 DEFAULT SYSDATETIME(), amount DECIMAL(10,2),
    payment_method NVARCHAR(30), transaction_id NVARCHAR(100), status NVARCHAR(20) DEFAULT 'completed'
);

CREATE TABLE invoices (
    invoice_id INT IDENTITY(1,1) PRIMARY KEY, booking_id INT REFERENCES bookings(booking_id),
    invoice_number NVARCHAR(30) UNIQUE, issue_date DATE DEFAULT CAST(SYSDATETIME() AS DATE),
    due_date DATE, subtotal DECIMAL(12,2), tax DECIMAL(10,2),
    total DECIMAL(12,2), status NVARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE invoice_items (
    item_id INT IDENTITY(1,1) PRIMARY KEY, invoice_id INT REFERENCES invoices(invoice_id),
    description NVARCHAR(200), quantity INT, unit_price DECIMAL(10,2), total DECIMAL(10,2)
);

CREATE TABLE amenities (
    amenity_id INT IDENTITY(1,1) PRIMARY KEY, name NVARCHAR(50), description NVARCHAR(MAX), chargeable BIT DEFAULT 0, price DECIMAL(8,2)
);

CREATE TABLE room_amenities (
    room_amenity_id INT IDENTITY(1,1) PRIMARY KEY, room_id INT REFERENCES rooms(room_id), amenity_id INT REFERENCES amenities(amenity_id)
);

CREATE TABLE housekeeping_tasks (
    task_id INT IDENTITY(1,1) PRIMARY KEY, room_id INT REFERENCES rooms(room_id), assigned_to NVARCHAR(50),
    task_type NVARCHAR(30), status NVARCHAR(20) DEFAULT 'pending',
    scheduled_time DATETIME2, completed_time DATETIME2, notes NVARCHAR(MAX)
);

CREATE TABLE staff (
    staff_id INT IDENTITY(1,1) PRIMARY KEY, first_name NVARCHAR(50), last_name NVARCHAR(50),
    email NVARCHAR(100), phone NVARCHAR(20), role NVARCHAR(30), hire_date DATE,
    salary DECIMAL(10,2), manager_id INT REFERENCES staff(staff_id)
);

CREATE TABLE cancellations (
    cancellation_id INT IDENTITY(1,1) PRIMARY KEY, reservation_id INT REFERENCES reservations(reservation_id),
    cancel_date DATETIME2 DEFAULT SYSDATETIME(), reason NVARCHAR(MAX), refund_amount DECIMAL(10,2), processed_by NVARCHAR(50)
);

CREATE TABLE refunds (
    refund_id INT IDENTITY(1,1) PRIMARY KEY, payment_id INT REFERENCES payments(payment_id),
    refund_date DATETIME2 DEFAULT SYSDATETIME(), amount DECIMAL(10,2), reason NVARCHAR(MAX), status NVARCHAR(20)
);

CREATE TABLE reviews (
    review_id INT IDENTITY(1,1) PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    room_id INT REFERENCES rooms(room_id), rating INT CHECK(rating BETWEEN 1 AND 5),
    comment NVARCHAR(MAX), review_date DATETIME2 DEFAULT SYSDATETIME(), response NVARCHAR(MAX)
);

CREATE INDEX idx_reservations_guest ON reservations(guest_id);
CREATE INDEX idx_reservations_dates ON reservations(check_in, check_out);
CREATE INDEX idx_reservations_status ON reservations(status);
CREATE INDEX idx_bookings_payment ON bookings(payment_status);
CREATE INDEX idx_payments_booking ON payments(booking_id);
CREATE INDEX idx_invoices_booking ON invoices(booking_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_guests_email ON guests(email);
CREATE INDEX idx_reviews_guest ON reviews(guest_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_housekeeping_status ON housekeeping_tasks(status);
GO

-- #############################################################################
-- E-COMMERCE DATABASE
-- #############################################################################
USE e_commerce;
GO
PRINT '=== Database: e_commerce ===';

CREATE TABLE customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY, first_name NVARCHAR(50), last_name NVARCHAR(50),
    email NVARCHAR(100) UNIQUE, phone NVARCHAR(20), password_hash NVARCHAR(100),
    registered_at DATETIME2 DEFAULT SYSDATETIME(), is_active BIT DEFAULT 1,
    last_login DATETIME2, date_of_birth DATE, gender NVARCHAR(10)
);

CREATE TABLE categories (
    category_id INT IDENTITY(1,1) PRIMARY KEY, name NVARCHAR(100), description NVARCHAR(MAX),
    parent_category_id INT REFERENCES categories(category_id), is_active BIT DEFAULT 1,
    display_order INT DEFAULT 0
);

CREATE TABLE products (
    product_id INT IDENTITY(1,1) PRIMARY KEY, sku NVARCHAR(50) UNIQUE, name NVARCHAR(200),
    description NVARCHAR(MAX), unit_price DECIMAL(10,2), cost_price DECIMAL(10,2),
    weight DECIMAL(8,2), is_active BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT SYSDATETIME(), updated_at DATETIME2
);

CREATE TABLE product_categories (
    pc_id INT IDENTITY(1,1) PRIMARY KEY, product_id INT REFERENCES products(product_id),
    category_id INT REFERENCES categories(category_id)
);

CREATE TABLE product_reviews (
    review_id INT IDENTITY(1,1) PRIMARY KEY, product_id INT REFERENCES products(product_id),
    customer_id INT REFERENCES customers(customer_id), rating INT CHECK(rating BETWEEN 1 AND 5),
    title NVARCHAR(200), review_text NVARCHAR(MAX), is_verified BIT DEFAULT 0,
    helpful_count INT DEFAULT 0, created_at DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE inventory (
    inventory_id INT IDENTITY(1,1) PRIMARY KEY, product_id INT REFERENCES products(product_id),
    warehouse_id INT, quantity INT DEFAULT 0, reserved_quantity INT DEFAULT 0,
    reorder_level INT, reorder_quantity INT, last_updated DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    order_date DATETIME2 DEFAULT SYSDATETIME(), total_amount DECIMAL(12,2),
    shipping_amount DECIMAL(10,2), tax_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2) DEFAULT 0, status NVARCHAR(20) DEFAULT 'pending',
    payment_status NVARCHAR(20) DEFAULT 'pending', order_number NVARCHAR(30) UNIQUE
);

CREATE TABLE order_items (
    order_item_id INT IDENTITY(1,1) PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    product_id INT REFERENCES products(product_id), quantity INT,
    unit_price DECIMAL(10,2), total_price DECIMAL(12,2), discount DECIMAL(10,2) DEFAULT 0
);

CREATE TABLE order_status_history (
    history_id INT IDENTITY(1,1) PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    status NVARCHAR(20), changed_at DATETIME2 DEFAULT SYSDATETIME(), changed_by NVARCHAR(50), notes NVARCHAR(MAX)
);

CREATE TABLE shipments (
    shipment_id INT IDENTITY(1,1) PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    shipping_method_id INT, tracking_number NVARCHAR(100),
    shipped_date DATETIME2, delivered_date DATETIME2,
    carrier NVARCHAR(50), status NVARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE payment_transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    payment_method_id INT, amount DECIMAL(12,2),
    transaction_date DATETIME2 DEFAULT SYSDATETIME(), status NVARCHAR(20),
    gateway_response NVARCHAR(MAX), gateway_ref NVARCHAR(100)
);

CREATE TABLE shopping_cart (
    cart_id INT IDENTITY(1,1) PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    created_at DATETIME2 DEFAULT SYSDATETIME(), updated_at DATETIME2, is_active BIT DEFAULT 1
);

CREATE TABLE cart_items (
    cart_item_id INT IDENTITY(1,1) PRIMARY KEY, cart_id INT REFERENCES shopping_cart(cart_id),
    product_id INT REFERENCES products(product_id), quantity INT DEFAULT 1,
    added_at DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE coupons (
    coupon_id INT IDENTITY(1,1) PRIMARY KEY, code NVARCHAR(50) UNIQUE, description NVARCHAR(MAX),
    discount_type NVARCHAR(20), discount_value DECIMAL(10,2),
    min_order_amount DECIMAL(10,2), max_discount DECIMAL(10,2),
    usage_limit INT, used_count INT DEFAULT 0,
    valid_from DATE, valid_to DATE, is_active BIT DEFAULT 1
);

CREATE TABLE supplier (
    supplier_id INT IDENTITY(1,1) PRIMARY KEY, name NVARCHAR(100), contact_name NVARCHAR(50),
    email NVARCHAR(100), phone NVARCHAR(20), address NVARCHAR(MAX), payment_terms NVARCHAR(50),
    rating INT CHECK(rating BETWEEN 1 AND 5), is_active BIT DEFAULT 1
);

CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_price ON products(unit_price);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inventory_quantity ON inventory(quantity);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_reviews_product ON product_reviews(product_id);
CREATE INDEX idx_reviews_rating ON product_reviews(rating);
CREATE INDEX idx_payment_transactions_order ON payment_transactions(order_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_coupons_dates ON coupons(valid_from, valid_to);
CREATE INDEX idx_cart_customer ON shopping_cart(customer_id);
GO

-- #############################################################################
-- ERP SYSTEM DATABASE
-- #############################################################################
USE erp_system;
GO
PRINT '=== Database: erp_system ===';

CREATE TABLE companies (
    company_id INT IDENTITY(1,1) PRIMARY KEY, name NVARCHAR(200), tax_id NVARCHAR(50) UNIQUE,
    address NVARCHAR(MAX), phone NVARCHAR(20), email NVARCHAR(100), website NVARCHAR(200),
    founded_date DATE, is_active BIT DEFAULT 1
);

CREATE TABLE departments (
    dept_id INT IDENTITY(1,1) PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    name NVARCHAR(100), code NVARCHAR(20) UNIQUE, manager_id INT,
    budget DECIMAL(14,2), is_active BIT DEFAULT 1
);

CREATE TABLE employees (
    employee_id INT IDENTITY(1,1) PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    dept_id INT REFERENCES departments(dept_id),
    first_name NVARCHAR(50), last_name NVARCHAR(50), email NVARCHAR(100) UNIQUE,
    phone NVARCHAR(20), hire_date DATE, salary DECIMAL(12,2),
    status NVARCHAR(20) DEFAULT 'active', manager_id INT REFERENCES employees(employee_id)
);

CREATE TABLE projects (
    project_id INT IDENTITY(1,1) PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    name NVARCHAR(200), code NVARCHAR(30) UNIQUE, description NVARCHAR(MAX),
    start_date DATE, end_date DATE, budget DECIMAL(14,2),
    status NVARCHAR(20) DEFAULT 'planning', priority NVARCHAR(10)
);

CREATE TABLE project_tasks (
    task_id INT IDENTITY(1,1) PRIMARY KEY, project_id INT REFERENCES projects(project_id),
    parent_task_id INT REFERENCES project_tasks(task_id),
    name NVARCHAR(200), description NVARCHAR(MAX), assigned_to INT,
    start_date DATE, due_date DATE, estimated_hours DECIMAL(8,2),
    actual_hours DECIMAL(8,2) DEFAULT 0, status NVARCHAR(20) DEFAULT 'todo',
    priority NVARCHAR(10)
);

CREATE TABLE vendors (
    vendor_id INT IDENTITY(1,1) PRIMARY KEY, company_name NVARCHAR(200), contact_person NVARCHAR(50),
    email NVARCHAR(100), phone NVARCHAR(20), address NVARCHAR(MAX), tax_id NVARCHAR(50),
    payment_terms NVARCHAR(50), rating INT, is_active BIT DEFAULT 1
);

CREATE TABLE purchase_orders_erp (
    po_id INT IDENTITY(1,1) PRIMARY KEY, vendor_id INT REFERENCES vendors(vendor_id),
    po_number NVARCHAR(50) UNIQUE, order_date DATETIME2 DEFAULT SYSDATETIME(), delivery_date DATE,
    total_amount DECIMAL(14,2), status NVARCHAR(20) DEFAULT 'pending', payment_terms NVARCHAR(50)
);

CREATE TABLE journal_entries (
    je_id INT IDENTITY(1,1) PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    entry_number NVARCHAR(30) UNIQUE, entry_date DATE,
    description NVARCHAR(MAX), created_by INT, created_at DATETIME2 DEFAULT SYSDATETIME(),
    approved BIT DEFAULT 0, posted BIT DEFAULT 0
);

CREATE TABLE attendance_records (
    record_id INT IDENTITY(1,1) PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    work_date DATE, clock_in TIME, clock_out TIME,
    hours_worked DECIMAL(5,2), overtime DECIMAL(5,2) DEFAULT 0,
    status NVARCHAR(20) DEFAULT 'present'
);

CREATE INDEX idx_employees_dept ON employees(dept_id);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_project_tasks_project ON project_tasks(project_id);
CREATE INDEX idx_project_tasks_assigned ON project_tasks(assigned_to);
CREATE INDEX idx_project_tasks_status ON project_tasks(status);
CREATE INDEX idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX idx_journal_entries_company ON journal_entries(company_id);
CREATE INDEX idx_attendance_employee ON attendance_records(employee_id);
CREATE INDEX idx_attendance_date ON attendance_records(work_date);
GO

-- #############################################################################
-- HRM TOOL DATABASE
-- #############################################################################
USE hrm_tool;
GO
PRINT '=== Database: hrm_tool ===';

CREATE TABLE organizations (
    org_id INT IDENTITY(1,1) PRIMARY KEY, name NVARCHAR(200), registration_number NVARCHAR(50) UNIQUE,
    address NVARCHAR(MAX), phone NVARCHAR(20), email NVARCHAR(100), website NVARCHAR(200),
    industry NVARCHAR(100), founded_date DATE, is_active BIT DEFAULT 1
);

CREATE TABLE departments_hrm (
    dept_id INT IDENTITY(1,1) PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    name NVARCHAR(100), code NVARCHAR(20), cost_center NVARCHAR(50),
    manager_id INT, is_active BIT DEFAULT 1
);

CREATE TABLE employees_hrm (
    employee_id INT IDENTITY(1,1) PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    dept_id INT REFERENCES departments_hrm(dept_id),
    employee_code NVARCHAR(30) UNIQUE, first_name NVARCHAR(50), last_name NVARCHAR(50),
    email NVARCHAR(100) UNIQUE, phone NVARCHAR(20), date_of_birth DATE,
    gender NVARCHAR(10), hire_date DATE, exit_date DATE,
    employment_type NVARCHAR(30) DEFAULT 'permanent',
    status NVARCHAR(20) DEFAULT 'active', manager_id INT
);

CREATE TABLE leave_policies (
    policy_id INT IDENTITY(1,1) PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    policy_name NVARCHAR(100), leave_type NVARCHAR(50), max_days_per_year INT,
    carry_forward_limit INT, requires_approval BIT DEFAULT 1, is_active BIT DEFAULT 1
);

CREATE TABLE leave_applications_hrm (
    leave_id INT IDENTITY(1,1) PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    policy_id INT REFERENCES leave_policies(policy_id),
    start_date DATE, end_date DATE, total_days INT,
    reason NVARCHAR(MAX), status NVARCHAR(20) DEFAULT 'pending',
    applied_on DATETIME2 DEFAULT SYSDATETIME(), approved_by INT
);

CREATE TABLE payroll_hrm (
    payroll_id INT IDENTITY(1,1) PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    pay_period_start DATE, pay_period_end DATE, basic_pay DECIMAL(12,2),
    allowances DECIMAL(12,2), deductions DECIMAL(12,2),
    gross_pay DECIMAL(12,2), net_pay DECIMAL(12,2),
    payment_date DATE, status NVARCHAR(20)
);

CREATE TABLE performance_reviews_hrm (
    review_id INT IDENTITY(1,1) PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    reviewer_id INT, review_period NVARCHAR(30), review_date DATE,
    overall_rating INT CHECK(overall_rating BETWEEN 1 AND 5),
    summary NVARCHAR(MAX), status NVARCHAR(20) DEFAULT 'draft'
);

CREATE TABLE training_programs (
    program_id INT IDENTITY(1,1) PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    program_name NVARCHAR(200), description NVARCHAR(MAX), trainer NVARCHAR(100),
    duration_hours INT, mode NVARCHAR(30), start_date DATE, end_date DATE,
    max_participants INT, cost DECIMAL(10,2), is_active BIT DEFAULT 1
);

CREATE TABLE training_enrollments (
    enrollment_id INT IDENTITY(1,1) PRIMARY KEY, program_id INT REFERENCES training_programs(program_id),
    employee_id INT REFERENCES employees_hrm(employee_id),
    enrolled_at DATETIME2 DEFAULT SYSDATETIME(), status NVARCHAR(20) DEFAULT 'enrolled',
    completion_date DATE, score DECIMAL(5,2)
);

CREATE TABLE job_applications (
    application_id INT IDENTITY(1,1) PRIMARY KEY, applicant_name NVARCHAR(100),
    email NVARCHAR(100), phone NVARCHAR(20), status NVARCHAR(20) DEFAULT 'received',
    source NVARCHAR(30), experience_years DECIMAL(4,1)
);

CREATE TABLE grievances (
    grievance_id INT IDENTITY(1,1) PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    grievance_type NVARCHAR(50), subject NVARCHAR(200), description NVARCHAR(MAX),
    priority NVARCHAR(10), status NVARCHAR(20) DEFAULT 'open',
    created_at DATETIME2 DEFAULT SYSDATETIME(), resolved_at DATETIME2
);

CREATE INDEX idx_employees_hrm_dept ON employees_hrm(dept_id);
CREATE INDEX idx_employees_hrm_status ON employees_hrm(status);
CREATE INDEX idx_leave_applications_employee ON leave_applications_hrm(employee_id);
CREATE INDEX idx_leave_applications_status ON leave_applications_hrm(status);
CREATE INDEX idx_payroll_hrm_employee ON payroll_hrm(employee_id);
CREATE INDEX idx_performance_hrm_employee ON performance_reviews_hrm(employee_id);
CREATE INDEX idx_training_enrollments_program ON training_enrollments(program_id);
CREATE INDEX idx_training_enrollments_employee ON training_enrollments(employee_id);
CREATE INDEX idx_job_applications_status ON job_applications(status);
CREATE INDEX idx_grievances_status ON grievances(status);
GO

-- #############################################################################
-- DEPARTMENT STORE DATABASE
-- #############################################################################
USE department_store;
GO
PRINT '=== Database: department_store ===';

CREATE TABLE stores (
    store_id INT IDENTITY(1,1) PRIMARY KEY, store_code NVARCHAR(20) UNIQUE, name NVARCHAR(100),
    address NVARCHAR(MAX), city NVARCHAR(50), state NVARCHAR(50), zip NVARCHAR(20),
    phone NVARCHAR(20), email NVARCHAR(100), is_active BIT DEFAULT 1
);

CREATE TABLE departments_store (
    dept_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    name NVARCHAR(100), code NVARCHAR(20), manager_id INT,
    budget DECIMAL(14,2), is_active BIT DEFAULT 1
);

CREATE TABLE categories_store (
    category_id INT IDENTITY(1,1) PRIMARY KEY, dept_id INT REFERENCES departments_store(dept_id),
    name NVARCHAR(100), description NVARCHAR(MAX), parent_category_id INT REFERENCES categories_store(category_id),
    is_active BIT DEFAULT 1
);

CREATE TABLE products_store (
    product_id INT IDENTITY(1,1) PRIMARY KEY, category_id INT REFERENCES categories_store(category_id),
    sku NVARCHAR(50) UNIQUE, barcode NVARCHAR(50) UNIQUE, name NVARCHAR(200),
    description NVARCHAR(MAX), brand NVARCHAR(100), unit_price DECIMAL(10,2),
    cost_price DECIMAL(10,2), tax_rate DECIMAL(5,2) DEFAULT 0,
    is_active BIT DEFAULT 1, created_at DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE product_variants (
    variant_id INT IDENTITY(1,1) PRIMARY KEY, product_id INT REFERENCES products_store(product_id),
    sku NVARCHAR(50) UNIQUE, variant_name NVARCHAR(100), color NVARCHAR(30),
    size NVARCHAR(20), unit_price DECIMAL(10,2), quantity INT DEFAULT 0
);

CREATE TABLE inventory_store (
    inventory_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    product_id INT REFERENCES products_store(product_id),
    variant_id INT REFERENCES product_variants(variant_id),
    quantity INT DEFAULT 0, min_quantity INT DEFAULT 10,
    max_quantity INT DEFAULT 500, location_code NVARCHAR(30),
    last_updated DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE employees_store (
    employee_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    dept_id INT REFERENCES departments_store(dept_id),
    employee_code NVARCHAR(30) UNIQUE, first_name NVARCHAR(50), last_name NVARCHAR(50),
    email NVARCHAR(100), phone NVARCHAR(20), role NVARCHAR(30),
    hire_date DATE, salary DECIMAL(10,2), is_active BIT DEFAULT 1
);

CREATE TABLE sales_transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    customer_id INT, employee_id INT REFERENCES employees_store(employee_id),
    transaction_date DATETIME2 DEFAULT SYSDATETIME(), subtotal DECIMAL(12,2),
    tax_amount DECIMAL(10,2), discount_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(12,2), payment_method NVARCHAR(30),
    receipt_number NVARCHAR(30) UNIQUE, status NVARCHAR(20) DEFAULT 'completed'
);

CREATE TABLE sale_items (
    sale_item_id INT IDENTITY(1,1) PRIMARY KEY, transaction_id INT REFERENCES sales_transactions(transaction_id),
    product_id INT REFERENCES products_store(product_id),
    variant_id INT REFERENCES product_variants(variant_id),
    quantity INT, unit_price DECIMAL(10,2), total_price DECIMAL(12,2),
    discount DECIMAL(10,2) DEFAULT 0
);

CREATE TABLE customers_store (
    customer_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    first_name NVARCHAR(50), last_name NVARCHAR(50), email NVARCHAR(100),
    phone NVARCHAR(20), registered_at DATETIME2 DEFAULT SYSDATETIME(), is_loyalty_member BIT DEFAULT 0
);

CREATE TABLE promotions (
    promotion_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    promotion_name NVARCHAR(200), description NVARCHAR(MAX),
    discount_type NVARCHAR(20), discount_value DECIMAL(10,2),
    min_purchase DECIMAL(10,2), start_date DATETIME2, end_date DATETIME2,
    is_active BIT DEFAULT 1
);

CREATE TABLE daily_sales_summary (
    summary_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    sale_date DATE UNIQUE, total_transactions INT DEFAULT 0,
    total_sales DECIMAL(14,2) DEFAULT 0, total_tax DECIMAL(12,2) DEFAULT 0,
    total_discounts DECIMAL(12,2) DEFAULT 0
);

CREATE TABLE marketing_campaigns (
    campaign_id INT IDENTITY(1,1) PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    campaign_name NVARCHAR(200), campaign_type NVARCHAR(30),
    start_date DATE, end_date DATE, budget DECIMAL(12,2),
    description NVARCHAR(MAX), is_active BIT DEFAULT 1
);

CREATE INDEX idx_products_store_sku ON products_store(sku);
CREATE INDEX idx_products_store_barcode ON products_store(barcode);
CREATE INDEX idx_products_store_brand ON products_store(brand);
CREATE INDEX idx_products_store_price ON products_store(unit_price);
CREATE INDEX idx_sales_transactions_store ON sales_transactions(store_id);
CREATE INDEX idx_sales_transactions_date ON sales_transactions(transaction_date);
CREATE INDEX idx_sales_transactions_status ON sales_transactions(status);
CREATE INDEX idx_sale_items_transaction ON sale_items(transaction_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);
CREATE INDEX idx_inventory_store_product ON inventory_store(product_id);
CREATE INDEX idx_inventory_store_store ON inventory_store(store_id);
CREATE INDEX idx_customers_store_email ON customers_store(email);
CREATE INDEX idx_promotions_dates ON promotions(start_date, end_date);
CREATE INDEX idx_promotions_active ON promotions(is_active);
CREATE INDEX idx_daily_summary_store ON daily_sales_summary(store_id);
CREATE INDEX idx_daily_summary_date ON daily_sales_summary(sale_date);
GO

-- =====================================================
-- CRUD GENERATOR STORED PROCEDURES (per database)
-- Called by sql_runner.py instead of inline ad-hoc SQL.
-- v2: Expanded — 7+ operations per database with JOINs.
-- =====================================================

USE hotel_booking;
GO

CREATE OR ALTER PROCEDURE crud_hotel_create_reservation AS
BEGIN SET NOCOUNT ON;
    DECLARE @guest_id INT, @res_id INT;
    SELECT TOP 1 @guest_id = guest_id FROM guests ORDER BY NEWID();
    INSERT INTO reservations (guest_id, check_in, check_out, status, num_guests, source)
    SELECT @guest_id, DATEADD(DAY, CAST(RAND() * 30 AS INT) + 1, GETDATE()),
           DATEADD(DAY, CAST(RAND() * 30 AS INT) + 31, GETDATE()), 'confirmed',
           CAST(RAND() * 4 + 1 AS INT), 'load_test';
    SELECT SCOPE_IDENTITY() AS reservation_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_create_review @rating INT, @comment NVARCHAR(500) AS
BEGIN SET NOCOUNT ON;
    DECLARE @guest_id INT, @room_id INT;
    SELECT TOP 1 @guest_id = guest_id FROM guests ORDER BY NEWID();
    SELECT TOP 1 @room_id = room_id FROM rooms ORDER BY NEWID();
    INSERT INTO reviews (guest_id, room_id, rating, comment) VALUES (@guest_id, @room_id, @rating, @comment);
    SELECT SCOPE_IDENTITY() AS review_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_read_guest @guest_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT guest_id, first_name, last_name, email, nationality FROM guests WHERE guest_id = @guest_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_read_invoice @invoice_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT i.invoice_number, g.first_name + ' ' + g.last_name AS guest_name,
           i.total, i.status, ISNULL(b.paid_amount, 0) AS paid
    FROM invoices i JOIN bookings b ON i.booking_id = b.booking_id
    JOIN reservations r ON b.reservation_id = r.reservation_id
    JOIN guests g ON r.guest_id = g.guest_id
    WHERE i.invoice_id = @invoice_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_read_room @room_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT rm.room_number, rt.name AS room_type, rt.base_price, rm.floor, rm.status
    FROM rooms rm JOIN room_types rt ON rm.room_type_id = rt.room_type_id
    WHERE rm.room_id = @room_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_update_housekeeping @task_id INT, @status VARCHAR(20) AS
BEGIN SET NOCOUNT ON;
    UPDATE housekeeping_tasks SET status = @status,
        notes = ISNULL(notes, '') + ' | updated ' + CONVERT(VARCHAR, GETDATE(), 120)
    WHERE task_id = @task_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_update_reservation @res_id INT, @status VARCHAR(20) AS
BEGIN SET NOCOUNT ON;
    UPDATE reservations SET status = @status WHERE reservation_id = @res_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hotel_delete_housekeeping @task_id INT AS
BEGIN SET NOCOUNT ON;
    DELETE FROM housekeeping_tasks WHERE task_id = @task_id;
END;
GO

USE e_commerce;
GO

CREATE OR ALTER PROCEDURE crud_ecom_create_product @sku VARCHAR(50), @name VARCHAR(200), @price DECIMAL(10,2), @cost DECIMAL(10,2) AS
BEGIN SET NOCOUNT ON;
    INSERT INTO products (sku, name, description, unit_price, cost_price, is_active)
    VALUES (@sku, @name, 'Generated by load test', @price, @cost, 1);
    SELECT SCOPE_IDENTITY() AS product_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_create_order AS
BEGIN SET NOCOUNT ON;
    DECLARE @cust_id INT, @addr_id INT, @order_id INT, @prod1 INT, @prod2 INT;
    SELECT TOP 1 @cust_id = customer_id FROM customers ORDER BY NEWID();
    SELECT TOP 1 @addr_id = address_id FROM customer_addresses WHERE customer_id = @cust_id ORDER BY NEWID();
    SELECT TOP 1 @prod1 = product_id FROM products ORDER BY NEWID();
    SELECT TOP 1 @prod2 = product_id FROM products WHERE product_id != @prod1 ORDER BY NEWID();
    INSERT INTO orders (customer_id, total_amount, shipping_amount, tax_amount, status, shipping_address_id, billing_address_id, order_number)
    VALUES (@cust_id, 0, RAND() * 30, RAND() * 20, 'pending', @addr_id, @addr_id, 'ORD-LOAD-' + CAST(CAST(GETDATE() AS FLOAT) AS BIGINT));
    SET @order_id = SCOPE_IDENTITY();
    INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
    SELECT @order_id, @prod1, CAST(RAND() * 3 + 1 AS INT), unit_price, unit_price * (CAST(RAND() * 3 + 1 AS INT))
    FROM products WHERE product_id = @prod1;
    INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
    SELECT @order_id, @prod2, CAST(RAND() * 2 + 1 AS INT), unit_price, unit_price * (CAST(RAND() * 2 + 1 AS INT))
    FROM products WHERE product_id = @prod2;
    UPDATE orders SET total_amount = (SELECT SUM(total_price) FROM order_items WHERE order_id = @order_id) WHERE order_id = @order_id;
    SELECT @order_id AS order_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_read_product @product_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT pr.product_id, pr.name, pr.unit_price, ISNULL(c.name, 'Uncategorized') AS category
    FROM products pr
    LEFT JOIN product_categories pc ON pr.product_id = pc.product_id
    LEFT JOIN categories c ON pc.category_id = c.category_id
    WHERE pr.product_id = @product_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_read_order @order_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT o.order_number, c.first_name + ' ' + c.last_name AS customer,
           o.status, COUNT(oi.order_item_id) AS item_count, o.total_amount
    FROM orders o JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_id = @order_id
    GROUP BY o.order_id, c.first_name, c.last_name, o.order_number, o.status, o.total_amount;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_read_customer @customer_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT c.first_name, c.last_name, c.email,
           COUNT(DISTINCT o.order_id) AS recent_orders, ISNULL(SUM(o.total_amount), 0) AS total_spent
    FROM customers c LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE c.customer_id = @customer_id
    GROUP BY c.first_name, c.last_name, c.email;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_update_review @review_id INT AS
BEGIN SET NOCOUNT ON;
    UPDATE product_reviews SET helpful_count = helpful_count + 1 WHERE review_id = @review_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_update_order @order_id INT, @status VARCHAR(20) AS
BEGIN SET NOCOUNT ON;
    UPDATE orders SET status = @status WHERE order_id = @order_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_ecom_delete_review @review_id INT AS
BEGIN SET NOCOUNT ON;
    DELETE FROM product_reviews WHERE review_id = @review_id;
END;
GO

USE erp_system;
GO

CREATE OR ALTER PROCEDURE crud_erp_create_timesheet @employee_id INT, @task_id INT, @hours DECIMAL(5,2) AS
BEGIN SET NOCOUNT ON;
    INSERT INTO timesheets (employee_id, task_id, work_date, hours, description)
    VALUES (@employee_id, @task_id, GETDATE(), @hours, 'Load test entry');
    SELECT SCOPE_IDENTITY() AS timesheet_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_create_project @name VARCHAR(200), @budget DECIMAL(14,2) AS
BEGIN SET NOCOUNT ON;
    DECLARE @company_id INT, @project_id INT;
    SELECT TOP 1 @company_id = company_id FROM companies ORDER BY NEWID();
    INSERT INTO projects (company_id, name, code, description, budget, status)
    VALUES (@company_id, @name, 'PRJ-' + CAST(CAST(GETDATE() AS FLOAT) AS BIGINT), 'Generated by load test', @budget, 'planning');
    SET @project_id = SCOPE_IDENTITY();
    INSERT INTO project_tasks (project_id, name, description, status)
    SELECT @project_id, 'Task ' + CAST(g AS VARCHAR), 'Auto-generated task', 'pending'
    FROM (VALUES(1),(2),(3)) AS nums(g);
    SELECT @project_id AS project_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_read_employee @employee_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT employee_id, first_name, last_name, email FROM employees WHERE employee_id = @employee_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_read_employee_detail @employee_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT e.first_name, e.last_name, e.email,
           ISNULL(d.name, 'N/A') AS department, ISNULL(c.name, 'N/A') AS company, e.salary, e.status
    FROM employees e
    LEFT JOIN departments d ON e.dept_id = d.dept_id
    LEFT JOIN companies c ON e.company_id = c.company_id
    WHERE e.employee_id = @employee_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_read_project @project_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT p.name, p.status, COUNT(pt.task_id) AS task_count, p.budget
    FROM projects p LEFT JOIN project_tasks pt ON p.project_id = pt.project_id
    WHERE p.project_id = @project_id
    GROUP BY p.name, p.status, p.budget;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_update_timesheet @timesheet_id INT AS
BEGIN SET NOCOUNT ON;
    UPDATE timesheets SET approved = 1, description = ISNULL(description, '') + ' | reviewed'
    WHERE timesheet_id = @timesheet_id AND approved = 0;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_update_employee @employee_id INT, @salary DECIMAL(12,2) AS
BEGIN SET NOCOUNT ON;
    UPDATE employees SET salary = @salary WHERE employee_id = @employee_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_erp_delete_timesheet @timesheet_id INT AS
BEGIN SET NOCOUNT ON;
    DELETE FROM timesheets WHERE timesheet_id = @timesheet_id;
END;
GO

USE hrm_tool;
GO

CREATE OR ALTER PROCEDURE crud_hrm_create_enrollment @program_id INT, @employee_id INT, @status VARCHAR(20) AS
BEGIN SET NOCOUNT ON;
    INSERT INTO training_enrollments (program_id, employee_id, status) VALUES (@program_id, @employee_id, @status);
    SELECT SCOPE_IDENTITY() AS enrollment_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_create_attendance @employee_id INT, @hours DECIMAL(5,2) AS
BEGIN SET NOCOUNT ON;
    INSERT INTO attendance_records (employee_id, work_date, clock_in, clock_out, hours_worked, status)
    VALUES (@employee_id, GETDATE(), '08:00', DATEADD(HOUR, @hours, '08:00'), @hours, 'present');
    SELECT SCOPE_IDENTITY() AS record_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_read_employee @employee_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT employee_id, employee_code, first_name, last_name, email FROM employees_hrm WHERE employee_id = @employee_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_read_enrollment @enrollment_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT tp.program_name, eh.first_name + ' ' + eh.last_name AS employee_name, te.status, te.enrolled_at
    FROM training_enrollments te
    JOIN training_programs tp ON te.program_id = tp.program_id
    JOIN employees_hrm eh ON te.employee_id = eh.employee_id
    WHERE te.enrollment_id = @enrollment_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_read_organization @org_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT o.name AS org_name, COUNT(eh.employee_id) AS emp_count,
           SUM(CASE WHEN eh.status = 'active' THEN 1 ELSE 0 END) AS active_count
    FROM organizations o LEFT JOIN employees_hrm eh ON o.org_id = eh.org_id
    WHERE o.org_id = @org_id GROUP BY o.name;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_update_enrollment @enrollment_id INT, @status VARCHAR(20) AS
BEGIN SET NOCOUNT ON;
    UPDATE training_enrollments SET status = @status WHERE enrollment_id = @enrollment_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_update_employee @employee_id INT, @status VARCHAR(20) AS
BEGIN SET NOCOUNT ON;
    UPDATE employees_hrm SET status = @status WHERE employee_id = @employee_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_hrm_delete_enrollment @enrollment_id INT AS
BEGIN SET NOCOUNT ON;
    DELETE FROM training_enrollments WHERE enrollment_id = @enrollment_id;
END;
GO

USE department_store;
GO

CREATE OR ALTER PROCEDURE crud_dept_create_movement @inventory_id INT, @movement_type VARCHAR(20), @quantity INT, @ref_type VARCHAR(30) AS
BEGIN SET NOCOUNT ON;
    INSERT INTO inventory_movements (inventory_id, movement_type, quantity, reference_type, notes)
    VALUES (@inventory_id, @movement_type, @quantity, @ref_type, 'Load test movement');
    SELECT SCOPE_IDENTITY() AS movement_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_dept_read_product @product_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT product_id, name, unit_price, sku FROM products_store WHERE product_id = @product_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_dept_read_inventory @inventory_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT ps.name AS product_name, inv.quantity, ps.unit_price
    FROM inventory_store inv JOIN products_store ps ON inv.product_id = ps.product_id
    WHERE inv.inventory_id = @inventory_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_dept_read_promotion @promotion_id INT AS
BEGIN SET NOCOUNT ON;
    SELECT pr.promotion_name, s.name AS store_name, pr.discount_value, pr.is_active
    FROM promotions pr JOIN stores s ON pr.store_id = s.store_id
    WHERE pr.promotion_id = @promotion_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_dept_update_movement @movement_id INT AS
BEGIN SET NOCOUNT ON;
    UPDATE inventory_movements SET notes = ISNULL(notes, '') + ' | updated ' + CONVERT(VARCHAR, GETDATE(), 120)
    WHERE movement_id = @movement_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_dept_update_product @product_id INT, @price DECIMAL(10,2) AS
BEGIN SET NOCOUNT ON;
    UPDATE products_store SET unit_price = @price WHERE product_id = @product_id;
END;
GO

CREATE OR ALTER PROCEDURE crud_dept_delete_movement @movement_id INT AS
BEGIN SET NOCOUNT ON;
    DELETE FROM inventory_movements WHERE movement_id = @movement_id;
END;
GO

PRINT '============================================';
PRINT 'Database Creation Complete!';
PRINT '============================================';
GO
