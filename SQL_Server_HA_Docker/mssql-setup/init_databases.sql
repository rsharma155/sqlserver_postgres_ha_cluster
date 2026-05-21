-- =====================================================
-- PostgreSQL Demo Databases: Hotel Booking, E-Commerce,
-- ERP System, HRM Tool, Department Store
-- Run via: psql -U postgres -f init_databases.sql
-- =====================================================

\c postgres

SELECT 'Creating databases...';

CREATE DATABASE hotel_booking;
CREATE DATABASE e_commerce;
CREATE DATABASE erp_system;
CREATE DATABASE hrm_tool;
CREATE DATABASE department_store;

-- #############################################################################
-- HOTEL BOOKING DATABASE
-- #############################################################################
\echo '=== Database: hotel_booking ==='
\c hotel_booking

SELECT 'Creating hotel_booking tables...';

CREATE TABLE IF NOT EXISTS guests (
    guest_id SERIAL PRIMARY KEY, first_name VARCHAR(50), last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE, phone VARCHAR(20), dob DATE,
    nationality VARCHAR(50), id_type VARCHAR(20), id_number VARCHAR(50),
    address TEXT, created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS guest_contacts (
    contact_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    contact_type VARCHAR(20), contact_value VARCHAR(100), is_primary BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS guest_documents (
    doc_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    doc_type VARCHAR(30), doc_number VARCHAR(50), expiry_date DATE, verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS room_types (
    room_type_id SERIAL PRIMARY KEY, name VARCHAR(50), description TEXT,
    max_occupancy INT, base_price NUMERIC(10,2), amenities TEXT
);

CREATE TABLE IF NOT EXISTS rooms (
    room_id SERIAL PRIMARY KEY, room_number VARCHAR(10) UNIQUE,
    room_type_id INT REFERENCES room_types(room_type_id), floor INT,
    status VARCHAR(20) DEFAULT 'available', notes TEXT
);

CREATE TABLE IF NOT EXISTS room_rates (
    rate_id SERIAL PRIMARY KEY, room_type_id INT REFERENCES room_types(room_type_id),
    rate_name VARCHAR(50), rate_amount NUMERIC(10,2), valid_from DATE, valid_to DATE
);

CREATE TABLE IF NOT EXISTS seasonal_rates (
    seasonal_rate_id SERIAL PRIMARY KEY, room_type_id INT REFERENCES room_types(room_type_id),
    season_name VARCHAR(50), start_date DATE, end_date DATE, multiplier NUMERIC(4,2) DEFAULT 1.0
);

CREATE TABLE IF NOT EXISTS reservations (
    reservation_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    check_in DATE NOT NULL, check_out DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'confirmed',
    booking_date TIMESTAMP DEFAULT NOW(), num_guests INT, special_requests TEXT,
    source VARCHAR(30) DEFAULT 'direct', cancel_reason TEXT
);

CREATE TABLE IF NOT EXISTS reservation_rooms (
    res_room_id SERIAL PRIMARY KEY, reservation_id INT REFERENCES reservations(reservation_id),
    room_id INT REFERENCES rooms(room_id), nightly_rate NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS bookings (
    booking_id SERIAL PRIMARY KEY, reservation_id INT REFERENCES reservations(reservation_id),
    total_amount NUMERIC(12,2), paid_amount NUMERIC(12,2), balance NUMERIC(12,2),
    payment_status VARCHAR(20) DEFAULT 'pending', booking_ref VARCHAR(20) UNIQUE
);

CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY, booking_id INT REFERENCES bookings(booking_id),
    payment_date TIMESTAMP DEFAULT NOW(), amount NUMERIC(10,2),
    payment_method VARCHAR(30), transaction_id VARCHAR(100), status VARCHAR(20) DEFAULT 'completed'
);

CREATE TABLE IF NOT EXISTS invoices (
    invoice_id SERIAL PRIMARY KEY, booking_id INT REFERENCES bookings(booking_id),
    invoice_number VARCHAR(30) UNIQUE, issue_date DATE DEFAULT CURRENT_DATE,
    due_date DATE, subtotal NUMERIC(12,2), tax NUMERIC(10,2),
    total NUMERIC(12,2), status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS invoice_items (
    item_id SERIAL PRIMARY KEY, invoice_id INT REFERENCES invoices(invoice_id),
    description VARCHAR(200), quantity INT, unit_price NUMERIC(10,2), total NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS amenities (
    amenity_id SERIAL PRIMARY KEY, name VARCHAR(50), description TEXT, chargeable BOOLEAN DEFAULT FALSE, price NUMERIC(8,2)
);

CREATE TABLE IF NOT EXISTS room_amenities (
    room_amenity_id SERIAL PRIMARY KEY, room_id INT REFERENCES rooms(room_id), amenity_id INT REFERENCES amenities(amenity_id)
);

CREATE TABLE IF NOT EXISTS housekeeping_tasks (
    task_id SERIAL PRIMARY KEY, room_id INT REFERENCES rooms(room_id), assigned_to VARCHAR(50),
    task_type VARCHAR(30), status VARCHAR(20) DEFAULT 'pending',
    scheduled_time TIMESTAMP, completed_time TIMESTAMP, notes TEXT
);

CREATE TABLE IF NOT EXISTS maintenance_requests (
    request_id SERIAL PRIMARY KEY, room_id INT REFERENCES rooms(room_id),
    reported_by VARCHAR(50), issue_description TEXT, priority VARCHAR(10),
    status VARCHAR(20) DEFAULT 'open', created_at TIMESTAMP DEFAULT NOW(), resolved_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staff (
    staff_id SERIAL PRIMARY KEY, first_name VARCHAR(50), last_name VARCHAR(50),
    email VARCHAR(100), phone VARCHAR(20), role VARCHAR(30), hire_date DATE,
    salary NUMERIC(10,2), manager_id INT REFERENCES staff(staff_id)
);

CREATE TABLE IF NOT EXISTS staff_roles (
    role_id SERIAL PRIMARY KEY, role_name VARCHAR(50), description TEXT,
    department VARCHAR(50), hourly_rate NUMERIC(8,2)
);

CREATE TABLE IF NOT EXISTS staff_schedules (
    schedule_id SERIAL PRIMARY KEY, staff_id INT REFERENCES staff(staff_id),
    shift_date DATE, start_time TIME, end_time TIME, role VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS reviews (
    review_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    room_id INT REFERENCES rooms(room_id), rating INT CHECK(rating BETWEEN 1 AND 5),
    comment TEXT, review_date TIMESTAMP DEFAULT NOW(), response TEXT
);

CREATE TABLE IF NOT EXISTS loyalty_program (
    program_id SERIAL PRIMARY KEY, program_name VARCHAR(50), tier VARCHAR(20),
    min_points INT, discount_percent NUMERIC(4,2), benefits TEXT
);

CREATE TABLE IF NOT EXISTS loyalty_points (
    points_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    program_id INT REFERENCES loyalty_program(program_id),
    points_earned INT DEFAULT 0, points_redeemed INT DEFAULT 0, tier VARCHAR(20) DEFAULT 'silver'
);

CREATE TABLE IF NOT EXISTS cancellations (
    cancellation_id SERIAL PRIMARY KEY, reservation_id INT REFERENCES reservations(reservation_id),
    cancel_date TIMESTAMP DEFAULT NOW(), reason TEXT, refund_amount NUMERIC(10,2), processed_by VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS refunds (
    refund_id SERIAL PRIMARY KEY, payment_id INT REFERENCES payments(payment_id),
    refund_date TIMESTAMP DEFAULT NOW(), amount NUMERIC(10,2), reason TEXT, status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id SERIAL PRIMARY KEY, name VARCHAR(100), contact_person VARCHAR(50),
    phone VARCHAR(20), email VARCHAR(100), address TEXT, supply_type VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS inventory_items (
    item_id SERIAL PRIMARY KEY, supplier_id INT REFERENCES suppliers(supplier_id),
    item_name VARCHAR(100), category VARCHAR(50), quantity INT, reorder_level INT,
    unit_price NUMERIC(10,2), last_restocked TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    po_id SERIAL PRIMARY KEY, supplier_id INT REFERENCES suppliers(supplier_id),
    order_date TIMESTAMP DEFAULT NOW(), expected_delivery DATE,
    status VARCHAR(20), total_amount NUMERIC(12,2), approved_by VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    poi_id SERIAL PRIMARY KEY, po_id INT REFERENCES purchase_orders(po_id),
    item_id INT REFERENCES inventory_items(item_id), quantity INT, unit_price NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS conference_rooms (
    conf_room_id SERIAL PRIMARY KEY, name VARCHAR(50), capacity INT,
    equipment TEXT, hourly_rate NUMERIC(10,2), available BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS conference_bookings (
    conf_booking_id SERIAL PRIMARY KEY, conf_room_id INT REFERENCES conference_rooms(conf_room_id),
    guest_id INT REFERENCES guests(guest_id), booking_date DATE,
    start_time TIME, end_time TIME, total_cost NUMERIC(10,2), status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS parking_spots (
    spot_id SERIAL PRIMARY KEY, spot_number VARCHAR(10) UNIQUE, location VARCHAR(50),
    spot_type VARCHAR(20), is_available BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS parking_reservations (
    parking_res_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    spot_id INT REFERENCES parking_spots(spot_id), entry_time TIMESTAMP,
    exit_time TIMESTAMP, fee NUMERIC(8,2), status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS feedback (
    feedback_id SERIAL PRIMARY KEY, guest_id INT REFERENCES guests(guest_id),
    category VARCHAR(30), rating INT CHECK(rating BETWEEN 1 AND 5),
    comments TEXT, submitted_at TIMESTAMP DEFAULT NOW(), resolved BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS lost_and_found (
    item_id SERIAL PRIMARY KEY, description TEXT, found_location VARCHAR(50),
    found_by VARCHAR(50), found_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'unclaimed', claimed_by INT REFERENCES guests(guest_id), claimed_at TIMESTAMP
);

SELECT 'Inserting hotel_booking data...';

DO $data$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM room_types LIMIT 1) THEN
        INSERT INTO room_types (name, description, max_occupancy, base_price, amenities) VALUES
        ('Standard Room', 'Basic room with essential amenities', 2, 120.00, 'WiFi,TV,AC'),
        ('Deluxe Room', 'Spacious room with city view', 3, 200.00, 'WiFi,TV,AC,MiniBar'),
        ('Suite', 'Premium suite with separate living area', 4, 350.00, 'WiFi,TV,AC,MiniBar,Jacuzzi'),
        ('Penthouse', 'Top floor luxury penthouse', 6, 800.00, 'WiFi,TV,AC,MiniBar,Jacuzzi,Butler'),
        ('Family Room', 'Large room for families', 5, 280.00, 'WiFi,TV,AC,Kitchenette'),
        ('Single', 'Compact room for solo travelers', 1, 80.00, 'WiFi,TV');
        
        INSERT INTO rooms (room_number, room_type_id, floor, status)
        SELECT 'R' || LPAD(g::text, 3, '0'), (random() * 5 + 1)::int, (random() * 4 + 1)::int,
               CASE WHEN random() < 0.8 THEN 'available' ELSE 'occupied' END
        FROM generate_series(1, 100) g;
        
        INSERT INTO amenities (name, description, chargeable, price) VALUES
        ('WiFi', 'High-speed wireless internet', FALSE, 0), ('Breakfast', 'Continental breakfast', TRUE, 25),
        ('Airport Transfer', 'Shuttle service', TRUE, 50), ('Spa Access', 'Full spa facilities', TRUE, 80),
        ('Gym', 'Fitness center access', FALSE, 0), ('Pool', 'Swimming pool access', FALSE, 0),
        ('Laundry', 'Laundry service', TRUE, 30), ('Mini Bar', 'In-room mini bar', TRUE, 45),
        ('Room Service', '24/7 room service', TRUE, 20), ('Parking', 'Valet parking', TRUE, 35);
        
        INSERT INTO guests (first_name, last_name, email, phone, nationality, address)
        SELECT
            (ARRAY['John','Jane','Robert','Maria','David','Sarah','Michael','Emma','James','Linda','William','Susan','Richard','Karen','Joseph','Nancy','Thomas','Lisa','Charles','Betty'])[floor(random() * 20 + 1)],
            (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'])[floor(random() * 20 + 1)],
            'guest' || g || '@email.com',
            '555-' || LPAD((random() * 999999)::int::text, 6, '0'),
            (ARRAY['USA','UK','Canada','Australia','Germany','France','India','Brazil','Japan','Mexico'])[floor(random() * 10 + 1)],
            (ARRAY['123 Main St','456 Oak Ave','789 Pine Rd','321 Elm Dr','654 Maple Ln'])[floor(random() * 5 + 1)]
        FROM generate_series(1, 50000) g;
        
        INSERT INTO reservations (guest_id, check_in, check_out, status, num_guests, source)
        SELECT
            (random() * 49999 + 1)::int,
            CURRENT_DATE - (random() * 365)::int,
            CURRENT_DATE - (random() * 365)::int + (random() * 10 + 1)::int,
            (ARRAY['confirmed','checked_in','checked_out','cancelled'])[floor(random() * 4 + 1)],
            (random() * 4 + 1)::int,
            (ARRAY['direct','booking.com','expedia','agoda','phone'])[floor(random() * 5 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO bookings (reservation_id, total_amount, paid_amount, balance, payment_status, booking_ref)
        SELECT
            g, (random() * 2000 + 100)::numeric(12,2), (random() * 1000)::numeric(12,2),
            ((random() * 2000 + 100) - (random() * 1000))::numeric(12,2),
            (ARRAY['pending','partial','paid','refunded'])[floor(random() * 4 + 1)],
            'BK-' || LPAD(g::text, 6, '0')
        FROM generate_series(1, 100000) g
        ON CONFLICT (booking_ref) DO NOTHING;
        
        INSERT INTO payments (booking_id, amount, payment_method, status)
        SELECT
            (random() * 99999 + 1)::int, (random() * 1000 + 50)::numeric(10,2),
            (ARRAY['credit_card','debit_card','cash','bank_transfer','paypal'])[floor(random() * 5 + 1)],
            (ARRAY['completed','pending','failed','refunded'])[floor(random() * 4 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO invoices (booking_id, invoice_number, issue_date, due_date, subtotal, tax, total, status)
        SELECT
            (random() * 99999 + 1)::int,
            'INV-' || LPAD(g::text, 6, '0'),
            CURRENT_DATE - (random() * 180)::int,
            CURRENT_DATE - (random() * 180)::int + 30,
            (random() * 2000 + 100)::numeric(12,2),
            (random() * 200)::numeric(10,2),
            ((random() * 2000 + 100) + (random() * 200))::numeric(12,2),
            (ARRAY['pending','paid','overdue','cancelled'])[floor(random() * 4 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO reviews (guest_id, room_id, rating, comment)
        SELECT
            (random() * 49999 + 1)::int, (random() * 99 + 1)::int,
            (random() * 4 + 1)::int,
            (ARRAY['Great stay!','Room was clean.','Needs improvement.','Wonderful experience.',
                   'Average service.','Excellent view.','Will return!','Okay for the price.',
                   'Beautiful hotel.','Staff was friendly.'])[floor(random() * 10 + 1)]
        FROM generate_series(1, 30000) g;
        
        INSERT INTO housekeeping_tasks (room_id, assigned_to, task_type, status)
        SELECT
            (random() * 99 + 1)::int,
            (ARRAY['Alice','Bob','Charlie','Diana','Eve','Frank','Grace'])[floor(random() * 7 + 1)],
            (ARRAY['cleaning','linen_change','deep_clean','turndown','inspection'])[floor(random() * 5 + 1)],
            (ARRAY['pending','in_progress','completed'])[floor(random() * 3 + 1)]
        FROM generate_series(1, 30000) g;
    END IF;
END $data$;

CREATE INDEX IF NOT EXISTS idx_reservations_guest ON reservations(guest_id);
CREATE INDEX IF NOT EXISTS idx_reservations_dates ON reservations(check_in, check_out);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_bookings_payment ON bookings(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_invoices_booking ON invoices(booking_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms(status);
CREATE INDEX IF NOT EXISTS idx_guests_email ON guests(email);
CREATE INDEX IF NOT EXISTS idx_reviews_guest ON reviews(guest_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_housekeeping_status ON housekeeping_tasks(status);
CREATE INDEX IF NOT EXISTS idx_housekeeping_room ON housekeeping_tasks(room_id);
CREATE INDEX IF NOT EXISTS idx_parking_status ON parking_reservations(status);

-- #############################################################################
-- E-COMMERCE DATABASE
-- #############################################################################
\echo '=== Database: e_commerce ==='
\c e_commerce

SELECT 'Creating e_commerce tables...';

CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY, first_name VARCHAR(50), last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE, phone VARCHAR(20), password_hash VARCHAR(100),
    registered_at TIMESTAMP DEFAULT NOW(), is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP, date_of_birth DATE, gender VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    address_id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    address_type VARCHAR(20), address_line1 VARCHAR(200), address_line2 VARCHAR(200),
    city VARCHAR(50), state VARCHAR(50), zip_code VARCHAR(20), country VARCHAR(50),
    is_default BOOLEAN DEFAULT FALSE, phone VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS categories (
    category_id SERIAL PRIMARY KEY, name VARCHAR(100), description TEXT,
    parent_category_id INT REFERENCES categories(category_id), is_active BOOLEAN DEFAULT TRUE,
    display_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY, sku VARCHAR(50) UNIQUE, name VARCHAR(200),
    description TEXT, unit_price NUMERIC(10,2), cost_price NUMERIC(10,2),
    weight NUMERIC(8,2), is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(), updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_categories (
    pc_id SERIAL PRIMARY KEY, product_id INT REFERENCES products(product_id),
    category_id INT REFERENCES categories(category_id)
);

CREATE TABLE IF NOT EXISTS product_images (
    image_id SERIAL PRIMARY KEY, product_id INT REFERENCES products(product_id),
    image_url VARCHAR(500), is_primary BOOLEAN DEFAULT FALSE, sort_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS product_reviews (
    review_id SERIAL PRIMARY KEY, product_id INT REFERENCES products(product_id),
    customer_id INT REFERENCES customers(customer_id), rating INT CHECK(rating BETWEEN 1 AND 5),
    title VARCHAR(200), review_text TEXT, is_verified BOOLEAN DEFAULT FALSE,
    helpful_count INT DEFAULT 0, created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_attributes (
    attr_id SERIAL PRIMARY KEY, attr_name VARCHAR(50), attr_type VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS attribute_values (
    attr_value_id SERIAL PRIMARY KEY, attr_id INT REFERENCES product_attributes(attr_id),
    value VARCHAR(100), display_order INT
);

CREATE TABLE IF NOT EXISTS product_variant_attributes (
    pva_id SERIAL PRIMARY KEY, product_id INT REFERENCES products(product_id),
    attr_value_id INT REFERENCES attribute_values(attr_value_id)
);

CREATE TABLE IF NOT EXISTS inventory (
    inventory_id SERIAL PRIMARY KEY, product_id INT REFERENCES products(product_id),
    warehouse_id INT, quantity INT DEFAULT 0, reserved_quantity INT DEFAULT 0,
    reorder_level INT, reorder_quantity INT, last_updated TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id SERIAL PRIMARY KEY, name VARCHAR(100), contact_name VARCHAR(50),
    email VARCHAR(100), phone VARCHAR(20), address TEXT, payment_terms VARCHAR(50),
    rating INT CHECK(rating BETWEEN 1 AND 5), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    po_id SERIAL PRIMARY KEY, supplier_id INT REFERENCES suppliers(supplier_id),
    order_date TIMESTAMP DEFAULT NOW(), expected_date DATE,
    status VARCHAR(20) DEFAULT 'pending', total_amount NUMERIC(12,2),
    notes TEXT, created_by VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    poi_id SERIAL PRIMARY KEY, po_id INT REFERENCES purchase_orders(po_id),
    product_id INT REFERENCES products(product_id), quantity INT,
    unit_cost NUMERIC(10,2), total_cost NUMERIC(12,2)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    order_date TIMESTAMP DEFAULT NOW(), total_amount NUMERIC(12,2),
    shipping_amount NUMERIC(10,2), tax_amount NUMERIC(10,2),
    discount_amount NUMERIC(10,2) DEFAULT 0, status VARCHAR(20) DEFAULT 'pending',
    shipping_address_id INT REFERENCES customer_addresses(address_id),
    billing_address_id INT REFERENCES customer_addresses(address_id),
    payment_status VARCHAR(20) DEFAULT 'pending', order_number VARCHAR(30) UNIQUE
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    product_id INT REFERENCES products(product_id), quantity INT,
    unit_price NUMERIC(10,2), total_price NUMERIC(12,2), discount NUMERIC(10,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS order_status_history (
    history_id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    status VARCHAR(20), changed_at TIMESTAMP DEFAULT NOW(), changed_by VARCHAR(50), notes TEXT
);

CREATE TABLE IF NOT EXISTS shipments (
    shipment_id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    shipping_method_id INT, tracking_number VARCHAR(100),
    shipped_date TIMESTAMP, delivered_date TIMESTAMP,
    carrier VARCHAR(50), status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS shipment_items (
    si_id SERIAL PRIMARY KEY, shipment_id INT REFERENCES shipments(shipment_id),
    order_item_id INT REFERENCES order_items(order_item_id), quantity INT
);

CREATE TABLE IF NOT EXISTS payment_transactions (
    transaction_id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    payment_method_id INT, amount NUMERIC(12,2),
    transaction_date TIMESTAMP DEFAULT NOW(), status VARCHAR(20),
    gateway_response TEXT, gateway_ref VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS payment_methods (
    payment_method_id SERIAL PRIMARY KEY, method_name VARCHAR(50),
    provider VARCHAR(50), is_active BOOLEAN DEFAULT TRUE, processing_fee NUMERIC(4,2)
);

CREATE TABLE IF NOT EXISTS shopping_cart (
    cart_id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    created_at TIMESTAMP DEFAULT NOW(), updated_at TIMESTAMP, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS cart_items (
    cart_item_id SERIAL PRIMARY KEY, cart_id INT REFERENCES shopping_cart(cart_id),
    product_id INT REFERENCES products(product_id), quantity INT DEFAULT 1,
    added_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wishlist (
    wishlist_id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    name VARCHAR(100) DEFAULT 'My Wishlist', created_at TIMESTAMP DEFAULT NOW(), is_public BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS wishlist_items (
    wi_id SERIAL PRIMARY KEY, wishlist_id INT REFERENCES wishlist(wishlist_id),
    product_id INT REFERENCES products(product_id), added_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS coupons (
    coupon_id SERIAL PRIMARY KEY, code VARCHAR(50) UNIQUE, description TEXT,
    discount_type VARCHAR(20), discount_value NUMERIC(10,2),
    min_order_amount NUMERIC(10,2), max_discount NUMERIC(10,2),
    usage_limit INT, used_count INT DEFAULT 0,
    valid_from DATE, valid_to DATE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS coupon_usage (
    usage_id SERIAL PRIMARY KEY, coupon_id INT REFERENCES coupons(coupon_id),
    customer_id INT REFERENCES customers(customer_id), order_id INT REFERENCES orders(order_id),
    used_at TIMESTAMP DEFAULT NOW(), discount_applied NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS returns (
    return_id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(order_id),
    customer_id INT REFERENCES customers(customer_id),
    return_date TIMESTAMP DEFAULT NOW(), reason TEXT,
    status VARCHAR(20) DEFAULT 'requested', rma_number VARCHAR(30) UNIQUE
);

CREATE TABLE IF NOT EXISTS return_items (
    ri_id SERIAL PRIMARY KEY, return_id INT REFERENCES returns(return_id),
    order_item_id INT REFERENCES order_items(order_item_id), quantity INT,
    condition VARCHAR(30), refund_amount NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS refunds (
    refund_id SERIAL PRIMARY KEY, return_id INT REFERENCES returns(return_id),
    transaction_id INT REFERENCES payment_transactions(transaction_id),
    refund_date TIMESTAMP DEFAULT NOW(), amount NUMERIC(12,2),
    reason TEXT, status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS shipping_methods (
    shipping_method_id SERIAL PRIMARY KEY, name VARCHAR(50),
    estimated_days_min INT, estimated_days_max INT, base_cost NUMERIC(10,2),
    cost_per_kg NUMERIC(8,2), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS tax_rates (
    tax_rate_id SERIAL PRIMARY KEY, country VARCHAR(50), state VARCHAR(50),
    tax_name VARCHAR(50), rate NUMERIC(5,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS newsletter_subscribers (
    subscriber_id SERIAL PRIMARY KEY, email VARCHAR(100) UNIQUE,
    subscribed_at TIMESTAMP DEFAULT NOW(), is_active BOOLEAN DEFAULT TRUE,
    unsubscribe_token VARCHAR(100), source VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS customer_support_tickets (
    ticket_id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(customer_id),
    subject VARCHAR(200), description TEXT, priority VARCHAR(10),
    status VARCHAR(20) DEFAULT 'open', created_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP, assigned_to VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS ticket_messages (
    message_id SERIAL PRIMARY KEY, ticket_id INT REFERENCES customer_support_tickets(ticket_id),
    sender_type VARCHAR(10), message_text TEXT, sent_at TIMESTAMP DEFAULT NOW(),
    attachment_url VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS gift_cards (
    gift_card_id SERIAL PRIMARY KEY, code VARCHAR(50) UNIQUE,
    initial_balance NUMERIC(10,2), current_balance NUMERIC(10,2),
    issued_to_email VARCHAR(100), issued_at TIMESTAMP DEFAULT NOW(),
    expires_at DATE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS gift_card_transactions (
    gct_id SERIAL PRIMARY KEY, gift_card_id INT REFERENCES gift_cards(gift_card_id),
    order_id INT REFERENCES orders(order_id), amount NUMERIC(10,2),
    transaction_type VARCHAR(10), created_at TIMESTAMP DEFAULT NOW()
);

SELECT 'Inserting e_commerce data...';

DO $data$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM categories LIMIT 1) THEN
        INSERT INTO categories (name, description, display_order) VALUES
        ('Electronics','Electronic devices and accessories',1),('Clothing','Apparel and fashion',2),
        ('Books','Books and publications',3),('Home & Garden','Home improvement and garden',4),
        ('Sports','Sports equipment and gear',5),('Toys','Toys and games',6),
        ('Automotive','Car parts and accessories',7),('Health','Health and wellness',8),
        ('Food','Food and beverages',9),('Office','Office supplies',10);
        
        INSERT INTO products (sku, name, description, unit_price, cost_price, weight)
        SELECT
            'SKU-' || LPAD(g::text, 6, '0'),
            'Product ' || g,
            'Description for product ' || g,
            (random() * 500 + 5)::numeric(10,2),
            (random() * 300 + 2)::numeric(10,2),
            (random() * 20 + 0.1)::numeric(8,2)
        FROM generate_series(1, 50000) g;
        
        INSERT INTO product_categories (product_id, category_id)
        SELECT g, (random() * 9 + 1)::int FROM generate_series(1, 50000) g;
        
        INSERT INTO inventory (product_id, warehouse_id, quantity, reorder_level, reorder_quantity)
        SELECT g, (random() * 4 + 1)::int, (random() * 1000)::int, (random() * 50)::int, (random() * 200 + 50)::int
        FROM generate_series(1, 50000) g;
        
        INSERT INTO customers (first_name, last_name, email, phone, registered_at, is_active)
        SELECT
            (ARRAY['Alice','Bob','Carol','Dan','Eve','Frank','Grace','Henry','Iris','Jack'])[floor(random() * 10 + 1)],
            (ARRAY['Cooper','Diaz','Lee','Patel','Kim','Brown','Wang','Chen','Gupta','Ali'])[floor(random() * 10 + 1)],
            'cust' || g || '@domain.com',
            '555-' || LPAD((random() * 999999)::int::text, 6, '0'),
            NOW() - (random() * 365 * 2 || ' days')::interval,
            random() < 0.9
        FROM generate_series(1, 50000) g;
        
        INSERT INTO orders (customer_id, total_amount, shipping_amount, tax_amount, discount_amount, status, payment_status, order_number)
        SELECT
            (random() * 49999 + 1)::int,
            (random() * 500 + 10)::numeric(12,2),
            (random() * 30)::numeric(10,2),
            (random() * 50)::numeric(10,2),
            (random() * 20)::numeric(10,2)::int::numeric(10,2),
            (ARRAY['pending','processing','shipped','delivered','cancelled'])[floor(random() * 5 + 1)],
            (ARRAY['pending','paid','refunded'])[floor(random() * 3 + 1)],
            'ORD-' || LPAD(g::text, 8, '0')
        FROM generate_series(1, 100000) g;
        
        INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
        SELECT
            (random() * 99999 + 1)::int,
            (random() * 49999 + 1)::int,
            (random() * 5 + 1)::int,
            (random() * 200 + 10)::numeric(10,2),
            ((random() * 200 + 10) * (random() * 5 + 1))::numeric(12,2)
        FROM generate_series(1, 200000) g;
        
        INSERT INTO product_reviews (product_id, customer_id, rating, title, review_text)
        SELECT
            (random() * 49999 + 1)::int, (random() * 49999 + 1)::int,
            (random() * 4 + 1)::int,
            (ARRAY['Great product','Not bad','Excellent','Poor quality','Average'])[floor(random() * 5 + 1)],
            (ARRAY['Highly recommended!','Does the job.','Could be better.','Perfect!','Not what I expected.','Good value.','Amazing quality.','Works as described.'])[floor(random() * 8 + 1)]
        FROM generate_series(1, 50000) g;
        
        INSERT INTO payment_transactions (order_id, amount, status, gateway_ref)
        SELECT
            (random() * 99999 + 1)::int,
            (random() * 500 + 10)::numeric(12,2),
            (ARRAY['completed','pending','failed','refunded'])[floor(random() * 4 + 1)],
            'TXN-' || LPAD(g::text, 10, '0')
        FROM generate_series(1, 100000) g;
    END IF;
END $data$;

CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(unit_price);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_quantity ON inventory(quantity);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON product_reviews(rating);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order ON payment_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_dates ON coupons(valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_gift_cards_code ON gift_cards(code);
CREATE INDEX IF NOT EXISTS idx_cart_customer ON shopping_cart(customer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_customer ON customer_support_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON customer_support_tickets(status);

-- #############################################################################
-- ERP SYSTEM DATABASE
-- #############################################################################
\echo '=== Database: erp_system ==='
\c erp_system

SELECT 'Creating erp_system tables...';

CREATE TABLE IF NOT EXISTS companies (
    company_id SERIAL PRIMARY KEY, name VARCHAR(200), tax_id VARCHAR(50) UNIQUE,
    address TEXT, phone VARCHAR(20), email VARCHAR(100), website VARCHAR(200),
    founded_date DATE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS departments (
    dept_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    name VARCHAR(100), code VARCHAR(20) UNIQUE, manager_id INT,
    budget NUMERIC(14,2), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS positions (
    position_id SERIAL PRIMARY KEY, dept_id INT REFERENCES departments(dept_id),
    title VARCHAR(100), description TEXT, min_salary NUMERIC(12,2),
    max_salary NUMERIC(12,2), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS employees (
    employee_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    dept_id INT REFERENCES departments(dept_id), position_id INT REFERENCES positions(position_id),
    first_name VARCHAR(50), last_name VARCHAR(50), email VARCHAR(100) UNIQUE,
    phone VARCHAR(20), hire_date DATE, salary NUMERIC(12,2),
    status VARCHAR(20) DEFAULT 'active', manager_id INT REFERENCES employees(employee_id)
);

CREATE TABLE IF NOT EXISTS employee_documents (
    doc_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    doc_type VARCHAR(30), doc_name VARCHAR(100), file_path VARCHAR(500),
    uploaded_at TIMESTAMP DEFAULT NOW(), verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS job_applicants (
    applicant_id SERIAL PRIMARY KEY, position_id INT REFERENCES positions(position_id),
    first_name VARCHAR(50), last_name VARCHAR(50), email VARCHAR(100),
    phone VARCHAR(20), resume_path VARCHAR(500), status VARCHAR(20),
    applied_at TIMESTAMP DEFAULT NOW(), rating INT
);

CREATE TABLE IF NOT EXISTS payroll (
    payroll_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    pay_period_start DATE, pay_period_end DATE, gross_pay NUMERIC(12,2),
    deductions NUMERIC(12,2), net_pay NUMERIC(12,2),
    payment_date DATE, status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS payroll_items (
    pi_id SERIAL PRIMARY KEY, payroll_id INT REFERENCES payroll(payroll_id),
    item_type VARCHAR(30), description VARCHAR(200), amount NUMERIC(12,2)
);

CREATE TABLE IF NOT EXISTS attendance_records (
    record_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    work_date DATE, clock_in TIME, clock_out TIME,
    hours_worked NUMERIC(5,2), overtime NUMERIC(5,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'present'
);

CREATE TABLE IF NOT EXISTS leave_types (
    leave_type_id SERIAL PRIMARY KEY, name VARCHAR(50), description TEXT,
    max_days INT, is_paid BOOLEAN DEFAULT TRUE, carry_forward BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS leave_requests (
    leave_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    leave_type_id INT REFERENCES leave_types(leave_type_id),
    start_date DATE, end_date DATE, total_days INT,
    reason TEXT, status VARCHAR(20) DEFAULT 'pending',
    approved_by INT, created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
    project_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    name VARCHAR(200), code VARCHAR(30) UNIQUE, description TEXT,
    start_date DATE, end_date DATE, budget NUMERIC(14,2),
    status VARCHAR(20) DEFAULT 'planning', priority VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS project_tasks (
    task_id SERIAL PRIMARY KEY, project_id INT REFERENCES projects(project_id),
    parent_task_id INT REFERENCES project_tasks(task_id),
    name VARCHAR(200), description TEXT, assigned_to INT,
    start_date DATE, due_date DATE, estimated_hours NUMERIC(8,2),
    actual_hours NUMERIC(8,2) DEFAULT 0, status VARCHAR(20) DEFAULT 'todo',
    priority VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS task_assignments (
    assignment_id SERIAL PRIMARY KEY, task_id INT REFERENCES project_tasks(task_id),
    employee_id INT REFERENCES employees(employee_id),
    assigned_at TIMESTAMP DEFAULT NOW(), role VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS project_milestones (
    milestone_id SERIAL PRIMARY KEY, project_id INT REFERENCES projects(project_id),
    name VARCHAR(200), description TEXT, due_date DATE,
    status VARCHAR(20) DEFAULT 'pending', completion_percent INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS timesheets (
    timesheet_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    task_id INT REFERENCES project_tasks(task_id), work_date DATE,
    hours NUMERIC(5,2), description TEXT, approved BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS expense_categories (
    expense_cat_id SERIAL PRIMARY KEY, name VARCHAR(100), description TEXT,
    budget_limit NUMERIC(12,2), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS expenses (
    expense_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees(employee_id),
    expense_cat_id INT REFERENCES expense_categories(expense_cat_id),
    project_id INT REFERENCES projects(project_id), amount NUMERIC(12,2),
    expense_date DATE, description TEXT, receipt_path VARCHAR(500),
    status VARCHAR(20) DEFAULT 'pending', approved_by INT, approved_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vendors (
    vendor_id SERIAL PRIMARY KEY, company_name VARCHAR(200), contact_person VARCHAR(50),
    email VARCHAR(100), phone VARCHAR(20), address TEXT, tax_id VARCHAR(50),
    payment_terms VARCHAR(50), rating INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS vendor_contracts (
    contract_id SERIAL PRIMARY KEY, vendor_id INT REFERENCES vendors(vendor_id),
    contract_number VARCHAR(50) UNIQUE, start_date DATE, end_date DATE,
    value NUMERIC(14,2), terms TEXT, status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS purchase_requisitions (
    pr_id SERIAL PRIMARY KEY, requested_by INT REFERENCES employees(employee_id),
    dept_id INT REFERENCES departments(dept_id), requisition_date TIMESTAMP DEFAULT NOW(),
    description TEXT, total_estimated NUMERIC(12,2), status VARCHAR(20) DEFAULT 'draft',
    approved_by INT, approved_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_orders_erp (
    po_id SERIAL PRIMARY KEY, pr_id INT REFERENCES purchase_requisitions(pr_id),
    vendor_id INT REFERENCES vendors(vendor_id), po_number VARCHAR(50) UNIQUE,
    order_date TIMESTAMP DEFAULT NOW(), delivery_date DATE,
    total_amount NUMERIC(14,2), status VARCHAR(20) DEFAULT 'pending',
    payment_terms VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS po_items (
    poi_id SERIAL PRIMARY KEY, po_id INT REFERENCES purchase_orders_erp(po_id),
    item_description TEXT, quantity INT, unit_price NUMERIC(12,2),
    total_price NUMERIC(14,2), received_quantity INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS inventory_items_erp (
    item_id SERIAL PRIMARY KEY, name VARCHAR(200), sku VARCHAR(50) UNIQUE,
    category VARCHAR(50), unit_of_measure VARCHAR(20),
    unit_price NUMERIC(12,2), reorder_level INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id SERIAL PRIMARY KEY, name VARCHAR(100), location VARCHAR(200),
    capacity_sqft NUMERIC(10,2), manager_id INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS warehouse_transactions (
    wtxn_id SERIAL PRIMARY KEY, warehouse_id INT REFERENCES warehouses(warehouse_id),
    item_id INT REFERENCES inventory_items_erp(item_id), transaction_type VARCHAR(20),
    quantity INT, reference_type VARCHAR(30), reference_id INT,
    transaction_date TIMESTAMP DEFAULT NOW(), created_by INT
);

CREATE TABLE IF NOT EXISTS assets (
    asset_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    name VARCHAR(200), asset_type VARCHAR(50), purchase_date DATE,
    purchase_cost NUMERIC(14,2), salvage_value NUMERIC(12,2) DEFAULT 0,
    useful_life_years INT, depreciation_method VARCHAR(30),
    current_value NUMERIC(14,2), status VARCHAR(20) DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS asset_depreciation (
    depr_id SERIAL PRIMARY KEY, asset_id INT REFERENCES assets(asset_id),
    depreciation_date DATE, amount NUMERIC(12,2),
    accumulated_depreciation NUMERIC(14,2), book_value NUMERIC(14,2)
);

CREATE TABLE IF NOT EXISTS chart_of_accounts (
    account_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    account_code VARCHAR(20) UNIQUE, account_name VARCHAR(100),
    account_type VARCHAR(30), parent_account_id INT REFERENCES chart_of_accounts(account_id),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS journal_entries (
    je_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    entry_number VARCHAR(30) UNIQUE, entry_date DATE,
    description TEXT, created_by INT, created_at TIMESTAMP DEFAULT NOW(),
    approved BOOLEAN DEFAULT FALSE, posted BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS journal_entry_lines (
    jel_id SERIAL PRIMARY KEY, je_id INT REFERENCES journal_entries(je_id),
    account_id INT REFERENCES chart_of_accounts(account_id),
    debit_amount NUMERIC(14,2) DEFAULT 0, credit_amount NUMERIC(14,2) DEFAULT 0,
    description TEXT
);

CREATE TABLE IF NOT EXISTS accounts_payable (
    ap_id SERIAL PRIMARY KEY, vendor_id INT REFERENCES vendors(vendor_id),
    invoice_number VARCHAR(50), invoice_date DATE, due_date DATE,
    amount NUMERIC(14,2), balance NUMERIC(14,2), status VARCHAR(20) DEFAULT 'open'
);

CREATE TABLE IF NOT EXISTS accounts_receivable (
    ar_id SERIAL PRIMARY KEY, customer_name VARCHAR(200), invoice_number VARCHAR(50),
    invoice_date DATE, due_date DATE, amount NUMERIC(14,2),
    balance NUMERIC(14,2), status VARCHAR(20) DEFAULT 'open'
);

CREATE TABLE IF NOT EXISTS budgets (
    budget_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    fiscal_year INT, name VARCHAR(100), total_amount NUMERIC(14,2),
    created_at TIMESTAMP DEFAULT NOW(), approved BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS budget_lines (
    bl_id SERIAL PRIMARY KEY, budget_id INT REFERENCES budgets(budget_id),
    dept_id INT REFERENCES departments(dept_id), category VARCHAR(100),
    allocated_amount NUMERIC(14,2), spent_amount NUMERIC(14,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS audit_logs (
    log_id SERIAL PRIMARY KEY, company_id INT REFERENCES companies(company_id),
    table_name VARCHAR(50), record_id INT, action VARCHAR(20),
    old_values TEXT, new_values TEXT, changed_by INT,
    changed_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS approvals (
    approval_id SERIAL PRIMARY KEY, reference_type VARCHAR(30), reference_id INT,
    requested_by INT, approved_by INT, status VARCHAR(20) DEFAULT 'pending',
    comments TEXT, requested_at TIMESTAMP DEFAULT NOW(), decided_at TIMESTAMP
);

SELECT 'Inserting erp_system data...';

DO $data$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM companies LIMIT 1) THEN
        INSERT INTO companies (name, tax_id, address, phone, email, founded_date) VALUES
        ('Acme Corporation','TAX-001-USA','123 Business Ave, NY','555-0100','info@acme.com','2005-03-15'),
        ('GlobalTech Industries','TAX-002-USA','456 Innovation Dr, CA','555-0200','info@globaltech.com','2010-07-22'),
        ('Prime Solutions Ltd','TAX-003-UK','789 Commerce St, London','555-0300','info@primesol.com','2008-11-01');
        
        INSERT INTO departments (company_id, name, code, budget)
        SELECT c.company_id, d.name, d.code, (random() * 5000000 + 100000)::numeric(14,2)
        FROM companies CROSS JOIN (
            VALUES ('Finance','FIN'),('Human Resources','HR'),('IT','IT'),
                   ('Operations','OPS'),('Sales','SALES'),('Marketing','MKTG'),
                   ('Legal','LEGAL'),('R&D','RD'),('Customer Support','CS'),('Procurement','PROC')
        ) AS d(name, code);
        
        INSERT INTO positions (dept_id, title, min_salary, max_salary)
        SELECT d.dept_id, p.title, p.min_salary, p.max_salary
        FROM departments d, (VALUES
            ('Junior Analyst',35000,55000),('Senior Analyst',55000,80000),
            ('Manager',75000,120000),('Director',110000,180000),
            ('VP',160000,250000),('Associate',40000,65000),
            ('Coordinator',30000,50000),('Specialist',45000,75000),
            ('Lead',65000,100000),('Executive',200000,350000)
        ) AS p(title, min_salary, max_salary);
        
        INSERT INTO employees (company_id, dept_id, position_id, first_name, last_name, email, phone, hire_date, salary, status)
        SELECT
            (random() * 2 + 1)::int,
            (random() * 9 + 1)::int,
            (random() * 9 + 1)::int,
            (ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Barbara',
                   'William','Elizabeth','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Christopher','Karen'])[floor(random() * 20 + 1)],
            (ARRAY['Miller','Davis','Garcia','Rodriguez','Wilson','Martinez','Anderson','Taylor','Thomas','Moore',
                   'Jackson','Martin','Lee','Perez','White','Harris','Sanchez','Clark','Ramirez','Lewis'])[floor(random() * 20 + 1)],
            'emp' || g || '@erp.com',
            '555-' || LPAD((random() * 999999)::int::text, 6, '0'),
            CURRENT_DATE - (random() * 365 * 10)::int,
            (random() * 150000 + 30000)::numeric(12,2),
            CASE WHEN random() < 0.95 THEN 'active' ELSE 'inactive' END
        FROM generate_series(1, 10000) g;
        
        UPDATE departments SET manager_id = (random() * 9999 + 1)::int;
        
        INSERT INTO projects (company_id, name, code, description, start_date, end_date, budget, status)
        SELECT
            (random() * 2 + 1)::int,
            'Project ' || g,
            'PRJ-' || LPAD(g::text, 4, '0'),
            'ERP project number ' || g,
            CURRENT_DATE - (random() * 365)::int,
            CURRENT_DATE + (random() * 365)::int,
            (random() * 1000000 + 50000)::numeric(14,2),
            (ARRAY['planning','active','on_hold','completed','cancelled'])[floor(random() * 5 + 1)]
        FROM generate_series(1, 50000) g;
        
        INSERT INTO project_tasks (project_id, name, description, assigned_to, start_date, due_date, estimated_hours, status)
        SELECT
            (random() * 49999 + 1)::int,
            'Task ' || g,
            'Description for task ' || g,
            (random() * 9999 + 1)::int,
            CURRENT_DATE - (random() * 180)::int,
            CURRENT_DATE + (random() * 180)::int,
            (random() * 100 + 2)::numeric(8,2),
            (ARRAY['todo','in_progress','review','done','blocked'])[floor(random() * 5 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO journal_entries (company_id, entry_number, entry_date, description, created_by, posted)
        SELECT
            (random() * 2 + 1)::int,
            'JE-' || LPAD(g::text, 8, '0'),
            CURRENT_DATE - (random() * 730)::int,
            'Journal entry ' || g,
            (random() * 9999 + 1)::int,
            random() < 0.85
        FROM generate_series(1, 100000) g;
        
        INSERT INTO journal_entry_lines (je_id, account_id, debit_amount, credit_amount)
        SELECT
            (random() * 99999 + 1)::int,
            (random() * 99 + 1)::int,
            CASE WHEN random() < 0.5 THEN (random() * 10000)::numeric(14,2) ELSE 0 END,
            CASE WHEN random() >= 0.5 THEN (random() * 10000)::numeric(14,2) ELSE 0 END
        FROM generate_series(1, 200000) g;
        
        INSERT INTO attendance_records (employee_id, work_date, clock_in, clock_out, hours_worked, status)
        SELECT
            (random() * 9999 + 1)::int,
            CURRENT_DATE - (random() * 365)::int,
            (TIME '08:00' + (random() * 60 || ' minutes')::interval),
            (TIME '17:00' + (random() * 60 || ' minutes')::interval),
            (random() * 2 + 8)::numeric(5,2),
            (ARRAY['present','absent','late','half_day'])[floor(random() * 4 + 1)]
        FROM generate_series(1, 200000) g;
    END IF;
END $data$;

CREATE INDEX IF NOT EXISTS idx_employees_dept ON employees(dept_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_project_tasks_project ON project_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_project_tasks_assigned ON project_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_project_tasks_status ON project_tasks(status);
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_entries_company ON journal_entries(company_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_je ON journal_entry_lines(je_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_entry_lines(account_id);
CREATE INDEX IF NOT EXISTS idx_attendance_employee ON attendance_records(employee_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance_records(work_date);
CREATE INDEX IF NOT EXISTS idx_payroll_employee ON payroll(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_requests_employee ON leave_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests(status);
CREATE INDEX IF NOT EXISTS idx_expenses_status ON expenses(status);
CREATE INDEX IF NOT EXISTS idx_vendors_active ON vendors(is_active);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders_erp(status);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_budgets_fiscal ON budgets(fiscal_year);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_date ON warehouse_transactions(transaction_date);

-- #############################################################################
-- HRM TOOL DATABASE
-- #############################################################################
\echo '=== Database: hrm_tool ==='
\c hrm_tool

SELECT 'Creating hrm_tool tables...';

CREATE TABLE IF NOT EXISTS organizations (
    org_id SERIAL PRIMARY KEY, name VARCHAR(200), registration_number VARCHAR(50) UNIQUE,
    address TEXT, phone VARCHAR(20), email VARCHAR(100), website VARCHAR(200),
    industry VARCHAR(100), founded_date DATE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS branches (
    branch_id SERIAL PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    name VARCHAR(100), address TEXT, phone VARCHAR(20), email VARCHAR(100),
    manager_id INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS departments_hrm (
    dept_id SERIAL PRIMARY KEY, branch_id INT REFERENCES branches(branch_id),
    name VARCHAR(100), code VARCHAR(20), cost_center VARCHAR(50),
    manager_id INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS positions_hrm (
    position_id SERIAL PRIMARY KEY, dept_id INT REFERENCES departments_hrm(dept_id),
    title VARCHAR(100), job_description TEXT, min_experience_years INT,
    education_requirement VARCHAR(100), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS employees_hrm (
    employee_id SERIAL PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    branch_id INT REFERENCES branches(branch_id), dept_id INT REFERENCES departments_hrm(dept_id),
    position_id INT REFERENCES positions_hrm(position_id),
    employee_code VARCHAR(30) UNIQUE, first_name VARCHAR(50), last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE, phone VARCHAR(20), date_of_birth DATE,
    gender VARCHAR(10), marital_status VARCHAR(20), blood_group VARCHAR(5),
    hire_date DATE, confirmation_date DATE, exit_date DATE,
    employment_type VARCHAR(30) DEFAULT 'permanent',
    status VARCHAR(20) DEFAULT 'active', manager_id INT
);

CREATE TABLE IF NOT EXISTS employee_education (
    edu_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    degree VARCHAR(100), institution VARCHAR(200), year_of_passing INT,
    percentage NUMERIC(5,2), specialization VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS employee_certifications (
    cert_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    certification_name VARCHAR(200), issuing_authority VARCHAR(100),
    issue_date DATE, expiry_date DATE, cert_number VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS skills (
    skill_id SERIAL PRIMARY KEY, name VARCHAR(100), category VARCHAR(50),
    description TEXT
);

CREATE TABLE IF NOT EXISTS employee_skills (
    es_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    skill_id INT REFERENCES skills(skill_id), proficiency_level INT CHECK(proficiency_level BETWEEN 1 AND 5),
    years_of_experience NUMERIC(4,1), last_used_date DATE
);

CREATE TABLE IF NOT EXISTS employee_documents_hrm (
    doc_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    doc_type VARCHAR(30), doc_name VARCHAR(100), file_path VARCHAR(500),
    uploaded_at TIMESTAMP DEFAULT NOW(), verified BOOLEAN DEFAULT FALSE,
    verified_by INT, verified_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS attendance_hrm (
    attendance_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    work_date DATE, day_type VARCHAR(20) DEFAULT 'working',
    clock_in TIME, clock_out TIME, hours_worked NUMERIC(5,2),
    overtime NUMERIC(5,2) DEFAULT 0, status VARCHAR(20) DEFAULT 'present',
    remarks TEXT
);

CREATE TABLE IF NOT EXISTS attendance_logs_hrm (
    log_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    log_date DATE, log_time TIME, log_type VARCHAR(20),
    device_id VARCHAR(50), ip_address VARCHAR(50), verified_by VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS leave_policies (
    policy_id SERIAL PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    policy_name VARCHAR(100), leave_type VARCHAR(50), max_days_per_year INT,
    min_notice_days INT, carry_forward_limit INT,
    requires_approval BOOLEAN DEFAULT TRUE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS leave_balances (
    balance_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    policy_id INT REFERENCES leave_policies(policy_id),
    total_allocated INT, used INT DEFAULT 0, pending INT DEFAULT 0,
    remaining INT, fiscal_year INT
);

CREATE TABLE IF NOT EXISTS leave_applications_hrm (
    leave_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    policy_id INT REFERENCES leave_policies(policy_id),
    start_date DATE, end_date DATE, total_days INT,
    reason TEXT, status VARCHAR(20) DEFAULT 'pending',
    applied_on TIMESTAMP DEFAULT NOW(), approved_by INT, approved_on TIMESTAMP,
    comments TEXT
);

CREATE TABLE IF NOT EXISTS payroll_hrm (
    payroll_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    pay_period_start DATE, pay_period_end DATE, basic_pay NUMERIC(12,2),
    allowances NUMERIC(12,2), deductions NUMERIC(12,2),
    gross_pay NUMERIC(12,2), net_pay NUMERIC(12,2),
    payment_date DATE, payment_method VARCHAR(30), status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS payroll_components (
    comp_id SERIAL PRIMARY KEY, payroll_id INT REFERENCES payroll_hrm(payroll_id),
    component_type VARCHAR(30), component_name VARCHAR(100), amount NUMERIC(12,2),
    is_taxable BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS salary_revisions (
    revision_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    previous_salary NUMERIC(12,2), new_salary NUMERIC(12,2),
    revision_date DATE, revision_type VARCHAR(30), reason TEXT,
    approved_by INT, created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bonuses (
    bonus_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    bonus_type VARCHAR(50), amount NUMERIC(12,2), bonus_date DATE,
    description TEXT, approved_by INT, status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS deductions_hrm (
    deduction_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    deduction_type VARCHAR(50), amount NUMERIC(12,2),
    frequency VARCHAR(20), start_date DATE, end_date DATE,
    description TEXT, is_mandatory BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS performance_reviews_hrm (
    review_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    reviewer_id INT REFERENCES employees_hrm(employee_id),
    review_period VARCHAR(30), review_date DATE,
    overall_rating INT CHECK(overall_rating BETWEEN 1 AND 5),
    summary TEXT, strengths TEXT, improvements TEXT,
    status VARCHAR(20) DEFAULT 'draft', created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS review_goals (
    goal_id SERIAL PRIMARY KEY, review_id INT REFERENCES performance_reviews_hrm(review_id),
    goal_name VARCHAR(200), goal_description TEXT, target_date DATE,
    weight NUMERIC(5,2), self_rating INT, reviewer_rating INT,
    status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS review_feedback (
    feedback_id SERIAL PRIMARY KEY, review_id INT REFERENCES performance_reviews_hrm(review_id),
    feedback_giver_id INT REFERENCES employees_hrm(employee_id),
    feedback_text TEXT, rating INT, submitted_at TIMESTAMP DEFAULT NOW(),
    is_confidential BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS training_programs (
    program_id SERIAL PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    program_name VARCHAR(200), description TEXT, trainer VARCHAR(100),
    duration_hours INT, mode VARCHAR(30), start_date DATE, end_date DATE,
    max_participants INT, cost NUMERIC(10,2), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS training_enrollments (
    enrollment_id SERIAL PRIMARY KEY, program_id INT REFERENCES training_programs(program_id),
    employee_id INT REFERENCES employees_hrm(employee_id),
    enrolled_at TIMESTAMP DEFAULT NOW(), status VARCHAR(20) DEFAULT 'enrolled',
    completion_date DATE, score NUMERIC(5,2)
);

CREATE TABLE IF NOT EXISTS training_feedback_hrm (
    feedback_id SERIAL PRIMARY KEY, enrollment_id INT REFERENCES training_enrollments(enrollment_id),
    rating INT CHECK(rating BETWEEN 1 AND 5), feedback_text TEXT,
    submitted_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS job_applications (
    application_id SERIAL PRIMARY KEY, position_id INT REFERENCES positions_hrm(position_id),
    applicant_name VARCHAR(100), email VARCHAR(100), phone VARCHAR(20),
    resume_path VARCHAR(500), cover_letter TEXT,
    applied_at TIMESTAMP DEFAULT NOW(), status VARCHAR(20) DEFAULT 'received',
    source VARCHAR(30), current_company VARCHAR(100), experience_years NUMERIC(4,1)
);

CREATE TABLE IF NOT EXISTS interview_schedules (
    interview_id SERIAL PRIMARY KEY, application_id INT REFERENCES job_applications(application_id),
    interviewer_id INT REFERENCES employees_hrm(employee_id),
    interview_date TIMESTAMP, mode VARCHAR(20), duration_minutes INT,
    status VARCHAR(20) DEFAULT 'scheduled', location VARCHAR(200), notes TEXT
);

CREATE TABLE IF NOT EXISTS interview_feedback_hrm (
    feedback_id SERIAL PRIMARY KEY, interview_id INT REFERENCES interview_schedules(interview_id),
    interviewer_id INT REFERENCES employees_hrm(employee_id),
    technical_score INT, communication_score INT, cultural_fit INT,
    overall_recommendation VARCHAR(30), comments TEXT, submitted_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS offer_letters (
    offer_id SERIAL PRIMARY KEY, application_id INT REFERENCES job_applications(application_id),
    offered_salary NUMERIC(12,2), joining_date DATE, offer_date DATE,
    status VARCHAR(20) DEFAULT 'draft', accepted BOOLEAN, accepted_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS onboarding_tasks (
    task_id SERIAL PRIMARY KEY, task_name VARCHAR(200), description TEXT,
    assigned_role VARCHAR(50), due_days_from_joining INT,
    is_mandatory BOOLEAN DEFAULT TRUE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS employee_onboarding (
    onboarding_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    task_id INT REFERENCES onboarding_tasks(task_id), assigned_to INT,
    due_date DATE, completed_date DATE, status VARCHAR(20) DEFAULT 'pending',
    notes TEXT
);

CREATE TABLE IF NOT EXISTS exit_interviews (
    exit_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    exit_date DATE, reason VARCHAR(200), feedback TEXT,
    notice_period_served BOOLEAN, eligible_for_rehire BOOLEAN,
    conducted_by INT, conducted_date DATE
);

CREATE TABLE IF NOT EXISTS grievances (
    grievance_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    grievance_type VARCHAR(50), subject VARCHAR(200), description TEXT,
    priority VARCHAR(10), status VARCHAR(20) DEFAULT 'open',
    created_at TIMESTAMP DEFAULT NOW(), resolved_at TIMESTAMP,
    resolved_by INT, resolution TEXT
);

CREATE TABLE IF NOT EXISTS disciplinary_actions (
    action_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    action_type VARCHAR(50), description TEXT, incident_date DATE,
    action_date DATE, taken_by INT, status VARCHAR(20),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS employee_benefits (
    benefit_id SERIAL PRIMARY KEY, org_id INT REFERENCES organizations(org_id),
    benefit_name VARCHAR(100), description TEXT, benefit_type VARCHAR(30),
    employer_contribution NUMERIC(10,2), employee_contribution NUMERIC(10,2),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS benefit_enrollments (
    enrollment_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    benefit_id INT REFERENCES employee_benefits(benefit_id),
    enrolled_at DATE, opt_out_at DATE, status VARCHAR(20) DEFAULT 'active',
    dependents INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS shift_rosters (
    roster_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    shift_date DATE, start_time TIME, end_time TIME,
    shift_type VARCHAR(30), created_by INT, notes TEXT
);

CREATE TABLE IF NOT EXISTS employee_recognition (
    recognition_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_hrm(employee_id),
    award_type VARCHAR(50), description TEXT, recognized_by INT,
    recognition_date DATE, points INT DEFAULT 0
);

SELECT 'Inserting hrm_tool data...';

DO $data$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM organizations LIMIT 1) THEN
        INSERT INTO organizations (name, registration_number, industry, founded_date) VALUES
        ('TechCorp International','REG-1001-USA','Technology','2010-01-15'),
        ('HealthFirst Group','REG-1002-USA','Healthcare','2005-06-20'),
        ('EduPrime Academy','REG-1003-USA','Education','2015-03-10'),
        ('FinServe Solutions','REG-1004-UK','Finance','2008-11-01'),
        ('RetailMax Inc','REG-1005-USA','Retail','2012-09-25');
        
        INSERT INTO branches (org_id, name, address, phone, email)
        SELECT o.org_id, b.name, b.address, '555-' || LPAD((random() * 999999)::int::text, 6, '0'), b.name || '@branch.com'
        FROM organizations o, (VALUES
            ('Downtown Office','100 Main St, NY'),('Uptown Office','200 Park Ave, NY'),
            ('Westside Branch','300 Oak Rd, CA'),('Eastside Office','400 Pine Dr, TX'),
            ('Midtown Hub','500 Elm St, IL'),('Airport Branch','600 Airport Blvd, FL'),
            ('Tech Park','700 Innovation Dr, WA'),('Business Center','800 Commerce St, MA')
        ) AS b(name, address);
        
        INSERT INTO departments_hrm (branch_id, name, code, cost_center)
        SELECT b.branch_id, d.name, LEFT(d.name, 3) || b.branch_id, 'CC-' || b.branch_id || '-' || LEFT(d.name, 3)
        FROM branches b, (VALUES ('Engineering'),('Finance'),('Marketing'),('Sales'),('HR'),
                                 ('Operations'),('Legal'),('Support'),('R&D'),('Admin')) AS d(name);
        
        INSERT INTO positions_hrm (dept_id, title, min_experience_years, education_requirement)
        SELECT d.dept_id, p.title, (random() * 5 + 1)::int, p.edu
        FROM departments_hrm d, (VALUES
            ('Junior Engineer', 'Bachelors'),('Senior Engineer', 'Masters'),
            ('Team Lead', 'Masters'),('Manager', 'MBA'),
            ('Director', 'MBA/PhD'),('Analyst', 'Bachelors'),
            ('Associate', 'Bachelors'),('Executive', 'MBA'),
            ('Consultant', 'Masters'),('Intern', 'Bachelors')
        ) AS p(title, edu);
        
        INSERT INTO employees_hrm (org_id, branch_id, dept_id, position_id, employee_code, first_name, last_name, email, phone, hire_date, employment_type, status)
        SELECT
            (random() * 4 + 1)::int, (random() * 7 + 1)::int, (random() * 9 + 1)::int, (random() * 9 + 1)::int,
            'EMP-' || LPAD(g::text, 6, '0'),
            (ARRAY['Aarav','Vihaan','Vivaan','Ananya','Diya','Advik','Kabir','Aarohi','Anaya','Ishaan',
                   'Sai','Pari','Arjun','Aadhya','Reyansh','Anika','Krishna','Ishita','Shaurya','Myra'])[floor(random() * 20 + 1)],
            (ARRAY['Sharma','Verma','Patel','Kumar','Singh','Joshi','Reddy','Nair','Gupta','Mehta',
                   'Desai','Bose','Choudhury','Saxena','Rao','Malhotra','Srinivas','Iyer','Bhat','Pillai'])[floor(random() * 20 + 1)],
            'hrm_emp' || g || '@company.com',
            '555-' || LPAD((random() * 999999)::int::text, 6, '0'),
            CURRENT_DATE - (random() * 365 * 8)::int,
            (ARRAY['permanent','contract','probation','intern'])[floor(random() * 4 + 1)],
            CASE WHEN random() < 0.92 THEN 'active' ELSE 'inactive' END
        FROM generate_series(1, 50000) g;
        
        INSERT INTO leave_policies (org_id, policy_name, leave_type, max_days_per_year, carry_forward_limit)
        SELECT o.org_id, p.policy_name, p.leave_type, p.max_days, p.carry
        FROM organizations o, (VALUES
            ('Annual Leave - Full Time','annual',20,10),('Sick Leave','sick',12,0),
            ('Personal Leave','personal',5,0),('Maternity Leave','maternity',180,0),
            ('Paternity Leave','paternity',15,0),('Bereavement Leave','bereavement',5,0),
            ('Study Leave','study',10,0),('Sabbatical','sabbatical',365,0)
        ) AS p(policy_name, leave_type, max_days, carry);
        
        INSERT INTO leave_applications_hrm (employee_id, policy_id, start_date, end_date, total_days, status, reason)
        SELECT
            (random() * 49999 + 1)::int, (random() * 7 + 1)::int,
            CURRENT_DATE - (random() * 365)::int,
            CURRENT_DATE - (random() * 365)::int + (random() * 5 + 1)::int,
            (random() * 5 + 1)::int,
            (ARRAY['pending','approved','rejected','cancelled'])[floor(random() * 4 + 1)],
            (ARRAY['Vacation','Medical appointment','Family event','Personal reasons','Sick','Travel'])[floor(random() * 6 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO attendance_logs_hrm (employee_id, log_date, log_time, log_type)
        SELECT
            (random() * 49999 + 1)::int,
            CURRENT_DATE - (random() * 365)::int,
            CASE WHEN random() < 0.5 THEN TIME '08:00' + (random() * 120 || ' minutes')::interval
                 ELSE TIME '17:00' + (random() * 60 || ' minutes')::interval END,
            CASE WHEN random() < 0.5 THEN 'check_in' ELSE 'check_out' END
        FROM generate_series(1, 200000) g;
        
        INSERT INTO payroll_hrm (employee_id, pay_period_start, pay_period_end, basic_pay, allowances, deductions, gross_pay, net_pay, status)
        SELECT
            (random() * 49999 + 1)::int,
            CURRENT_DATE - (random() * 180)::int,
            CURRENT_DATE - (random() * 180)::int + 14,
            (random() * 100000 + 20000)::numeric(12,2),
            (random() * 20000 + 5000)::numeric(12,2),
            (random() * 15000 + 2000)::numeric(12,2),
            (random() * 120000 + 25000)::numeric(12,2),
            (random() * 100000 + 20000)::numeric(12,2),
            (ARRAY['paid','pending','processing'])[floor(random() * 3 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO performance_reviews_hrm (employee_id, reviewer_id, review_period, review_date, overall_rating, status)
        SELECT
            (random() * 49999 + 1)::int, (random() * 49999 + 1)::int,
            (ARRAY['Q1 2024','Q2 2024','Q3 2024','Q4 2024','Annual 2024','Q1 2025'])[floor(random() * 6 + 1)],
            CURRENT_DATE - (random() * 180)::int,
            (random() * 4 + 1)::int,
            (ARRAY['draft','submitted','reviewed','completed'])[floor(random() * 4 + 1)]
        FROM generate_series(1, 50000) g;
        
        INSERT INTO training_programs (org_id, program_name, description, trainer, duration_hours, mode, start_date, end_date, max_participants)
        SELECT
            (random() * 4 + 1)::int,
            'Training Program ' || g,
            'Professional development program ' || g,
            (ARRAY['John Smith','Sarah Johnson','Mike Brown','Lisa Davis','Robert Wilson'])[floor(random() * 5 + 1)],
            (random() * 40 + 4)::int,
            (ARRAY['online','in_person','hybrid'])[floor(random() * 3 + 1)],
            CURRENT_DATE - (random() * 180)::int,
            CURRENT_DATE + (random() * 180)::int,
            (random() * 30 + 10)::int
        FROM generate_series(1, 500) g;
        
        INSERT INTO training_enrollments (program_id, employee_id, status, completion_date, score)
        SELECT
            (random() * 499 + 1)::int, (random() * 49999 + 1)::int,
            (ARRAY['enrolled','in_progress','completed','dropped'])[floor(random() * 4 + 1)],
            CASE WHEN random() < 0.6 THEN CURRENT_DATE - (random() * 90)::int ELSE NULL END,
            CASE WHEN random() < 0.6 THEN (random() * 40 + 60)::numeric(5,2) ELSE NULL END
        FROM generate_series(1, 10000) g;
        
        INSERT INTO job_applications (position_id, applicant_name, email, phone, status, source, experience_years)
        SELECT
            (random() * 99 + 1)::int,
            'Applicant ' || g,
            'applicant' || g || '@email.com',
            '555-' || LPAD((random() * 999999)::int::text, 6, '0'),
            (ARRAY['received','screening','interviewed','offered','hired','rejected'])[floor(random() * 6 + 1)],
            (ARRAY['linkedin','indeed','website','referral','agency'])[floor(random() * 5 + 1)],
            (random() * 15 + 1)::numeric(4,1)
        FROM generate_series(1, 20000) g;
    END IF;
END $data$;

CREATE INDEX IF NOT EXISTS idx_employees_hrm_dept ON employees_hrm(dept_id);
CREATE INDEX IF NOT EXISTS idx_employees_hrm_status ON employees_hrm(status);
CREATE INDEX IF NOT EXISTS idx_employees_hrm_code ON employees_hrm(employee_code);
CREATE INDEX IF NOT EXISTS idx_leave_applications_employee ON leave_applications_hrm(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_applications_status ON leave_applications_hrm(status);
CREATE INDEX IF NOT EXISTS idx_leave_applications_dates ON leave_applications_hrm(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_attendance_logs_employee ON attendance_logs_hrm(employee_id);
CREATE INDEX IF NOT EXISTS idx_attendance_logs_date ON attendance_logs_hrm(log_date);
CREATE INDEX IF NOT EXISTS idx_payroll_hrm_employee ON payroll_hrm(employee_id);
CREATE INDEX IF NOT EXISTS idx_payroll_hrm_status ON payroll_hrm(status);
CREATE INDEX IF NOT EXISTS idx_performance_hrm_employee ON performance_reviews_hrm(employee_id);
CREATE INDEX IF NOT EXISTS idx_performance_hrm_rating ON performance_reviews_hrm(overall_rating);
CREATE INDEX IF NOT EXISTS idx_training_enrollments_program ON training_enrollments(program_id);
CREATE INDEX IF NOT EXISTS idx_training_enrollments_employee ON training_enrollments(employee_id);
CREATE INDEX IF NOT EXISTS idx_job_applications_status ON job_applications(status);
CREATE INDEX IF NOT EXISTS idx_job_applications_position ON job_applications(position_id);
CREATE INDEX IF NOT EXISTS idx_employee_skills_employee ON employee_skills(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_skills_skill ON employee_skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_grievances_status ON grievances(status);
CREATE INDEX IF NOT EXISTS idx_benefit_enrollments_employee ON benefit_enrollments(employee_id);
CREATE INDEX IF NOT EXISTS idx_shift_rosters_employee ON shift_rosters(employee_id);
CREATE INDEX IF NOT EXISTS idx_shift_rosters_date ON shift_rosters(shift_date);

-- #############################################################################
-- DEPARTMENT STORE DATABASE
-- #############################################################################
\echo '=== Database: department_store ==='
\c department_store

SELECT 'Creating department_store tables...';

CREATE TABLE IF NOT EXISTS stores (
    store_id SERIAL PRIMARY KEY, store_code VARCHAR(20) UNIQUE, name VARCHAR(100),
    address TEXT, city VARCHAR(50), state VARCHAR(50), zip VARCHAR(20),
    phone VARCHAR(20), email VARCHAR(100), manager_id INT,
    open_time TIME DEFAULT '08:00', close_time TIME DEFAULT '22:00',
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS store_sections (
    section_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    section_name VARCHAR(100), section_code VARCHAR(20), floor INT,
    area_sqft NUMERIC(10,2), description TEXT
);

CREATE TABLE IF NOT EXISTS departments_store (
    dept_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    section_id INT REFERENCES store_sections(section_id),
    name VARCHAR(100), code VARCHAR(20), manager_id INT,
    budget NUMERIC(14,2), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS categories_store (
    category_id SERIAL PRIMARY KEY, dept_id INT REFERENCES departments_store(dept_id),
    name VARCHAR(100), description TEXT, parent_category_id INT REFERENCES categories_store(category_id),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS products_store (
    product_id SERIAL PRIMARY KEY, category_id INT REFERENCES categories_store(category_id),
    sku VARCHAR(50) UNIQUE, barcode VARCHAR(50) UNIQUE, name VARCHAR(200),
    description TEXT, brand VARCHAR(100), unit_price NUMERIC(10,2),
    cost_price NUMERIC(10,2), tax_rate NUMERIC(5,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
    variant_id SERIAL PRIMARY KEY, product_id INT REFERENCES products_store(product_id),
    sku VARCHAR(50) UNIQUE, variant_name VARCHAR(100), color VARCHAR(30),
    size VARCHAR(20), unit_price NUMERIC(10,2), quantity INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS variant_attributes (
    va_id SERIAL PRIMARY KEY, variant_id INT REFERENCES product_variants(variant_id),
    attribute_name VARCHAR(50), attribute_value VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS suppliers_store (
    supplier_id SERIAL PRIMARY KEY, supplier_code VARCHAR(30) UNIQUE,
    company_name VARCHAR(200), contact_person VARCHAR(50),
    email VARCHAR(100), phone VARCHAR(20), address TEXT,
    payment_terms VARCHAR(50), lead_time_days INT, rating INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS purchase_orders_store (
    po_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    supplier_id INT REFERENCES suppliers_store(supplier_id),
    po_number VARCHAR(50) UNIQUE, order_date TIMESTAMP DEFAULT NOW(),
    expected_delivery DATE, status VARCHAR(20) DEFAULT 'pending',
    total_amount NUMERIC(14,2), notes TEXT
);

CREATE TABLE IF NOT EXISTS purchase_order_items_store (
    poi_id SERIAL PRIMARY KEY, po_id INT REFERENCES purchase_orders_store(po_id),
    product_id INT REFERENCES products_store(product_id),
    variant_id INT REFERENCES product_variants(variant_id),
    quantity INT, unit_cost NUMERIC(10,2), total_cost NUMERIC(14,2),
    received_quantity INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS inventory_store (
    inventory_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    product_id INT REFERENCES products_store(product_id),
    variant_id INT REFERENCES product_variants(variant_id),
    quantity INT DEFAULT 0, min_quantity INT DEFAULT 10,
    max_quantity INT DEFAULT 500, location_code VARCHAR(30),
    last_updated TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_movements (
    movement_id SERIAL PRIMARY KEY, inventory_id INT REFERENCES inventory_store(inventory_id),
    movement_type VARCHAR(20), quantity INT, reference_type VARCHAR(30),
    reference_id INT, movement_date TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(50), notes TEXT
);

CREATE TABLE IF NOT EXISTS stock_counts (
    count_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    count_date DATE, counted_by VARCHAR(50), status VARCHAR(20),
    notes TEXT, created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_count_items (
    sci_id SERIAL PRIMARY KEY, count_id INT REFERENCES stock_counts(count_id),
    product_id INT REFERENCES products_store(product_id),
    expected_qty INT, actual_qty INT, variance INT,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS shelf_locations (
    location_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    section_id INT REFERENCES store_sections(section_id),
    aisle VARCHAR(10), shelf VARCHAR(10), level INT,
    barcode VARCHAR(50), max_capacity INT
);

CREATE TABLE IF NOT EXISTS employees_store (
    employee_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    dept_id INT REFERENCES departments_store(dept_id),
    employee_code VARCHAR(30) UNIQUE, first_name VARCHAR(50), last_name VARCHAR(50),
    email VARCHAR(100), phone VARCHAR(20), role VARCHAR(30),
    hire_date DATE, salary NUMERIC(10,2), manager_id INT,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS employee_schedules (
    schedule_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_store(employee_id),
    shift_date DATE, start_time TIME, end_time TIME,
    role VARCHAR(30), notes TEXT
);

CREATE TABLE IF NOT EXISTS attendance_store (
    attendance_id SERIAL PRIMARY KEY, employee_id INT REFERENCES employees_store(employee_id),
    work_date DATE, clock_in TIME, clock_out TIME,
    hours_worked NUMERIC(5,2), status VARCHAR(20) DEFAULT 'present'
);

CREATE TABLE IF NOT EXISTS sales_transactions (
    transaction_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    customer_id INT, employee_id INT REFERENCES employees_store(employee_id),
    transaction_date TIMESTAMP DEFAULT NOW(), subtotal NUMERIC(12,2),
    tax_amount NUMERIC(10,2), discount_amount NUMERIC(10,2) DEFAULT 0,
    total_amount NUMERIC(12,2), payment_method VARCHAR(30),
    receipt_number VARCHAR(30) UNIQUE, status VARCHAR(20) DEFAULT 'completed'
);

CREATE TABLE IF NOT EXISTS sale_items (
    sale_item_id SERIAL PRIMARY KEY, transaction_id INT REFERENCES sales_transactions(transaction_id),
    product_id INT REFERENCES products_store(product_id),
    variant_id INT REFERENCES product_variants(variant_id),
    quantity INT, unit_price NUMERIC(10,2), total_price NUMERIC(12,2),
    discount NUMERIC(10,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS returns_store (
    return_id SERIAL PRIMARY KEY, transaction_id INT REFERENCES sales_transactions(transaction_id),
    customer_id INT, return_date TIMESTAMP DEFAULT NOW(),
    reason TEXT, status VARCHAR(20) DEFAULT 'requested',
    refund_amount NUMERIC(10,2), processed_by INT
);

CREATE TABLE IF NOT EXISTS return_items_store (
    ri_id SERIAL PRIMARY KEY, return_id INT REFERENCES returns_store(return_id),
    sale_item_id INT REFERENCES sale_items(sale_item_id),
    quantity INT, condition VARCHAR(30), refund_amount NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS customers_store (
    customer_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    first_name VARCHAR(50), last_name VARCHAR(50), email VARCHAR(100),
    phone VARCHAR(20), address TEXT, date_of_birth DATE,
    registered_at TIMESTAMP DEFAULT NOW(), is_loyalty_member BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS customer_loyalty (
    loyalty_id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers_store(customer_id),
    card_number VARCHAR(30) UNIQUE, tier VARCHAR(20) DEFAULT 'bronze',
    points INT DEFAULT 0, total_spent NUMERIC(14,2) DEFAULT 0,
    enrolled_at TIMESTAMP DEFAULT NOW(), is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS loyalty_transactions (
    lt_id SERIAL PRIMARY KEY, loyalty_id INT REFERENCES customer_loyalty(loyalty_id),
    transaction_type VARCHAR(10), points INT, reference_type VARCHAR(30),
    reference_id INT, created_at TIMESTAMP DEFAULT NOW(), description VARCHAR(200)
);

CREATE TABLE IF NOT EXISTS gift_cards_store (
    gift_card_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    card_number VARCHAR(30) UNIQUE, initial_balance NUMERIC(10,2),
    current_balance NUMERIC(10,2), issued_at TIMESTAMP DEFAULT NOW(),
    expires_at DATE, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS gift_card_sales (
    gcs_id SERIAL PRIMARY KEY, gift_card_id INT REFERENCES gift_cards_store(gift_card_id),
    transaction_id INT REFERENCES sales_transactions(transaction_id),
    amount NUMERIC(10,2), sold_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS promotions (
    promotion_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    promotion_name VARCHAR(200), description TEXT,
    discount_type VARCHAR(20), discount_value NUMERIC(10,2),
    min_purchase NUMERIC(10,2), start_date TIMESTAMP, end_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS promotion_products (
    pp_id SERIAL PRIMARY KEY, promotion_id INT REFERENCES promotions(promotion_id),
    product_id INT REFERENCES products_store(product_id)
);

CREATE TABLE IF NOT EXISTS coupons_store (
    coupon_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    code VARCHAR(50) UNIQUE, description TEXT, discount_type VARCHAR(20),
    discount_value NUMERIC(10,2), min_purchase NUMERIC(10,2),
    valid_from DATE, valid_to DATE, usage_limit INT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS coupon_redemptions (
    redemption_id SERIAL PRIMARY KEY, coupon_id INT REFERENCES coupons_store(coupon_id),
    transaction_id INT REFERENCES sales_transactions(transaction_id),
    customer_id INT, redeemed_at TIMESTAMP DEFAULT NOW(), discount_applied NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS marketing_campaigns (
    campaign_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    campaign_name VARCHAR(200), campaign_type VARCHAR(30),
    start_date DATE, end_date DATE, budget NUMERIC(12,2),
    description TEXT, is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS campaign_analytics (
    analytics_id SERIAL PRIMARY KEY, campaign_id INT REFERENCES marketing_campaigns(campaign_id),
    impressions INT DEFAULT 0, clicks INT DEFAULT 0, conversions INT DEFAULT 0,
    revenue_generated NUMERIC(14,2) DEFAULT 0, date DATE
);

CREATE TABLE IF NOT EXISTS vendor_payments (
    payment_id SERIAL PRIMARY KEY, po_id INT REFERENCES purchase_orders_store(po_id),
    supplier_id INT REFERENCES suppliers_store(supplier_id),
    payment_date DATE, amount NUMERIC(14,2),
    payment_method VARCHAR(30), payment_ref VARCHAR(50), status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS store_expenses (
    expense_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    dept_id INT REFERENCES departments_store(dept_id),
    expense_type VARCHAR(50), amount NUMERIC(12,2),
    expense_date DATE, description TEXT, paid_to VARCHAR(100),
    receipt_path VARCHAR(500), approved_by INT
);

CREATE TABLE IF NOT EXISTS daily_sales_summary (
    summary_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    sale_date DATE UNIQUE, total_transactions INT DEFAULT 0,
    total_sales NUMERIC(14,2) DEFAULT 0, total_tax NUMERIC(12,2) DEFAULT 0,
    total_discounts NUMERIC(12,2) DEFAULT 0, avg_transaction_value NUMERIC(10,2) DEFAULT 0,
    item_count INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS price_changes (
    change_id SERIAL PRIMARY KEY, product_id INT REFERENCES products_store(product_id),
    old_price NUMERIC(10,2), new_price NUMERIC(10,2),
    changed_by VARCHAR(50), changed_at TIMESTAMP DEFAULT NOW(),
    reason VARCHAR(200)
);

CREATE TABLE IF NOT EXISTS product_transfers (
    transfer_id SERIAL PRIMARY KEY, product_id INT REFERENCES products_store(product_id),
    from_store_id INT REFERENCES stores(store_id),
    to_store_id INT REFERENCES stores(store_id),
    quantity INT, transfer_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'pending', initiated_by VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS damaged_goods (
    damage_id SERIAL PRIMARY KEY, product_id INT REFERENCES products_store(product_id),
    store_id INT REFERENCES stores(store_id), quantity INT,
    damage_type VARCHAR(50), description TEXT, reported_by VARCHAR(50),
    reported_at TIMESTAMP DEFAULT NOW(), status VARCHAR(20) DEFAULT 'reported',
    disposal_date DATE, insurance_claim BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS customer_complaints (
    complaint_id SERIAL PRIMARY KEY, store_id INT REFERENCES stores(store_id),
    customer_id INT, product_id INT REFERENCES products_store(product_id),
    complaint_type VARCHAR(50), description TEXT,
    complaint_date TIMESTAMP DEFAULT NOW(), status VARCHAR(20) DEFAULT 'open',
    resolved_by INT, resolution TEXT, resolved_at TIMESTAMP
);

SELECT 'Inserting department_store data...';

DO $data$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stores LIMIT 1) THEN
        INSERT INTO stores (store_code, name, address, city, state, zip, phone, email) VALUES
        ('NYC001','Manhattan Flagship','100 5th Ave','New York','NY','10001','555-0101','nyc001@store.com'),
        ('LAX001','Los Angeles Downtown','200 Wilshire Blvd','Los Angeles','CA','90001','555-0102','lax001@store.com'),
        ('CHI001','Chicago Magnificent Mile','300 Michigan Ave','Chicago','IL','60601','555-0103','chi001@store.com'),
        ('HOU001','Houston Galleria','400 Westheimer Rd','Houston','TX','77001','555-0104','hou001@store.com'),
        ('MIA001','Miami Beach','500 Collins Ave','Miami Beach','FL','33101','555-0105','mia001@store.com'),
        ('SEA001','Seattle Downtown','600 Pike St','Seattle','WA','98101','555-0106','sea001@store.com');
        
        INSERT INTO store_sections (store_id, section_name, section_code, floor, area_sqft)
        SELECT s.store_id, sec.section_name, sec.section_code, sec.floor, (random() * 5000 + 500)::numeric(10,2)
        FROM stores s, (VALUES
            ('Men''s Fashion','MENS',1),('Women''s Fashion','WMNS',1),('Kids','KIDS',2),
           ('Electronics','ELEC',2),('Home & Living','HOME',3),('Sports','SPRT',3),
            ('Food Court','FOOD',4),('Grocery','GROC',0),('Beauty','BEAU',0),('Books','BOOK',4)
        ) AS sec(section_name, section_code, floor);
        
        INSERT INTO departments_store (store_id, section_id, name, code, budget)
        SELECT s.store_id, ss.section_id, d.name, d.code, (random() * 2000000 + 100000)::numeric(14,2)
        FROM stores s, store_sections ss, (VALUES
            ('Casual Wear','CW'),('Formal Wear','FW'),('Footwear','FTW'),
            ('Accessories','ACC'),('Kitchen','KIT'),('Furniture','FUR'),
            ('Toys','TOY'),('Stationery','STN'),('Cosmetics','COS'),('Snacks','SNK')
        ) AS d(name, code)
        WHERE ss.store_id = s.store_id;
        
        INSERT INTO categories_store (dept_id, name)
        SELECT d.dept_id, c.name
        FROM departments_store d, (VALUES
            ('T-Shirts'),('Shirts'),('Pants'),('Jeans'),('Dresses'),('Skirts'),
            ('Suits'),('Jackets'),('Shoes'),('Sandals'),('Boots'),('Bags'),
            ('Watches'),('Belts'),('Cookware'),('Bedding'),('Lamps'),('Rugs'),
            ('Action Figures'),('Board Games'),('Pens'),('Notebooks'),('Skincare'),
            ('Makeup'),('Chips'),('Beverages'),('Chocolate'),('Cookies')
        ) AS c(name);
        
        INSERT INTO products_store (category_id, sku, barcode, name, brand, unit_price, cost_price, tax_rate)
        SELECT
            (random() * 27 + 1)::int,
            'SKU-' || LPAD(g::text, 8, '0'),
            'BRC-' || LPAD(g::text, 8, '0'),
            'Store Product ' || g,
            (ARRAY['Nike','Adidas','Puma','Levi''s','Zara','H&M','Gap','Tommy','Ralph','CK'])[floor(random() * 10 + 1)],
            (random() * 200 + 5)::numeric(10,2),
            (random() * 100 + 2)::numeric(10,2),
            (ARRAY[0,5,8,12])[floor(random() * 4 + 1)]
        FROM generate_series(1, 50000) g;
        
        INSERT INTO product_variants (product_id, sku, variant_name, color, size, unit_price, quantity)
        SELECT
            (random() * 49999 + 1)::int,
            'VAR-' || LPAD(g::text, 8, '0'),
            'Variant ' || g,
            (ARRAY['Red','Blue','Green','Black','White','Gray','Navy','Beige'])[floor(random() * 8 + 1)],
            (ARRAY['S','M','L','XL','XXL'])[floor(random() * 5 + 1)],
            (random() * 200 + 5)::numeric(10,2),
            (random() * 200)::int
        FROM generate_series(1, 100000) g;
        
        INSERT INTO inventory_store (store_id, product_id, variant_id, quantity, min_quantity, max_quantity, location_code)
        SELECT
            (random() * 5 + 1)::int, (random() * 49999 + 1)::int, (random() * 99999 + 1)::int,
            (random() * 500)::int, (random() * 20 + 5)::int, (random() * 300 + 100)::int,
            'LOC-' || LPAD((random() * 999)::int::text, 3, '0')
        FROM generate_series(1, 100000) g;
        
        INSERT INTO customers_store (store_id, first_name, last_name, email, phone, is_loyalty_member)
        SELECT
            (random() * 5 + 1)::int,
            (ARRAY['Oliver','Charlotte','Elijah','Amelia','Lucas','Sophia','Mason','Isabella','Logan','Mia',
                   'Ethan','Harper','Aiden','Evelyn','Carter','Abigail','Jacob','Emily','Jayden','Ella'])[floor(random() * 20 + 1)],
            (ARRAY['Brown','Taylor','Wilson','Moore','Jackson','Martin','Lee','White','Harris','Clark'])[floor(random() * 10 + 1)],
            'store_cust' || g || '@email.com',
            '555-' || LPAD((random() * 999999)::int::text, 6, '0'),
            random() < 0.3
        FROM generate_series(1, 50000) g;
        
        INSERT INTO sales_transactions (store_id, employee_id, subtotal, tax_amount, discount_amount, total_amount, payment_method, receipt_number, status)
        SELECT
            (random() * 5 + 1)::int, (random() * 9999 + 1)::int,
            (random() * 500 + 10)::numeric(12,2),
            (random() * 40 + 1)::numeric(10,2),
            (random() * 30)::numeric(10,2),
            ((random() * 500 + 10) + (random() * 40 + 1) - (random() * 30))::numeric(12,2),
            (ARRAY['cash','credit_card','debit_card','gift_card','mobile_pay'])[floor(random() * 5 + 1)],
            'RCPT-' || LPAD(g::text, 8, '0'),
            (ARRAY['completed','refunded','voided'])[floor(random() * 3 + 1)]
        FROM generate_series(1, 100000) g;
        
        INSERT INTO sale_items (transaction_id, product_id, variant_id, quantity, unit_price, total_price)
        SELECT
            (random() * 99999 + 1)::int, (random() * 49999 + 1)::int, (random() * 99999 + 1)::int,
            (random() * 3 + 1)::int,
            (random() * 200 + 5)::numeric(10,2),
            ((random() * 200 + 5) * (random() * 3 + 1))::numeric(12,2)
        FROM generate_series(1, 200000) g;
        
        INSERT INTO promotions (store_id, promotion_name, discount_type, discount_value, min_purchase, start_date, end_date, is_active)
        SELECT
            (random() * 5 + 1)::int,
            'Promotion ' || g,
            (ARRAY['percent','fixed'])[floor(random() * 2 + 1)],
            CASE WHEN random() < 0.5 THEN (random() * 50 + 5)::numeric(10,2) ELSE (random() * 200 + 10)::numeric(10,2) END,
            (random() * 100)::numeric(10,2),
            CURRENT_DATE - (random() * 90)::int,
            CURRENT_DATE + (random() * 90)::int,
            random() < 0.8
        FROM generate_series(1, 2000) g;
        
        INSERT INTO daily_sales_summary (store_id, sale_date, total_transactions, total_sales, total_tax, total_discounts)
        SELECT
            (random() * 5 + 1)::int,
            CURRENT_DATE - g,
            (random() * 500 + 50)::int,
            (random() * 50000 + 5000)::numeric(14,2),
            (random() * 4000 + 200)::numeric(12,2),
            (random() * 2000)::numeric(12,2)
        FROM generate_series(1, 365) g;
        
        INSERT INTO inventory_movements (inventory_id, movement_type, quantity, reference_type, notes)
        SELECT
            (random() * 99999 + 1)::int,
            (ARRAY['inbound','outbound','adjustment','transfer'])[floor(random() * 4 + 1)],
            (random() * 50 + 1)::int,
            (ARRAY['purchase','sale','return','stock_count'])[floor(random() * 4 + 1)],
            'Movement ' || g
        FROM generate_series(1, 100000) g;
    END IF;
END $data$;

CREATE INDEX IF NOT EXISTS idx_products_store_sku ON products_store(sku);
CREATE INDEX IF NOT EXISTS idx_products_store_barcode ON products_store(barcode);
CREATE INDEX IF NOT EXISTS idx_products_store_brand ON products_store(brand);
CREATE INDEX IF NOT EXISTS idx_products_store_price ON products_store(unit_price);
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_store_product ON inventory_store(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_store_store ON inventory_store(store_id);
CREATE INDEX IF NOT EXISTS idx_inventory_store_qty ON inventory_store(quantity);
CREATE INDEX IF NOT EXISTS idx_sales_transactions_store ON sales_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_sales_transactions_date ON sales_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_sales_transactions_status ON sales_transactions(status);
CREATE INDEX IF NOT EXISTS idx_sale_items_transaction ON sale_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id);
CREATE INDEX IF NOT EXISTS idx_customers_store_email ON customers_store(email);
CREATE INDEX IF NOT EXISTS idx_customer_loyalty_card ON customer_loyalty(card_number);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_loyalty ON loyalty_transactions(loyalty_id);
CREATE INDEX IF NOT EXISTS idx_promotions_dates ON promotions(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_promotions_active ON promotions(is_active);
CREATE INDEX IF NOT EXISTS idx_coupons_store_code ON coupons_store(code);
CREATE INDEX IF NOT EXISTS idx_daily_summary_store ON daily_sales_summary(store_id);
CREATE INDEX IF NOT EXISTS idx_daily_summary_date ON daily_sales_summary(sale_date);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_inv ON inventory_movements(inventory_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_type ON inventory_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_suppliers_store_code ON suppliers_store(supplier_code);
CREATE INDEX IF NOT EXISTS idx_price_changes_product ON price_changes(product_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON customer_complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_store ON customer_complaints(store_id);

-- =====================================================
-- SUMMARY
-- =====================================================
\c postgres

SELECT '============================================';
SELECT 'Database Creation Complete!';
SELECT '============================================';
SELECT 'Databases created:';
SELECT datname FROM pg_database WHERE datname IN ('hotel_booking','e_commerce','erp_system','hrm_tool','department_store');
SELECT '============================================';
SELECT 'Connect using: psql -U postgres -d <database_name>';
SELECT 'Or via HAProxy: localhost:5000 / localhost:5001';
SELECT '============================================';


