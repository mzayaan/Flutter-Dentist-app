# SmileCare - Flutter Dentist App

A full-featured dental clinic management system built with **Flutter** and **Supabase** as part of a university mobile application development assignment.

---

## 1. Project Overview

**SmileCare** is a cross-platform mobile application that digitises the day-to-day operations of a dental clinic. It provides two distinct user roles:

- **Admin** — clinic staff who manage dentists, treatments, appointments, and billing from a central dashboard.
- **Patient** — registered patients who can book appointments, track their history, and view outstanding bills — all from their phone.

The app uses **Supabase** (PostgreSQL) as its backend, with the `supabase_flutter` package handling all database communication. No custom server code is required.

---

## 2. Features

### Admin Features
- Secure admin login (credentials checked against the `admins` table)
- Dashboard with live summary cards: total patients, today's appointments, total revenue, pending bills
- **Dentists** — add, edit, and delete dentist records (name, specialization, email, phone, available days)
- **Treatments** — add, edit, and delete treatments (name, description, price, duration)
- **Appointments** — view all appointments with patient & dentist details; change status to Confirmed, Cancelled, or Completed
- **Bills** — view all patient bills; mark individual bills as Paid
- Auto-mark bill as Paid when an appointment is set to Completed
- Logout with confirmation dialog

### Patient Features
- New patient registration (full name, email, phone, date of birth, password)
- Patient login (email + password)
- Home screen with personalised welcome card and upcoming appointments list
- **Book Appointment** — guided 4-step wizard:
  1. Choose a dentist (with live search by name or specialization)
  2. Choose a treatment (with price and duration shown)
  3. Pick an appointment date via date picker
  4. Enter preferred time and optional notes, then confirm
- Auto-creation of a bill record upon booking
- Duplicate booking prevention: patients cannot have two pending appointments on the same date
- **My Appointments** — tabbed view of upcoming and past appointments with status badges; cancel pending appointments
- **My Bills** — list of all bills with outstanding balance banner
- **Profile** — display of account details (name, email, phone, date of birth, member since)
- Logout with confirmation dialog

### Additional Features
- Real-time search / filter for dentists by name or specialization on the booking screen
- Color-coded status badges throughout the app:
  - **Pending** — Orange
  - **Confirmed** — Green
  - **Cancelled** — Red
  - **Completed** — Blue
  - **Paid** — Green
  - **Unpaid** — Orange
- `CircularProgressIndicator` on every async operation
- `SnackBar` feedback for all successes and errors
- Pull-to-refresh on all list screens
- Full null safety throughout

---

## 3. Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter 3.x (Dart) |
| Backend / Database | Supabase (PostgreSQL) |
| Flutter Package | `supabase_flutter ^2.3.4` |
| Date Formatting | `intl ^0.19.0` |
| State Management | `setState` (built-in) |

---

## 4. Project Structure

```
lib/
├── main.dart
├── config/
│   └── supabase_config.dart
├── models/
│   ├── admin.dart
│   ├── dentist.dart
│   ├── patient.dart
│   ├── treatment.dart
│   ├── appointment.dart
│   └── bill.dart
├── services/
│   ├── auth_service.dart
│   ├── dentist_service.dart
│   ├── treatment_service.dart
│   ├── appointment_service.dart
│   └── bill_service.dart
├── screens/
│   ├── auth/
│   │   ├── splash_screen.dart
│   │   ├── admin_login_screen.dart
│   │   ├── patient_login_screen.dart
│   │   └── patient_register_screen.dart
│   ├── admin/
│   │   ├── admin_dashboard.dart
│   │   ├── admin_home_tab.dart
│   │   ├── admin_dentists_tab.dart
│   │   ├── admin_treatments_tab.dart
│   │   ├── admin_appointments_tab.dart
│   │   └── admin_bills_tab.dart
│   └── patient/
│       ├── patient_dashboard.dart
│       ├── patient_home_tab.dart
│       ├── patient_book_tab.dart
│       ├── patient_appointments_tab.dart
│       ├── patient_bills_tab.dart
│       └── patient_profile_tab.dart
└── widgets/
    └── status_badge.dart
```

---

## 5. Database Schema

### admins
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| email | text | Admin email |
| password | text | Admin password |

### dentists
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| name | text | Dentist full name |
| specialization | text | Area of expertise |
| email | text | Contact email |
| phone | text | Contact phone |
| available_days | text | Working days |
| created_at | timestamp | Record creation time |

### patients
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| email | text | Patient email (unique) |
| password | text | Patient password |
| full_name | text | Patient full name |
| phone | text | Contact number |
| date_of_birth | date | Patient DOB |
| created_at | timestamp | Record creation time |

### treatments
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| name | text | Treatment name |
| description | text | Treatment details |
| price | numeric | Cost of treatment |
| duration_mins | int | Duration in minutes |
| created_at | timestamp | Record creation time |

### appointments
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| patient_id | uuid | References patients |
| dentist_id | uuid | References dentists |
| treatment_id | uuid | References treatments |
| appointment_date | date | Date of appointment |
| appointment_time | text | Time of appointment |
| status | text | Pending / Confirmed / Completed / Cancelled |
| notes | text | Additional notes |
| created_at | timestamp | Record creation time |

### bills
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| appointment_id | uuid | References appointments |
| patient_id | uuid | References patients |
| total_amount | numeric | Bill total |
| status | text | Paid or Unpaid |
| created_at | timestamp | Record creation time |

---

## 6. Setup Instructions

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and on your PATH
- Dart SDK (bundled with Flutter)
- A free [Supabase](https://supabase.com) account

### Installation Steps

**1. Clone the repository**
```bash
git clone https://github.com/mzayaan/Flutter-Dentist-app.git
cd Flutter-Dentist-app
```

**2. Install dependencies**
```bash
flutter pub get
```

**3. Configure Supabase**

Open `lib/config/supabase_config.dart` and replace the placeholder values:
```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```
Your Project URL and anon key are found in your Supabase dashboard under **Settings → API**.

**4. Run the SQL schema**

Copy the contents of `supabase_schema.sql` and paste it into the **SQL Editor** in your Supabase dashboard, then click **Run**. This creates all tables, sets permissions, seeds the default admin account, and adds sample dentists and treatments.

**5. Run the app**
```bash
flutter run
```

---

## 7. Default Admin Credentials

| Field | Value |
|---|---|
| Email | admin@smilecare.com |
| Password | admin123 |

> These credentials are seeded by the SQL script. Change them in Supabase after first login.

---

## 8. Screenshots

> *(Add screenshots here)*

---

## 9. Assignment Info

| Field | Detail |
|---|---|
| Module | Mobile Application Development |
| Framework | Flutter + Supabase |
| Submission Deadline | 04 August 2026 |
