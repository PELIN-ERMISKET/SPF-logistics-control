
--SPF Logictics DB Tables--

CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    customer_code INTEGER NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE warehouse (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_code VARCHAR(10) NOT NULL UNIQUE,
    warehouse_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE shift (
    shift_code VARCHAR(2) PRIMARY KEY,     -- S1, S2, S3
    shift_name VARCHAR(20) NOT NULL,       -- 08:00-16:00 vb.
    start_time TIME NOT NULL,
    end_time TIME NOT NULL
);

CREATE TABLE date_dim (
    date_key INTEGER PRIMARY KEY,          -- 20260115 formatında
    full_date DATE NOT NULL UNIQUE,
    day INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    quarter INTEGER NOT NULL,
    year INTEGER NOT NULL,
    week_of_year INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE color (
    color_code VARCHAR(3) PRIMARY KEY,     -- BLK, WHT vb.
    color_name VARCHAR(30) NOT NULL
);

CREATE TABLE size (
    size_code VARCHAR(5) PRIMARY KEY,      -- XS, S, M, L, XL, XXL
    size_name VARCHAR(20) NOT NULL,
    size_order INTEGER NOT NULL            -- sıralama için (XS=1, S=2 vb.)
);

CREATE TABLE season (
    season_code VARCHAR(10) PRIMARY KEY,   -- SS25, FW25
    season_name VARCHAR(30) NOT NULL,      -- Spring/Summer 2025 vb.
    year INTEGER NOT NULL,
    season_type VARCHAR(2) NOT NULL        -- SS / FW
);

CREATE TABLE product (
    product_id SERIAL PRIMARY KEY,
    customer_code INTEGER NOT NULL,
    base_sku VARCHAR(20) NOT NULL,
    sku VARCHAR(50) NOT NULL UNIQUE,
    product_name VARCHAR(150) NOT NULL,
    color_code VARCHAR(3) NOT NULL,
    size_code VARCHAR(5) NOT NULL,
    season_code VARCHAR(10) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_product_customer
        FOREIGN KEY (customer_code) REFERENCES customer(customer_code),

    CONSTRAINT fk_product_color
        FOREIGN KEY (color_code) REFERENCES color(color_code),

    CONSTRAINT fk_product_size
        FOREIGN KEY (size_code) REFERENCES size(size_code),

    CONSTRAINT fk_product_season
        FOREIGN KEY (season_code) REFERENCES season(season_code)
);

CREATE TABLE dim_cancel_reason (
    reason_code VARCHAR(30) PRIMARY KEY,
    reason_description VARCHAR(150) NOT NULL,
    cancelled_by_party VARCHAR(3) NOT NULL CHECK (cancelled_by_party IN ('WH','CUS'))
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    order_no VARCHAR(30) NOT NULL UNIQUE,
    customer_code INTEGER NOT NULL,
    warehouse_code VARCHAR(10) NOT NULL,
    order_datetime TIMESTAMP NOT NULL,
    order_date DATE NOT NULL,  -- order_datetime'den türetilmiş (ETL/insert sırasında doldur)
    order_type VARCHAR(3) NOT NULL CHECK (order_type IN ('SO','RET','SPL')),
    order_status VARCHAR(10) NOT NULL CHECK (order_status IN ('Created','Picked','Shipped','Cancelled')),
    total_line_count INTEGER NOT NULL DEFAULT 0,
    total_quantity INTEGER NOT NULL DEFAULT 0,
    priority_flag VARCHAR(10) NOT NULL CHECK (priority_flag IN ('Normal','High','VIP')),
    shift_code VARCHAR(2) NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_code) REFERENCES customer(customer_code),

    CONSTRAINT fk_orders_warehouse
        FOREIGN KEY (warehouse_code) REFERENCES warehouse(warehouse_code),

    CONSTRAINT fk_orders_shift
        FOREIGN KEY (shift_code) REFERENCES shift(shift_code),

    CONSTRAINT fk_orders_date
        FOREIGN KEY (order_date) REFERENCES date_dim(full_date)
		
);

CREATE TABLE order_line (
    order_line_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    line_no INTEGER NOT NULL,
    sku VARCHAR(50) NOT NULL,
    line_type VARCHAR(3) NOT NULL CHECK (line_type IN ('SO','RET','SPL')),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    line_total_amount NUMERIC(14,2) NOT NULL CHECK (line_total_amount >= 0),

    CONSTRAINT fk_order_line_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),

    CONSTRAINT fk_order_line_product
        FOREIGN KEY (sku) REFERENCES product(sku),

    CONSTRAINT uq_order_line_order_line
        UNIQUE (order_id, line_no)
);

CREATE TABLE order_cancel (
    cancel_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL UNIQUE,  -- 1 order = 1 cancel
    cancelled_at TIMESTAMP NOT NULL,
    cancel_reason_code VARCHAR(30) NOT NULL,

    CONSTRAINT fk_order_cancel_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),

    CONSTRAINT fk_order_cancel_reason
        FOREIGN KEY (cancel_reason_code) REFERENCES dim_cancel_reason(reason_code)
);

CREATE TABLE fact_workforce (
    work_date DATE NOT NULL,
    customer_code INTEGER NOT NULL,
    warehouse_code VARCHAR(10) NOT NULL,
    shift_code VARCHAR(2) NOT NULL,

    worker_count INTEGER NOT NULL CHECK (worker_count >= 0),
    office_count INTEGER NOT NULL CHECK (office_count >= 0),
    total_employee INTEGER NOT NULL CHECK (total_employee >= 0),

    receiving_staff INTEGER NOT NULL CHECK (receiving_staff >= 0),
    picking_staff INTEGER NOT NULL CHECK (picking_staff >= 0),
    packing_staff INTEGER NOT NULL CHECK (packing_staff >= 0),
    shipping_staff INTEGER NOT NULL CHECK (shipping_staff >= 0),

    CONSTRAINT pk_fact_workforce 
        PRIMARY KEY (work_date, customer_code, warehouse_code, shift_code),

    CONSTRAINT fk_fw_customer
        FOREIGN KEY (customer_code) REFERENCES customer(customer_code),

    CONSTRAINT fk_fw_warehouse
        FOREIGN KEY (warehouse_code) REFERENCES warehouse(warehouse_code),

    CONSTRAINT fk_fw_shift
        FOREIGN KEY (shift_code) REFERENCES shift(shift_code),

    CONSTRAINT fk_fw_date
        FOREIGN KEY (work_date) REFERENCES date_dim(full_date)
);

ALTER TABLE fact_workforce
ADD CONSTRAINT chk_total_employee
CHECK (total_employee = worker_count + office_count);

ALTER TABLE fact_workforce
ADD CONSTRAINT chk_staff_distribution
CHECK (receiving_staff + picking_staff + packing_staff + shipping_staff <= worker_count);

CREATE TABLE inbound_receipt (
    receipt_id SERIAL PRIMARY KEY,
    receipt_no VARCHAR(30) NOT NULL UNIQUE,
    customer_code INTEGER NOT NULL,
    warehouse_code VARCHAR(10) NOT NULL,
    receipt_datetime TIMESTAMP NOT NULL,
    receipt_date DATE NOT NULL,
    shift_code VARCHAR(2) NOT NULL,
    receipt_status VARCHAR(10) NOT NULL CHECK (receipt_status IN ('Created','Received','Cancelled')),

    CONSTRAINT fk_inb_customer
        FOREIGN KEY (customer_code) REFERENCES customer(customer_code),

    CONSTRAINT fk_inb_warehouse
        FOREIGN KEY (warehouse_code) REFERENCES warehouse(warehouse_code),

    CONSTRAINT fk_inb_shift
        FOREIGN KEY (shift_code) REFERENCES shift(shift_code),

    CONSTRAINT fk_inb_date
        FOREIGN KEY (receipt_date) REFERENCES date_dim(full_date)
);

CREATE TABLE inbound_receipt_line (
    receipt_line_id SERIAL PRIMARY KEY,
    receipt_id INTEGER NOT NULL,
    line_no INTEGER NOT NULL,
    sku VARCHAR(50) NOT NULL,
    quantity_received INTEGER NOT NULL CHECK (quantity_received > 0),

    CONSTRAINT fk_inb_line_receipt
        FOREIGN KEY (receipt_id) REFERENCES inbound_receipt(receipt_id),

    CONSTRAINT fk_inb_line_product
        FOREIGN KEY (sku) REFERENCES product(sku),

    CONSTRAINT uq_inb_line
        UNIQUE (receipt_id, line_no)
);

ALTER TABLE fact_workforce
ADD COLUMN planned_hours NUMERIC(4,2) NOT NULL DEFAULT 8,
ADD COLUMN break_hours NUMERIC(4,2) NOT NULL DEFAULT 2,
ADD COLUMN effective_hours NUMERIC(4,2) NOT NULL DEFAULT 6,
ADD COLUMN absent_count INTEGER NOT NULL DEFAULT 0 CHECK (absent_count >= 0);


ALTER TABLE fact_workforce
ADD CONSTRAINT chk_effective_hours
CHECK (effective_hours = planned_hours - break_hours);

  -- Records--

  INSERT INTO customer (customer_code, customer_name)
VALUES
(101, 'JLO'),
(102, 'KRODA'),
(103, 'POLINS');

INSERT INTO warehouse (warehouse_code, warehouse_name)
VALUES
('A', 'A Warehouse'),
('B', 'B Warehouse'),
('C', 'C Warehouse');

INSERT INTO shift (shift_code, shift_name, start_time, end_time)
VALUES
('S1', '08:00-16:00', '08:00', '16:00'),
('S2', '16:00-00:00', '16:00', '00:00'),
('S3', '00:00-08:00', '00:00', '08:00');

INSERT INTO color (color_code, color_name)
VALUES
('BLK', 'Black'),
('WHT', 'White'),
('GRY', 'Grey'),
('NAV', 'Navy'),
('BLU', 'Blue'),
('RED', 'Red');

INSERT INTO size (size_code, size_name, size_order)
VALUES
('XS', 'Extra Small', 1),
('S',  'Small',       2),
('M',  'Medium',      3),
('L',  'Large',       4),
('XL', 'Extra Large', 5),
('XXL','Double XL',   6);

INSERT INTO season (season_code, season_name, year, season_type)
VALUES
('SS25', 'Spring/Summer 2025', 2025, 'SS'),
('FW25', 'Fall/Winter 2025', 2025, 'FW');

INSERT INTO dim_cancel_reason (reason_code, reason_description, cancelled_by_party)
VALUES
-- Warehouse Reasons
('DAMAGE', 'Ürün hasarlı', 'WH'),
('STOCK_OUT', 'Stok yetersiz', 'WH'),
('WRONG_PICK', 'Yanlış ürün toplanmış', 'WH'),
('QC_FAIL', 'Kalite kontrolden geçmedi', 'WH'),
('SYSTEM_ERROR', 'Sistemsel hata', 'WH'),
('PACKING_ERROR', 'Paketleme hatası', 'WH'),

-- Customer Reasons
('PRICE_ERROR', 'Fiyat hatası', 'CUS'),
('ORDER_MISTAKE', 'Yanlış sipariş verilmiş', 'CUS'),
('DUPLICATE_ORDER', 'Mükerrer sipariş', 'CUS'),
('DELAY_NOT_ACCEPTED', 'Gecikme kabul edilmedi', 'CUS'),
('PAYMENT_ISSUE', 'Ödeme problemi', 'CUS');


WITH base_products AS (
    SELECT 101 AS customer_code, '101TSH01' AS base_sku, 'Basic T-Shirt'     AS product_name UNION ALL
    SELECT 101,                  '101TSH02',             'Oversize T-Shirt'  UNION ALL
    SELECT 101,                  '101SWT01',             'Hoodie Sweatshirt' UNION ALL
    SELECT 101,                  '101JEA01',             'Slim Fit Jean'     UNION ALL
    SELECT 101,                  '101MNT01',             'Winter Jacket'     UNION ALL
    SELECT 101,                  '101MNT02',             'Puffer Coat'       UNION ALL
    SELECT 101,                  '101SRT01',             'Casual Shirt'      UNION ALL
    SELECT 101,                  '101TRS01',             'Jogger Pants'
)
INSERT INTO product (
    customer_code, base_sku, sku, product_name,
    color_code, size_code, season_code
)
SELECT
    bp.customer_code,
    bp.base_sku,
    (bp.base_sku || c.color_code || s.size_code || se.season_code) AS sku,
    bp.product_name,
    c.color_code,
    s.size_code,
    se.season_code
FROM base_products bp
CROSS JOIN color c
CROSS JOIN size s
CROSS JOIN season se;

SELECT * FROM product WHERE customer_code = 101;

WITH base_products AS (
    SELECT 102 AS customer_code, '102HDP01' AS base_sku, 'Bluetooth Headphone'   AS product_name UNION ALL
    SELECT 102,                  '102PWB01',             'Powerbank 10000mAh'     UNION ALL
    SELECT 102,                  '102LTP01',             'Laptop 15"'             UNION ALL
    SELECT 102,                  '102TBL01',             'Tablet 10"'             UNION ALL
    SELECT 102,                  '102ROU01',             'WiFi Router'            UNION ALL
    SELECT 102,                  '102KBD01',             'Wireless Keyboard'      UNION ALL
    SELECT 102,                  '102MSE01',             'Optical Mouse'          UNION ALL
    SELECT 102,                  '102SPK01',             'Portable Speaker'
)
INSERT INTO product (
    customer_code, base_sku, sku, product_name,
    color_code, size_code, season_code
)
SELECT
    bp.customer_code,
    bp.base_sku,
    (bp.base_sku || 'BLK' || 'M' || 'SS25') AS sku,
    bp.product_name,
    'BLK'  AS color_code,
    'M'    AS size_code,
    'SS25' AS season_code
FROM base_products bp;

WITH base_products AS (
    SELECT 103 AS customer_code, '103AYN01' AS base_sku, 'Wall Mirror'          AS product_name UNION ALL
    SELECT 103,                  '103CER01',             'Photo Frame'          UNION ALL
    SELECT 103,                  '103LMP01',             'Table Lamp'           UNION ALL
    SELECT 103,                  '103SAT01',             'Wall Clock'           UNION ALL
    SELECT 103,                  '103OBJ01',             'Decorative Vase'      UNION ALL
    SELECT 103,                  '103CND01',             'Scented Candle'       UNION ALL
    SELECT 103,                  '103RUG01',             'Small Rug'            UNION ALL
    SELECT 103,                  '103PLT01',             'Decorative Plant'
)

INSERT INTO product (
    customer_code, base_sku, sku, product_name,
    color_code, size_code, season_code
)
SELECT
    bp.customer_code,
    bp.base_sku,
    (bp.base_sku || 'WHT' || 'M' || 'SS25') AS sku,
    bp.product_name,
    'WHT'  AS color_code,
    'M'    AS size_code,
    'SS25' AS season_code
FROM base_products bp;

INSERT INTO date_dim (
  date_key, full_date, day, month, month_name, quarter, year,
  week_of_year, day_of_week, day_name, is_weekend
)
SELECT
  to_char(d, 'YYYYMMDD')::int AS date_key,
  d::date AS full_date,
  EXTRACT(DAY FROM d)::int AS day,
  EXTRACT(MONTH FROM d)::int AS month,
  to_char(d, 'FMMonth') AS month_name,
  EXTRACT(QUARTER FROM d)::int AS quarter,
  EXTRACT(YEAR FROM d)::int AS year,
  EXTRACT(WEEK FROM d)::int AS week_of_year,
  EXTRACT(ISODOW FROM d)::int AS day_of_week,
  to_char(d, 'FMDay') AS day_name,
  (EXTRACT(ISODOW FROM d) IN (6,7)) AS is_weekend
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') d
ON CONFLICT (full_date) DO NOTHING;


---

CREATE INDEX ix_orders_date        ON orders(order_date);
CREATE INDEX ix_orders_customer    ON orders(customer_code);
CREATE INDEX ix_orders_wh          ON orders(warehouse_code);
CREATE INDEX ix_orders_cus_wh_date ON orders(customer_code, warehouse_code, order_date);

CREATE INDEX ix_order_line_orderid ON order_line(order_id);
CREATE INDEX ix_order_line_sku     ON order_line(sku);

CREATE INDEX ix_fw_date_cus_wh     ON fact_workforce(work_date, customer_code, warehouse_code, shift_code);


--- S4 : shift '08:00-17:00'

INSERT INTO shift (shift_code, shift_name, start_time, end_time)
VALUES ('S4', '08:00-17:00', '08:00', '17:00')
ON CONFLICT (shift_code) DO NOTHING;

--


INSERT INTO fact_workforce (
  work_date, customer_code, warehouse_code, shift_code,
  worker_count, office_count, total_employee,
  receiving_staff, picking_staff, packing_staff, shipping_staff
)
VALUES
-- JLO / A
('2025-01-15', 101, 'A', 'S1', 180, 2, 182, 36, 81, 45, 18),
('2025-01-15', 101, 'A', 'S2', 172, 1, 173, 34, 78, 43, 17),
('2025-01-15', 101, 'A', 'S3', 156, 1, 157, 31, 70, 39, 16),

-- JLO / B
('2025-01-15', 101, 'B', 'S1', 165, 2, 167, 33, 75, 41, 16),
('2025-01-15', 101, 'B', 'S2', 170, 1, 171, 34, 77, 42, 17),
('2025-01-15', 101, 'B', 'S3', 158, 1, 159, 32, 72, 39, 15),

-- KRODA / B (08:00-17:00)
('2025-01-15', 102, 'B', 'S4', 60, 2, 62, 12, 27, 15, 6),

-- POLINS / A
('2025-01-15', 103, 'A', 'S1', 210, 2, 212, 42, 94, 53, 21),
('2025-01-15', 103, 'A', 'S2', 186, 1, 187, 37, 83, 47, 19),
('2025-01-15', 103, 'A', 'S3', 175, 1, 176, 35, 79, 43, 18),

-- POLINS / B
('2025-01-15', 103, 'B', 'S1', 142, 2, 144, 28, 64, 36, 14),
('2025-01-15', 103, 'B', 'S2', 150, 1, 151, 29, 68, 38, 15),
('2025-01-15', 103, 'B', 'S3', 139, 1, 140, 28, 63, 34, 14),

-- POLINS / C
('2025-01-15', 103, 'C', 'S1', 240, 2, 242, 48, 108, 60, 24),
('2025-01-15', 103, 'C', 'S2', 196, 1, 197, 39, 88, 49, 20),
('2025-01-15', 103, 'C', 'S3', 187, 1, 188, 37, 84, 47, 19)
ON CONFLICT (work_date, customer_code, warehouse_code, shift_code) DO NOTHING;


-----------------
SELECT * FROM order_cancel;
-----
WITH params AS (
  SELECT 6.5::numeric AS effective_hours, 0.10::numeric AS absence_rate,   6::numeric AS base_orders_per_8h 
)
SELECT
  SUM(ROUND(fw.picking_staff * (p.base_orders_per_8h * (p.effective_hours/8.0) * (1-p.absence_rate))))::bigint AS expected_orders
FROM fact_workforce fw
CROSS JOIN params p
WHERE fw.work_date BETWEEN '2025-01-01' AND '2025-12-31';

---





SELECT order_id, customer_code, order_status, order_datetime
FROM public.orders
WHERE customer_code IN (101,102,103)
  AND order_status <> 'Shipped'
ORDER BY order_datetime DESC
LIMIT 200;



-- 1) Oranlar
WITH rates AS (
  SELECT 101::int AS customer_code, 0.02::numeric AS rate  -- JLO
  UNION ALL SELECT 102, 0.05                               -- KRODA
  UNION ALL SELECT 103, 0.10                               -- POLINS
),

-- 2) İptale aday (Shipped hariç, zaten Cancelled olan hariç, order_cancel’a düşmüş olan hariç)
eligible AS (
  SELECT o.order_id, o.customer_code, o.order_status, o.order_datetime
  FROM public.orders o
  WHERE o.order_status IN ('Created','Pending','Picked')
    AND NOT EXISTS (
      SELECT 1 FROM public.order_cancel oc WHERE oc.order_id = o.order_id
    )
),

-- 3) Müşteri bazında rastgele sırala + adet hesapla
ranked AS (
  SELECT
    e.*,
    ROW_NUMBER() OVER (PARTITION BY e.customer_code ORDER BY random()) AS rn,
    COUNT(*)    OVER (PARTITION BY e.customer_code) AS cnt
  FROM eligible e
),

-- 4) Oran kadar seç
to_cancel AS (
  SELECT r.order_id, r.customer_code, r.order_datetime
  FROM ranked r
  JOIN rates  t USING (customer_code)
  WHERE r.rn <= CEIL(r.cnt * t.rate)
),

-- 5) Her seçilen order’a WH/CUS (%60/%40) ata
party_assigned AS (
  SELECT
    tc.*,
    CASE WHEN random() < 0.60 THEN 'WH' ELSE 'CUS' END AS cancelled_by_party,
    ROW_NUMBER() OVER (ORDER BY random()) AS seq
  FROM to_cancel tc
),

-- 6) Party’ye uygun reason seç (karışık + dengeli)
reason_picked AS (
  SELECT
    p.order_id,
    p.order_datetime,
    (
      SELECT d.reason_code
      FROM public.dim_cancel_reason d
      WHERE d.cancelled_by_party = p.cancelled_by_party
      ORDER BY md5(p.order_id::text || '-' || d.reason_code)  -- deterministic karışım
      LIMIT 1
    ) AS cancel_reason_code
  FROM party_assigned p
),

-- 7) order_cancel insert
ins AS (
  INSERT INTO public.order_cancel (order_id, cancelled_at, cancel_reason_code)
  SELECT
    rp.order_id,
    rp.order_datetime + (interval '1 minute' * (5 + floor(random()*120))) AS cancelled_at,
    rp.cancel_reason_code
  FROM reason_picked rp
  WHERE NOT EXISTS (SELECT 1 FROM public.order_cancel oc WHERE oc.order_id = rp.order_id)
  RETURNING order_id
)

-- 8) orders status update
UPDATE public.orders o
SET order_status = 'Cancelled'
WHERE o.order_id IN (SELECT order_id FROM ins);


select * from order_cancel;

---------
-- Müşteri bazında kaç iptal üretildi?
SELECT o.customer_code, COUNT(*) AS cancelled_cnt
FROM public.orders o
WHERE o.order_status = 'Cancelled'
GROUP BY 1
ORDER BY 1;

-- WH / CUS dağılımı (dim üzerinden okunur)
SELECT d.cancelled_by_party, COUNT(*) cnt
FROM public.order_cancel oc
JOIN public.dim_cancel_reason d ON d.reason_code = oc.cancel_reason_code
GROUP BY 1;

-- Shipped iptal edilmiş mi? (0 gelmeli)
SELECT COUNT(*) shipped_cancelled
FROM public.orders
WHERE order_status='Cancelled' AND order_id IN (
  SELECT order_id FROM public.orders WHERE order_status='Shipped'
);


--Inventory

WITH cw AS (
  SELECT * FROM (VALUES
    (101,'A'), (101,'B'),
    (102,'B'),
    (103,'A'), (103,'B'), (103,'C')
  ) v(customer_code, warehouse_code)
),
ins AS (
  SELECT
    cw.customer_code,
    cw.warehouse_code,
    p.sku,
    ROW_NUMBER() OVER (PARTITION BY cw.customer_code, cw.warehouse_code ORDER BY random()) rn
  FROM cw
  JOIN public.product p
    ON p.customer_code = cw.customer_code
)
INSERT INTO fact_stock
(as_of_date, customer_code, warehouse_code, sku, saleable_qty, damaged_qty)
SELECT
  DATE '2025-12-31',
  customer_code,
  warehouse_code,
  sku,
  (100 + floor(random()*21))::int,  -- 100-120
  (floor(random()*5))::int          -- 0-4 damage
FROM ins
WHERE rn <= 100
ON CONFLICT DO NOTHING;


--UPDATE receipt date(1 year)

WITH numbered AS (
    SELECT 
        receipt_id,
        ROW_NUMBER() OVER (ORDER BY receipt_id) - 1 AS rn
    FROM inbound_receipt
),
dates AS (
    SELECT 
        DATE '2025-01-01' + (rn % 365)::int AS new_date,
        CASE 
            WHEN (rn % 3) = 0 THEN TIME '08:00:00'
            WHEN (rn % 3) = 1 THEN TIME '16:00:00'
            ELSE TIME '00:00:00'
        END AS shift_time,
        receipt_id
    FROM numbered
)
UPDATE inbound_receipt ir
SET receipt_datetime = d.new_date + d.shift_time
FROM dates d
WHERE ir.receipt_id = d.receipt_id;





--employee identy

CREATE TABLE IF NOT EXISTS dim_employee (
  employee_id   SERIAL PRIMARY KEY,
  employee_code VARCHAR(50) UNIQUE NOT NULL,
  employee_type VARCHAR(10) NOT NULL CHECK (employee_type IN ('Worker','Office')),
  warehouse_code VARCHAR(10) NOT NULL,
  customer_code  INTEGER NOT NULL,
  shift_code     VARCHAR(2) NOT NULL,
  is_active     BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS fact_employee_attendance (
  work_date      DATE NOT NULL,
  warehouse_code VARCHAR(10) NOT NULL,
  customer_code  INTEGER NOT NULL,
  shift_code     VARCHAR(2) NOT NULL,
  employee_id    INT  NOT NULL,
  is_absent      BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (work_date, warehouse_code, customer_code, shift_code, employee_id),
  FOREIGN KEY (employee_id) REFERENCES dim_employee(employee_id)
);




WITH params AS (
  SELECT DATE '2025-01-15' AS ref_date
),
base AS (
  SELECT
    fw.customer_code,
    fw.warehouse_code,
    fw.shift_code,
    fw.worker_count,
    fw.office_count
  FROM public.fact_workforce fw
  JOIN params p ON fw.work_date = p.ref_date
),
office_rows AS (
  SELECT
    b.customer_code, b.warehouse_code, b.shift_code,
    'O-' || b.customer_code || '-' || b.warehouse_code || '-' || b.shift_code || '-' || gs::text AS employee_code,
    'Office'::text AS employee_type
  FROM base b
  JOIN LATERAL generate_series(1, b.office_count) gs ON TRUE
),
worker_rows AS (
  SELECT
    b.customer_code, b.warehouse_code, b.shift_code,
    'W-' || b.customer_code || '-' || b.warehouse_code || '-' || b.shift_code || '-' || gs::text AS employee_code,
    'Worker'::text AS employee_type
  FROM base b
  JOIN LATERAL generate_series(1, b.worker_count) gs ON TRUE
),
all_rows AS (
  SELECT * FROM office_rows
  UNION ALL
  SELECT * FROM worker_rows
)
INSERT INTO dim_employee (employee_code, employee_type, warehouse_code, customer_code, shift_code)
SELECT employee_code, employee_type, warehouse_code, customer_code, shift_code
FROM all_rows
ON CONFLICT (employee_code) DO NOTHING;






WITH params AS (
  SELECT DATE '2025-01-01' AS d1, DATE '2025-12-31' AS d2
),
dates AS (
  SELECT d::date AS work_date
  FROM generate_series((SELECT d1 FROM params), (SELECT d2 FROM params), interval '1 day') d
)
INSERT INTO fact_employee_attendance (work_date, warehouse_code, customer_code, shift_code, employee_id, is_absent)
SELECT
  dt.work_date,
  e.warehouse_code,
  e.customer_code,
  e.shift_code,
  e.employee_id,
  FALSE AS is_absent
FROM dates dt
JOIN dim_employee e ON TRUE
ON CONFLICT DO NOTHING;


SELECT warehouse_code, shift_code, COUNT(*) AS headcount
FROM fact_employee_attendance
WHERE work_date = '2025-03-08'
GROUP BY 1,2
ORDER BY 1,2;



SELECT warehouse_code, shift_code, COUNT(*) AS headcount
FROM fact_employee_attendance
WHERE work_date = '2025-11-20'
GROUP BY 1,2
ORDER BY 1,2;





SELECT DISTINCT employee_id
FROM public.fact_employee_attendance
ORDER BY 1;




SELECT *
FROM order_cancel;


SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('orders','order_cancel','dim_cancel_reason')
ORDER BY table_name, ordinal_position;

SELECT reason_code FROM public.dim_cancel_reason;

SELECT customer_code, COUNT(*) FROM public.orders GROUP BY 1 ORDER BY 2 DESC;



SELECT COUNT(*) AS total_cancel_orders
FROM public.order_cancel;
-- Aynı order_id birden fazla kez varsa gör:
SELECT order_id, COUNT(*)
FROM public.order_cancel
GROUP BY order_id
HAVING COUNT(*) > 1;


CREATE UNIQUE INDEX IF NOT EXISTS ux_order_cancel_order_id
ON order_cancel(order_id);

----------------------------------------------
SELECT
  o.customer_code,
  COUNT(*) FILTER (WHERE oc.order_id IS NOT NULL) AS cancel_count,
  COUNT(*) AS order_count,
  ROUND(
    (COUNT(*) FILTER (WHERE oc.order_id IS NOT NULL))::numeric
    / NULLIF(COUNT(*), 0),
    4
  ) AS cancel_rate
FROM public.orders o
LEFT JOIN public.order_cancel oc
  ON oc.order_id = o.order_id
GROUP BY o.customer_code
ORDER BY cancel_rate DESC, order_count DESC;
-----------------------------------------------------------


WITH target_rates AS (
    SELECT 103 AS customer_code, 0.06::numeric AS target_rate
    UNION ALL
    SELECT 102, 0.04
    UNION ALL
    SELECT 101, 0.08
),

base AS (
    SELECT
        o.customer_code,
        COUNT(*) AS order_count,
        COUNT(*) FILTER (WHERE oc.order_id IS NOT NULL) AS cancel_count
    FROM orders o
    LEFT JOIN order_cancel oc ON oc.order_id = o.order_id
    GROUP BY o.customer_code
),

need AS (
    SELECT
        b.customer_code,
        CEIL(b.order_count * t.target_rate)::int AS target_cancel,
        b.cancel_count,
        GREATEST(
            0,
            CEIL(b.order_count * t.target_rate)::int - b.cancel_count
        ) AS add_needed
    FROM base b
    JOIN target_rates t ON t.customer_code = b.customer_code
),

candidates AS (
    SELECT
        o.order_id,
        o.order_datetime,
        o.customer_code,
        n.add_needed,
        ROW_NUMBER() OVER (PARTITION BY o.customer_code ORDER BY RANDOM()) AS rn
    FROM orders o
    JOIN need n ON n.customer_code = o.customer_code
    LEFT JOIN order_cancel oc ON oc.order_id = o.order_id
    WHERE oc.order_id IS NULL
),

picked AS (
    SELECT *
    FROM candidates
    WHERE rn <= add_needed
),

reason_pool AS (
    SELECT ARRAY_AGG(reason_code) AS reasons
    FROM dim_cancel_reason
)

INSERT INTO order_cancel (order_id, cancelled_at, cancel_reason_code)
SELECT
    p.order_id,
    p.order_datetime + (RANDOM() * INTERVAL '1 day'),
    rp.reasons[1 + FLOOR(RANDOM() * ARRAY_LENGTH(rp.reasons,1))::int]
FROM picked p
CROSS JOIN reason_pool rp;






UPDATE orders o
SET order_status = 'CANCELLED'
WHERE EXISTS (
    SELECT 1 FROM order_cancel oc
    WHERE oc.order_id = o.order_id
);









-- ORDERS INSERT

WITH params AS (
  SELECT
    '2025-01-01'::date AS d1,
    '2025-12-31'::date AS d2,
    6.5::numeric  AS effective_hours,
    0.10::numeric AS absence_rate,
    6::numeric    AS base_orders_per_8h
),

plan AS (
  SELECT
    fw.work_date,
    fw.customer_code,
    fw.warehouse_code,
    fw.shift_code,
    GREATEST(
      0,
      ROUND(
        fw.picking_staff *
        (p.base_orders_per_8h * (p.effective_hours / 8.0) * (1 - p.absence_rate))
      )
    )::int AS order_cnt
  FROM fact_workforce fw
  CROSS JOIN params p
  WHERE fw.work_date BETWEEN p.d1 AND p.d2
)

INSERT INTO orders (
  order_no, customer_code, warehouse_code,
  order_datetime, order_date,
  order_type, order_status,
  total_line_count, total_quantity,
  priority_flag, shift_code
)
SELECT
  'ORD-' || to_char(pl.work_date, 'YYYYMMDD') || '-' ||
    pl.customer_code || '-' || pl.warehouse_code || '-' || pl.shift_code || '-' ||
    gs::text AS order_no,

  pl.customer_code,
  pl.warehouse_code,

  (pl.work_date::timestamp
    + CASE pl.shift_code
        WHEN 'S1' THEN time '08:00'
        WHEN 'S2' THEN time '16:00'
        WHEN 'S3' THEN time '00:00'
        ELSE time '08:00'
      END
    + make_interval(mins => (gs % 390))
  ) AS order_datetime,

  pl.work_date,

  CASE WHEN (gs % 100) < 88 THEN 'SO'
       WHEN (gs % 100) < 98 THEN 'RET'
       ELSE 'SPL' END,

  CASE WHEN (gs % 100) < 90 THEN 'Shipped'
       WHEN (gs % 100) < 94 THEN 'Cancelled'
       WHEN (gs % 100) < 98 THEN 'Picked'
       ELSE 'Created' END,

  0, 0,

  CASE WHEN (gs % 100) < 85 THEN 'Normal'
       WHEN (gs % 100) < 97 THEN 'High'
       ELSE 'VIP' END,

  pl.shift_code

FROM plan pl
JOIN LATERAL generate_series(1, pl.order_cnt) gs ON TRUE
ON CONFLICT (order_no) DO NOTHING;

---control order count

SELECT COUNT(*) 
FROM orders
WHERE order_date BETWEEN '2025-01-01' AND '2025-12-31';

---

-- ORDER_LINE INSERT

INSERT INTO order_line (
  order_id, line_no, sku, line_type,
  quantity, unit_price, line_total_amount
)
SELECT
  o.order_id,
  ln AS line_no,

  pr.sku,
  'SO',

  qty,
  price,
  ROUND(qty * price, 2)

FROM orders o

JOIN LATERAL (
  SELECT (1 + (abs(hashtext(o.order_no)) % 2))::int AS line_cnt
) lc ON TRUE

JOIN LATERAL generate_series(1, lc.line_cnt) ln ON TRUE

JOIN LATERAL (
  SELECT sku
  FROM product
  WHERE customer_code = o.customer_code
  ORDER BY random()
  LIMIT 1
) pr ON TRUE

JOIN LATERAL (
  SELECT
    (1 + (abs(hashtext(o.order_no || '-' || ln::text)) % 3))::int AS qty,
    (10 + (abs(hashtext('P' || o.order_no || '-' || ln::text)) % 200))::numeric(12,2) AS price
) qp ON TRUE

WHERE o.order_date BETWEEN '2025-01-01' AND '2025-12-31';

--control count order line

SELECT COUNT(*) FROM order_line;
---

UPDATE orders o
SET
  total_line_count = x.line_cnt,
  total_quantity   = x.qty_sum
FROM (
  SELECT
    order_id,
    COUNT(*) AS line_cnt,
    SUM(quantity) AS qty_sum
  FROM order_line
  GROUP BY order_id
) x
WHERE o.order_id = x.order_id
AND o.order_date BETWEEN '2025-01-01' AND '2025-12-31';


-- INBOUND_RECEIPT INSERT (1 year)

WITH params AS (
  SELECT
    '2025-01-01'::date AS d1,
    '2025-12-31'::date AS d2,
    6.5::numeric  AS effective_hours,
    0.10::numeric AS absence_rate,
    4::numeric    AS base_receipts_per_8h
),
plan AS (
  SELECT
    fw.work_date,
    fw.customer_code,
    fw.warehouse_code,
    fw.shift_code,
    GREATEST(
      0,
      ROUND(
        fw.receiving_staff *
        (p.base_receipts_per_8h * (p.effective_hours/8.0) * (1 - p.absence_rate))
      )
    )::int AS receipt_cnt
  FROM fact_workforce fw
  CROSS JOIN params p
  WHERE fw.work_date BETWEEN p.d1 AND p.d2
)
INSERT INTO inbound_receipt (
  receipt_no, customer_code, warehouse_code,
  receipt_datetime, receipt_date,
  shift_code, receipt_status
)
SELECT
  'RCV-' || to_char(pl.work_date, 'YYYYMMDD') || '-' ||
  pl.customer_code || '-' || pl.warehouse_code || '-' || pl.shift_code || '-' ||
  gs::text AS receipt_no,

  pl.customer_code,
  pl.warehouse_code,

  (pl.work_date::timestamp
    + CASE pl.shift_code
        WHEN 'S1' THEN time '08:00'
        WHEN 'S2' THEN time '16:00'
        WHEN 'S3' THEN time '00:00'
        ELSE time '08:00'
      END
    + make_interval(mins => (gs % 390))  -- 6.5 saat = 390 dk içine dağıt
  ) AS receipt_datetime,

  pl.work_date AS receipt_date,
  pl.shift_code,

  CASE
    WHEN (gs % 100) < 92 THEN 'Received'
    WHEN (gs % 100) < 97 THEN 'Created'
    ELSE 'Cancelled'
  END AS receipt_status

FROM plan pl
JOIN LATERAL generate_series(1, pl.receipt_cnt) gs ON TRUE
ON CONFLICT (receipt_no) DO NOTHING;

--control inbound receipt

SELECT COUNT(*)
FROM inbound_receipt
WHERE receipt_date BETWEEN '2025-01-01' AND '2025-12-31';

--  INBOUND_RECEIPT_LINE INSERT

INSERT INTO inbound_receipt_line (
  receipt_id, line_no, sku, quantity_received
)
SELECT
  r.receipt_id,
  ln AS line_no,
  pr.sku,
  qty AS quantity_received
FROM inbound_receipt r

-- her receipt'e 1-3 line
JOIN LATERAL (
  SELECT (1 + (abs(hashtext(r.receipt_no)) % 3))::int AS line_cnt
) lc ON TRUE
JOIN LATERAL generate_series(1, lc.line_cnt) ln ON TRUE

-- customer’ın ürünlerinden rastgele SKU
JOIN LATERAL (
  SELECT sku
  FROM product
  WHERE customer_code = r.customer_code
  ORDER BY random()
  LIMIT 1
) pr ON TRUE

-- qty (1-10 arası)
JOIN LATERAL (
  SELECT (1 + (abs(hashtext(r.receipt_no || '-' || ln::text)) % 10))::int AS qty
) q ON TRUE

WHERE r.receipt_date BETWEEN '2025-01-01' AND '2025-12-31'
ON CONFLICT (receipt_id, line_no) DO NOTHING;


-----------------------


CREATE INDEX IF NOT EXISTS ix_inb_receipt_date     ON inbound_receipt(receipt_date);
CREATE INDEX IF NOT EXISTS ix_inb_receipt_customer ON inbound_receipt(customer_code);
CREATE INDEX IF NOT EXISTS ix_inb_receipt_wh       ON inbound_receipt(warehouse_code);

CREATE INDEX IF NOT EXISTS ix_inb_line_receiptid   ON inbound_receipt_line(receipt_id);
CREATE INDEX IF NOT EXISTS ix_inb_line_sku         ON inbound_receipt_line(sku);

----------------


--  INBOUND_RECEIPT INSERT (2025 full year)

WITH params AS (
  SELECT
    '2025-01-01'::date AS d1,
    '2025-12-31'::date AS d2,
    6.5::numeric  AS effective_hours,
    0.10::numeric AS absence_rate,
    4::numeric    AS base_receipts_per_8h
),

plan AS (
  SELECT
    fw.work_date,
    fw.customer_code,
    fw.warehouse_code,
    fw.shift_code,

    GREATEST(
      0,
      ROUND(
        fw.receiving_staff *
        (p.base_receipts_per_8h * (p.effective_hours/8.0) * (1 - p.absence_rate))
      )
    )::int AS receipt_cnt

  FROM fact_workforce fw
  CROSS JOIN params p
  WHERE fw.work_date BETWEEN p.d1 AND p.d2
)

INSERT INTO inbound_receipt (
  receipt_no,
  customer_code,
  warehouse_code,
  receipt_datetime,
  receipt_date,
  shift_code,
  receipt_status
)

SELECT
  'RCV-' || to_char(pl.work_date,'YYYYMMDD') || '-' ||
  pl.customer_code || '-' || pl.warehouse_code || '-' || pl.shift_code || '-' ||
  gs::text AS receipt_no,

  pl.customer_code,
  pl.warehouse_code,

  (
    pl.work_date::timestamp
    + CASE pl.shift_code
        WHEN 'S1' THEN time '08:00'
        WHEN 'S2' THEN time '16:00'
        WHEN 'S3' THEN time '00:00'
        WHEN 'S4' THEN time '08:00'
      END
    + make_interval(mins => (gs % 390))
  ) AS receipt_datetime,

  pl.work_date,
  pl.shift_code,

  CASE
    WHEN (gs % 100) < 92 THEN 'Received'
    WHEN (gs % 100) < 97 THEN 'Created'
    ELSE 'Cancelled'
  END

FROM plan pl
JOIN LATERAL generate_series(1, pl.receipt_cnt) gs ON TRUE
ON CONFLICT (receipt_no) DO NOTHING;

----Control 

SELECT COUNT(*)
FROM inbound_receipt
WHERE receipt_date BETWEEN '2025-01-01' AND '2025-12-31';


---

--  INBOUND_RECEIPT_LINE INSERT (1–3 line / receipt)

INSERT INTO inbound_receipt_line (
  receipt_id,
  line_no,
  sku,
  quantity_received
)
SELECT
  r.receipt_id,
  ln AS line_no,

  pr.sku,

  qty AS quantity_received

FROM inbound_receipt r

-- her receipt'e 1-3 line
JOIN LATERAL (
  SELECT (1 + (abs(hashtext(r.receipt_no)) % 3))::int AS line_cnt
) lc ON TRUE

JOIN LATERAL generate_series(1, lc.line_cnt) ln ON TRUE

-- müşteri bazlı ürün
JOIN LATERAL (
  SELECT sku
  FROM product
  WHERE customer_code = r.customer_code
  ORDER BY random()
  LIMIT 1
) pr ON TRUE

-- quantity 1-15 arası
JOIN LATERAL (
  SELECT (1 + (abs(hashtext(r.receipt_no || '-' || ln::text)) % 15))::int AS qty
) q ON TRUE

WHERE r.receipt_date BETWEEN '2025-01-01' AND '2025-12-31'
ON CONFLICT (receipt_id, line_no) DO NOTHING;

-----control

SELECT * FROM fact_workforce;


ALTER USER postgres WITH PASSWORD '1234';


