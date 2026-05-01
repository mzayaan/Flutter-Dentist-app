-- SmileCare Dentist App - Supabase SQL Schema
-- Run this entire script in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS admins (
  id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email    TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dentists (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           TEXT NOT NULL,
  specialization TEXT NOT NULL,
  email          TEXT NOT NULL,
  phone          TEXT NOT NULL,
  available_days TEXT NOT NULL,
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS patients (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT NOT NULL UNIQUE,
  password      TEXT NOT NULL,
  full_name     TEXT NOT NULL,
  phone         TEXT NOT NULL,
  date_of_birth DATE,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS treatments (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  description   TEXT NOT NULL,
  price         NUMERIC(10, 2) NOT NULL,
  duration_mins INTEGER NOT NULL,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Junction table linking dentists to the treatments they offer
CREATE TABLE IF NOT EXISTS dentist_treatments (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  dentist_id   UUID NOT NULL REFERENCES dentists(id) ON DELETE CASCADE,
  treatment_id UUID NOT NULL REFERENCES treatments(id) ON DELETE CASCADE,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(dentist_id, treatment_id)
);

CREATE TABLE IF NOT EXISTS appointments (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id       UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  dentist_id       UUID NOT NULL REFERENCES dentists(id) ON DELETE CASCADE,
  treatment_id     UUID NOT NULL REFERENCES treatments(id) ON DELETE CASCADE,
  appointment_date DATE NOT NULL,
  appointment_time TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'Pending',
  notes            TEXT,
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bills (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  patient_id     UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  total_amount   NUMERIC(10, 2) NOT NULL,
  status         TEXT NOT NULL DEFAULT 'Unpaid',
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY (disabled — app uses anon key directly)
-- ============================================================
ALTER TABLE admins             DISABLE ROW LEVEL SECURITY;
ALTER TABLE dentists           DISABLE ROW LEVEL SECURITY;
ALTER TABLE patients           DISABLE ROW LEVEL SECURITY;
ALTER TABLE treatments         DISABLE ROW LEVEL SECURITY;
ALTER TABLE dentist_treatments DISABLE ROW LEVEL SECURITY;
ALTER TABLE appointments       DISABLE ROW LEVEL SECURITY;
ALTER TABLE bills              DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- GRANTS
-- ============================================================
GRANT ALL ON admins             TO anon;
GRANT ALL ON dentists           TO anon;
GRANT ALL ON patients           TO anon;
GRANT ALL ON treatments         TO anon;
GRANT ALL ON dentist_treatments TO anon;
GRANT ALL ON appointments       TO anon;
GRANT ALL ON bills              TO anon;

-- ============================================================
-- SEED DATA: Admin
-- ============================================================
INSERT INTO admins (email, password)
VALUES ('admin@smilecare.com', 'admin123')
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- SEED DATA: Dentists
-- ============================================================
INSERT INTO dentists (name, specialization, email, phone, available_days) VALUES
  ('Dr. Sarah Johnson',   'General Dentistry',   'sarah@smilecare.com',   '+230 5900 0101', 'Mon, Tue, Wed, Thu, Fri'),
  ('Dr. Michael Chen',    'Orthodontics',         'michael@smilecare.com', '+230 5900 0102', 'Mon, Wed, Fri'),
  ('Dr. Emily Rodriguez', 'Oral Surgery',         'emily@smilecare.com',   '+230 5900 0103', 'Tue, Thu, Sat'),
  ('Dr. David Kim',       'Pediatric Dentistry',  'david@smilecare.com',   '+230 5900 0104', 'Mon, Tue, Thu, Fri')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED DATA: Treatments
-- ============================================================
INSERT INTO treatments (name, description, price, duration_mins) VALUES
  ('Routine Checkup',        'Full dental examination and cleaning',                                     80.00,   60),
  ('Teeth Whitening',        'Professional whitening treatment for a brighter smile',                   250.00,   90),
  ('Cavity Filling',         'Composite resin filling for cavities',                                    150.00,   45),
  ('Root Canal',             'Endodontic treatment to save an infected tooth',                          800.00,  120),
  ('Tooth Extraction',       'Simple or surgical extraction of a damaged tooth',                        200.00,   45),
  ('Braces Consultation',    'Orthodontic assessment and treatment planning',                           100.00,   60),
  ('Orthodontic Braces',     'Full orthodontic braces treatment to correct teeth alignment and bite', 27500.00,   200),
  ('Dental Crown',           'Porcelain crown placement to restore a damaged tooth',                    900.00,  120),
  ('Teeth Cleaning',         'Professional scaling and polishing',                                       75.00,   45),
  ('X-Ray Examination',      'Full mouth digital X-ray imaging',                                         60.00,   30),
  ('Dental Implant',         'Titanium implant for permanent tooth replacement',                       2500.00,  180)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED DATA: Assign treatments to dentists
-- ============================================================

-- Dr. Sarah Johnson — General Dentistry
INSERT INTO dentist_treatments (dentist_id, treatment_id)
SELECT d.id, t.id
FROM dentists d, treatments t
WHERE d.name = 'Dr. Sarah Johnson'
  AND t.name IN (
    'Routine Checkup',
    'Cavity Filling',
    'Teeth Cleaning',
    'Teeth Whitening',
    'X-Ray Examination'
  )
ON CONFLICT DO NOTHING;

-- Dr. Michael Chen — Orthodontics
INSERT INTO dentist_treatments (dentist_id, treatment_id)
SELECT d.id, t.id
FROM dentists d, treatments t
WHERE d.name = 'Dr. Michael Chen'
  AND t.name IN (
    'Braces Consultation',
    'Orthodontic Braces',
    'Routine Checkup',
    'X-Ray Examination'
  )
ON CONFLICT DO NOTHING;

-- Dr. Emily Rodriguez — Oral Surgery
INSERT INTO dentist_treatments (dentist_id, treatment_id)
SELECT d.id, t.id
FROM dentists d, treatments t
WHERE d.name = 'Dr. Emily Rodriguez'
  AND t.name IN (
    'Tooth Extraction',
    'Root Canal',
    'Dental Implant',
    'X-Ray Examination'
  )
ON CONFLICT DO NOTHING;

-- Dr. David Kim — Pediatric Dentistry
INSERT INTO dentist_treatments (dentist_id, treatment_id)
SELECT d.id, t.id
FROM dentists d, treatments t
WHERE d.name = 'Dr. David Kim'
  AND t.name IN (
    'Routine Checkup',
    'Cavity Filling',
    'Teeth Cleaning',
    'X-Ray Examination'
  )
ON CONFLICT DO NOTHING;
