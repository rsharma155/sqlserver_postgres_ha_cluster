-- Seed data for load test databases
-- Executes all INSERTs to populate tables for realistic CRUD operations

PRINT '=== Seeding hotel_booking ===';
USE hotel_booking;

-- room_types
INSERT INTO room_types (name, description, max_occupancy, base_price, amenities) VALUES
('Standard', 'Standard room with basic amenities', 2, 120.00, 'WiFi,TV,AC'),
('Deluxe', 'Spacious room with premium amenities', 3, 200.00, 'WiFi,TV,AC,MiniBar,SeaView'),
('Suite', 'Luxury suite with separate living area', 4, 350.00, 'WiFi,TV,AC,MiniBar,Jacuzzi,SeaView,Butler'),
('Penthouse', 'Top-floor penthouse with panoramic views', 6, 600.00, 'WiFi,TV,AC,MiniBar,Jacuzzi,PanoramicView,Butler,Kitchen');

-- rooms
INSERT INTO rooms (room_number, room_type_id, floor, status) VALUES
('101', 1, 1, 'available'), ('102', 1, 1, 'available'), ('103', 1, 1, 'available'),
('201', 2, 2, 'available'), ('202', 2, 2, 'maintenance'), ('203', 2, 2, 'available'),
('301', 3, 3, 'available'), ('302', 3, 3, 'occupied'), ('303', 3, 3, 'available'),
('401', 4, 4, 'available'), ('402', 4, 4, 'available');

-- guests
INSERT INTO guests (first_name, last_name, email, phone, nationality, id_type, id_number) VALUES
('John', 'Smith', 'john.smith@email.com', '+1-555-0101', 'USA', 'passport', 'P123456'),
('Maria', 'Garcia', 'maria.garcia@email.com', '+1-555-0102', 'Mexico', 'passport', 'P123457'),
('James', 'Johnson', 'james.j@email.com', '+1-555-0103', 'USA', 'drivers_license', 'DL78901'),
('Sophie', 'Martin', 'sophie.m@email.com', '+44-555-0104', 'UK', 'passport', 'P123458'),
('Wei', 'Chen', 'wei.chen@email.com', '+86-555-0105', 'China', 'passport', 'P123459'),
('Ahmed', 'Hassan', 'ahmed.h@email.com', '+971-555-0106', 'UAE', 'passport', 'P123460'),
('Olga', 'Petrova', 'olga.p@email.com', '+7-555-0107', 'Russia', 'passport', 'P123461'),
('Carlos', 'Silva', 'carlos.s@email.com', '+55-555-0108', 'Brazil', 'passport', 'P123462');

-- reservations
INSERT INTO reservations (guest_id, check_in, check_out, status, num_guests, source) VALUES
(1, DATEADD(day, -5, GETDATE()), DATEADD(day, 2, GETDATE()), 'confirmed', 2, 'direct'),
(2, DATEADD(day, -3, GETDATE()), DATEADD(day, 4, GETDATE()), 'checked_in', 3, 'booking.com'),
(3, DATEADD(day, 1, GETDATE()), DATEADD(day, 6, GETDATE()), 'confirmed', 1, 'expedia'),
(4, DATEADD(day, 7, GETDATE()), DATEADD(day, 10, GETDATE()), 'confirmed', 2, 'direct'),
(5, DATEADD(day, -10, GETDATE()), DATEADD(day, -5, GETDATE()), 'checked_out', 4, 'booking.com'),
(6, DATEADD(day, -2, GETDATE()), DATEADD(day, 5, GETDATE()), 'checked_in', 2, 'direct'),
(1, DATEADD(day, 14, GETDATE()), DATEADD(day, 18, GETDATE()), 'confirmed', 2, 'phone'),
(7, DATEADD(day, -8, GETDATE()), DATEADD(day, -1, GETDATE()), 'checked_out', 1, 'expedia');

-- cancellations
INSERT INTO cancellations (reservation_id, reason, refund_amount) VALUES
(5, 'Change of plans', 150.00),
(8, 'Flight cancelled', 200.00);

PRINT '  hotel_booking seeded';

-- ============================================
PRINT '=== Seeding e_commerce ===';
USE e_commerce;

-- customers
INSERT INTO customers (first_name, last_name, email, phone, is_active) VALUES
('Alice', 'Williams', 'alice.w@email.com', '+1-555-0201', 1),
('Bob', 'Taylor', 'bob.t@email.com', '+1-555-0202', 1),
('Charlie', 'Brown', 'charlie.b@email.com', '+1-555-0203', 1),
('Diana', 'Prince', 'diana.p@email.com', '+1-555-0204', 1),
('Edward', 'Norton', 'edward.n@email.com', '+1-555-0205', 1);

-- categories
INSERT INTO categories (name, description, is_active) VALUES
('Electronics', 'Electronic devices and accessories', 1),
('Clothing', 'Apparel and fashion items', 1),
('Books', 'Books and publications', 1),
('Home & Garden', 'Home improvement and garden supplies', 1);

-- products
INSERT INTO products (sku, name, description, unit_price, cost_price, is_active) VALUES
('SKU-ELEC-001', 'Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 15.00, 1),
('SKU-ELEC-002', 'USB-C Hub', '7-port USB-C hub with HDMI', 49.99, 25.00, 1),
('SKU-CLOTH-001', 'Cotton T-Shirt', 'Premium cotton T-shirt', 24.99, 10.00, 1),
('SKU-CLOTH-002', 'Denim Jacket', 'Classic denim jacket', 89.99, 40.00, 1),
('SKU-BOOK-001', 'Python Programming', 'Learn Python from scratch', 39.99, 20.00, 1),
('SKU-HOME-001', 'LED Desk Lamp', 'Adjustable LED desk lamp', 34.99, 18.00, 1);

-- orders
INSERT INTO orders (customer_id, total_amount, shipping_amount, tax_amount, status, order_number) VALUES
(1, 79.98, 5.99, 6.40, 'pending', 'ORD-2024-00001'),
(2, 49.99, 0.00, 4.00, 'pending', 'ORD-2024-00002'),
(3, 114.98, 8.99, 9.20, 'shipped', 'ORD-2024-00003'),
(4, 39.99, 4.99, 3.20, 'pending', 'ORD-2024-00004'),
(5, 89.99, 0.00, 7.20, 'delivered', 'ORD-2024-00005');

PRINT '  e_commerce seeded';

-- ============================================
PRINT '=== Seeding erp_system ===';
USE erp_system;

-- companies
INSERT INTO companies (name, tax_id, address, phone, email, is_active) VALUES
('Acme Corporation', 'TAX-101-USA', '123 Main St, New York, NY', '+1-555-0301', 'info@acme.com', 1),
('Globex Inc', 'TAX-102-USA', '456 Oak Ave, San Francisco, CA', '+1-555-0302', 'info@globex.com', 1),
('Initech LLC', 'TAX-103-USA', '789 Pine Rd, Austin, TX', '+1-555-0303', 'info@initech.com', 1);

-- departments
INSERT INTO departments (company_id, name, code, budget) VALUES
(1, 'Engineering', 'ENG-01', 500000.00),
(1, 'Marketing', 'MKT-01', 200000.00),
(1, 'Finance', 'FIN-01', 150000.00),
(2, 'Engineering', 'ENG-02', 400000.00),
(2, 'Sales', 'SAL-02', 300000.00),
(3, 'Operations', 'OPS-03', 250000.00);

-- employees
INSERT INTO employees (company_id, dept_id, first_name, last_name, email, salary, status) VALUES
(1, 1, 'Frank', 'Miller', 'frank.m@acme.com', 95000.00, 'active'),
(1, 1, 'Grace', 'Lee', 'grace.l@acme.com', 85000.00, 'active'),
(1, 2, 'Henry', 'Davis', 'henry.d@acme.com', 72000.00, 'active'),
(2, 4, 'Irene', 'Wilson', 'irene.w@globex.com', 90000.00, 'active'),
(2, 5, 'Jack', 'Moore', 'jack.m@globex.com', 78000.00, 'active'),
(3, 6, 'Karen', 'White', 'karen.w@initech.com', 70000.00, 'active');

-- projects
INSERT INTO projects (company_id, name, code, description, start_date, status) VALUES
(1, 'Cloud Migration', 'PRJ-ACM-001', 'Migrate infrastructure to cloud', GETDATE(), 'active'),
(1, 'Mobile App v2', 'PRJ-ACM-002', 'Version 2 of mobile application', GETDATE(), 'planning'),
(2, 'Data Analytics', 'PRJ-GLB-001', 'Implement data analytics platform', GETDATE(), 'active'),
(3, 'ERP Upgrade', 'PRJ-INT-001', 'Upgrade ERP system to latest version', GETDATE(), 'planning');

-- journal_entries
INSERT INTO journal_entries (company_id, entry_number, entry_date, description, approved, posted) VALUES
(1, 'JE-2024-00001', GETDATE(), 'Monthly accruals', 1, 1),
(1, 'JE-2024-00002', GETDATE(), 'Payroll entry', 1, 1),
(2, 'JE-2024-00003', GETDATE(), 'Quarterly adjustment', 0, 0),
(3, 'JE-2024-00004', GETDATE(), 'Asset depreciation', 1, 0);

PRINT '  erp_system seeded';

-- ============================================
PRINT '=== Seeding hrm_tool ===';
USE hrm_tool;

-- organizations
INSERT INTO organizations (name, registration_number, address, phone, email, industry, is_active) VALUES
('TechCorp', 'REG-001-HRM', '100 Tech Blvd, Silicon Valley, CA', '+1-555-0401', 'hr@techcorp.com', 'Technology', 1),
('HealthPlus', 'REG-002-HRM', '200 Health Dr, Boston, MA', '+1-555-0402', 'hr@healthplus.com', 'Healthcare', 1);

-- departments_hrm
INSERT INTO departments_hrm (org_id, name, code, cost_center, is_active) VALUES
(1, 'Engineering', 'ENG-HRM', 'CC-1001', 1),
(1, 'Human Resources', 'HR-HRM', 'CC-1002', 1),
(2, 'Nursing', 'NRS-HRM', 'CC-2001', 1),
(2, 'Administration', 'ADM-HRM', 'CC-2002', 1);

-- employees_hrm
INSERT INTO employees_hrm (org_id, dept_id, employee_code, first_name, last_name, email, phone, hire_date, employment_type, status) VALUES
(1, 1, 'EMP-001', 'Liam', 'Anderson', 'liam.a@techcorp.com', '+1-555-0403', DATEADD(month, -24, GETDATE()), 'permanent', 'active'),
(1, 1, 'EMP-002', 'Noah', 'Thomas', 'noah.t@techcorp.com', '+1-555-0404', DATEADD(month, -12, GETDATE()), 'permanent', 'active'),
(1, 2, 'EMP-003', 'Emma', 'Jackson', 'emma.j@techcorp.com', '+1-555-0405', DATEADD(month, -36, GETDATE()), 'permanent', 'active'),
(2, 3, 'EMP-004', 'Olivia', 'Harris', 'olivia.h@healthplus.com', '+1-555-0406', DATEADD(month, -18, GETDATE()), 'permanent', 'active'),
(2, 4, 'EMP-005', 'Ava', 'Martin', 'ava.m@healthplus.com', '+1-555-0407', DATEADD(month, -6, GETDATE()), 'contract', 'active');

-- leave_policies
INSERT INTO leave_policies (org_id, policy_name, leave_type, max_days_per_year, carry_forward_limit, is_active) VALUES
(1, 'Annual Leave', 'annual', 20, 5, 1),
(1, 'Sick Leave', 'sick', 10, 0, 1),
(2, 'Annual Leave', 'annual', 25, 10, 1),
(2, 'Sick Leave', 'sick', 15, 0, 1);

-- leave_applications_hrm
INSERT INTO leave_applications_hrm (employee_id, policy_id, start_date, end_date, total_days, reason, status) VALUES
(1, 1, DATEADD(day, 14, GETDATE()), DATEADD(day, 18, GETDATE()), 5, 'Vacation', 'pending'),
(2, 1, DATEADD(day, 21, GETDATE()), DATEADD(day, 23, GETDATE()), 3, 'Personal', 'pending'),
(3, 2, DATEADD(day, -2, GETDATE()), DATEADD(day, -1, GETDATE()), 2, 'Sick', 'approved');

-- training_programs
INSERT INTO training_programs (org_id, program_name, description, trainer, duration_hours, mode, is_active) VALUES
(1, 'Leadership Workshop', 'Developing leadership skills', 'Dr. Roberts', 16, 'in_person', 1),
(1, 'AWS Cloud Practitioner', 'AWS certification prep', 'John Smith', 24, 'online', 1),
(2, 'Patient Safety', 'Healthcare safety protocols', 'Nurse Manager', 8, 'in_person', 1);

PRINT '  hrm_tool seeded';

-- ============================================
PRINT '=== Seeding department_store ===';
USE department_store;

-- stores
INSERT INTO stores (store_code, name, address, city, state, zip, phone, email, is_active) VALUES
('NYC-001', 'Downtown NYC Store', '1 Broadway, New York', 'New York', 'NY', '10004', '+1-555-0501', 'nyc01@store.com', 1),
('LA-001', 'Hollywood Store', '500 Sunset Blvd, Los Angeles', 'Los Angeles', 'CA', '90028', '+1-555-0502', 'la01@store.com', 1);

-- departments_store
INSERT INTO departments_store (store_id, name, code, budget, is_active) VALUES
(1, 'Electronics', 'DEP-ELEC', 100000.00, 1),
(1, 'Apparel', 'DEP-APP', 80000.00, 1),
(2, 'Electronics', 'DEP-ELEC2', 90000.00, 1),
(2, 'Home Goods', 'DEP-HOME', 70000.00, 1);

-- categories_store
INSERT INTO categories_store (dept_id, name, description, is_active) VALUES
(1, 'Computers', 'Laptops and desktops', 1),
(1, 'Audio', 'Headphones and speakers', 1),
(2, 'Men', 'Men apparel', 1),
(2, 'Women', 'Women apparel', 1),
(3, 'Computers', 'Computers and accessories', 1),
(4, 'Kitchen', 'Kitchen appliances', 1);

-- products_store
INSERT INTO products_store (category_id, sku, barcode, name, description, brand, unit_price, cost_price, is_active) VALUES
(1, 'STORE-SKU-001', 'BAR-001', 'Laptop Pro 15', 'High-performance laptop', 'TechBrand', 1299.99, 900.00, 1),
(1, 'STORE-SKU-002', 'BAR-002', 'Wireless Keyboard', 'Bluetooth keyboard', 'TechBrand', 79.99, 40.00, 1),
(2, 'STORE-SKU-003', 'BAR-003', 'Noise Cancelling Headphones', 'Over-ear ANC headphones', 'SoundCo', 299.99, 150.00, 1),
(3, 'STORE-SKU-004', 'BAR-004', 'Casual Shirt', 'Cotton casual shirt', 'FashionBrand', 39.99, 20.00, 1),
(5, 'STORE-SKU-005', 'BAR-005', 'USB Monitor', '27-inch 4K monitor', 'TechBrand', 449.99, 300.00, 1);

-- employees_store
INSERT INTO employees_store (store_id, dept_id, employee_code, first_name, last_name, email, role, hire_date, salary, is_active) VALUES
(1, 1, 'ST-EMP-001', 'Mike', 'Johnson', 'mike.j@store-nyc.com', 'Sales Associate', DATEADD(month, -18, GETDATE()), 42000.00, 1),
(1, 2, 'ST-EMP-002', 'Sarah', 'Williams', 'sarah.w@store-nyc.com', 'Sales Associate', DATEADD(month, -12, GETDATE()), 40000.00, 1),
(2, 3, 'ST-EMP-003', 'Tom', 'Brown', 'tom.b@store-la.com', 'Store Manager', DATEADD(month, -36, GETDATE()), 65000.00, 1),
(2, 4, 'ST-EMP-004', 'Lisa', 'Davis', 'lisa.d@store-la.com', 'Sales Associate', DATEADD(month, -6, GETDATE()), 38000.00, 1);

-- product_variants
INSERT INTO product_variants (product_id, sku, variant_name, color, size, unit_price, quantity) VALUES
(1, 'STORE-SKU-001-SILVER', 'Silver 16GB RAM', 'Silver', '15-inch', 1399.99, 10),
(1, 'STORE-SKU-001-SPACE', 'Space Gray 32GB RAM', 'Space Gray', '15-inch', 1599.99, 5),
(3, 'STORE-SKU-003-BLK', 'Black Headphones', 'Black', 'One Size', 299.99, 20),
(3, 'STORE-SKU-003-WHT', 'White Headphones', 'White', 'One Size', 299.99, 15);

-- inventory_store
INSERT INTO inventory_store (store_id, product_id, variant_id, quantity, min_quantity, max_quantity, location_code) VALUES
(1, 1, 1, 25, 5, 100, 'A-01-01'),
(1, 1, 2, 15, 5, 100, 'A-01-02'),
(1, 2, NULL, 50, 10, 200, 'A-02-01'),
(1, 3, 3, 30, 5, 100, 'A-03-01'),
(2, 5, NULL, 20, 5, 80, 'B-01-01');

-- sales_transactions
INSERT INTO sales_transactions (store_id, employee_id, subtotal, tax_amount, total_amount, payment_method, receipt_number, status) VALUES
(1, 1, 79.99, 6.40, 86.39, 'credit_card', 'RCPT-2024-00001', 'completed'),
(1, 2, 299.99, 24.00, 323.99, 'debit_card', 'RCPT-2024-00002', 'completed'),
(2, 3, 449.99, 36.00, 485.99, 'credit_card', 'RCPT-2024-00003', 'completed');

-- promotions
INSERT INTO promotions (store_id, promotion_name, description, discount_type, discount_value, min_purchase, start_date, end_date, is_active) VALUES
(1, 'Summer Sale', '20% off all electronics', 'percent', 20.00, 50.00, GETDATE(), DATEADD(day, 30, GETDATE()), 1),
(2, 'Clearance', 'Up to 50% off home goods', 'percent', 50.00, 25.00, GETDATE(), DATEADD(day, 14, GETDATE()), 1);

PRINT '  department_store seeded';

PRINT '============================================';
PRINT 'Seed data insertion complete!';
PRINT '============================================';
