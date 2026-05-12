# 📊 ResultWave - Academic Excellence Tracker

<div align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.22.0-blue.svg)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.2.0-green.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

**Smart Result Management System for University Students**

[Features](#-features) • [Tech Stack](#-tech-stack) • [Installation](#-installation-guide) • [API Docs](#-api-endpoints) • [Screenshots](#-screenshots)

</div>

---

## 📱 Overview

ResultWave is a comprehensive academic performance tracking system designed for university students. It helps you track your grades, calculate GPAs, monitor semester performance, and generate professional academic reports. With AI-powered insights and a beautiful modern interface, ResultWave makes academic progress tracking simple and effective.

### Why ResultWave?

| Problem | Solution |
|---------|----------|
| ❌ Hard to track GPA manually | ✅ Automatic real-time GPA calculation |
| ❌ No central place for results | ✅ Organized semester-wise results |
| ❌ Cannot analyze performance | ✅ AI-powered insights and analytics |
| ❌ No professional reports | ✅ PDF export with beautiful formatting |
| ❌ Study materials scattered | ✅ Centralized course materials repository |

---

## ✨ Features

### Core Features

| Feature | Description | Status |
|---------|-------------|--------|
| 📊 **GPA Calculation** | Real-time CGPA & Semester GPA calculation | ✅ |
| 📚 **Result Management** | Easy grade entry and editing | ✅ |
| 📈 **Performance Analytics** | Visual charts and statistics dashboard | ✅ |
| 🤖 **AI Insights** | Smart recommendations based on performance | ✅ |
| 📄 **PDF Export** | Professional academic transcripts | ✅ |
| 👤 **Profile Management** | Custom avatars and personal info | ✅ |
| 📁 **Course Materials** | Centralized study materials repository | ✅ |
| 🌓 **Dark/Light Mode** | Theme support for day/night viewing | ✅ |
| 🔒 **Secure Auth** | JWT-based authentication | ✅ |
| 📧 **Email Verification** | Verify email during registration | 🚧 |
| 🔔 **Push Notifications** | Grade and deadline alerts | 📅 |
| 📅 **Exam Schedule** | Track exam dates with countdown | 📅 |

### Grade System

| Grade | Grade Point | Status |
|-------|-------------|--------|
| A+ | 4.0 | Excellent |
| A | 4.0 | Excellent |
| A- | 3.7 | Very Good |
| B+ | 3.3 | Good |
| B | 3.0 | Satisfactory |
| B- | 2.7 | Adequate |
| C+ | 2.3 | Fair |
| C | 2.0 | Passing |
| C- | 1.7 | Marginal |
| D+ | 1.3 | Below Average |
| D | 1.0 | Poor |
| F | 0.0 | Fail |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Flutter Mobile App │
│ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────────────┐ │
│ │ Login │ │Dashboard │ │ Results │ │ Profile │ │
│ │ Screen │ │ Page │ │ Page │ │ Page │ │
│ └───────────┘ └───────────┘ └───────────┘ └───────────────────────┘ │
│ │ │ │ │ │
│ └──────────────┼──────────────┼────────────────────┘ │
│ ▼ ▼ │
│ ┌────────────────────────────────────┐ │
│ │ HTTP/REST API │ │
│ └────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Spring Boot Server │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────────────────┐│
│ │ Auth │ │ User │ │ Avatar ││
│ │ Controller │ │ Service │ │ Service ││
│ └─────────────┘ └─────────────┘ └─────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PostgreSQL (Neon) │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ users | verification_tokens | backups │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Tech Stack

### Frontend (Flutter)

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | 3.22.0 | UI Framework |
| sqflite | ^2.0.2 | Local Database |
| provider | ^6.0.5 | State Management |
| pdf | ^3.8.1 | PDF Generation |
| shared_preferences | ^2.5.3 | Local Storage |
| flutter_pdfview | ^1.3.2 | PDF Viewer |
| http | ^1.1.0 | API Calls |
| google_fonts | ^8.0.2 | Typography |
| intl | ^0.18.1 | Date Formatting |
| share_plus | ^13.1.0 | PDF Sharing |

### Backend (Spring Boot)

| Dependency | Version | Purpose |
|------------|---------|---------|
| Spring Boot Starter Web | 3.2.0 | REST API |
| Spring Boot Starter Data JPA | 3.2.0 | Database ORM |
| PostgreSQL Driver | 42.7.1 | Database Driver |
| Spring Boot Starter Validation | 3.2.0 | Request Validation |

### Database

| Database | Purpose |
|----------|---------|
| PostgreSQL (Neon) | Cloud user data |
| SQLite | Local offline storage |

---

## 📁 Project Structure

### Flutter Structure
```
lib/
├── core/                           # Core business logic
│   └── gpa_system.dart            # GPA calculation system
├── models/                         # Data models
│   ├── student.dart
│   ├── module.dart
│   ├── grade.dart
│   ├── result.dart
│   ├── course.dart
│   └── avatar.dart
├── pages/                          # Main pages
│   ├── dashboard_page.dart
│   ├── results_page.dart
│   ├── profile_page.dart
│   ├── materials_page.dart
│   ├── insights_page.dart
│   └── edit_result_page.dart
├── screens/                        # Auth screens
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── create_account_screen.dart
│   └── home_screen.dart
├── services/                       # Services
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── database_service.dart
│   ├── pdf_service.dart
│   └── avatar_cache_service.dart
├── providers/                      # State management
│   └── theme_provider.dart
├── utils/                          # Utilities
│   ├── constants.dart
│   └── animations.dart
└── widgets/                        # Reusable widgets
    ├── glass_card.dart
    ├── insight_card.dart
    ├── gauge_chart.dart
    ├── semester_chip.dart
    └── grade_card.dart
```

### Spring Boot Structure
```
resultwave-server/
├── src/main/java/com/resultwave/
│   ├── ResultwaveServerApplication.java
│   ├── controller/
│   │   └── AuthController.java
│   ├── service/
│   │   └── AuthService.java
│   ├── repository/
│   │   └── UserRepository.java
│   ├── model/
│   │   └── User.java
│   ├── dto/
│   │   ├── LoginRequestDto.java
│   │   ├── RegisterRequestDto.java
│   │   ├── LoginResponseDto.java
│   │   ├── RegisterResponseDto.java
│   │   └── ApiResponseDto.java
│   └── config/
│       └── CorsConfig.java
└── src/main/resources/
    └── application.properties
```

### API Endpoints
##### Authentication Endpoints

| Method | Endpoint | Description |
|------|-------|-------|
| POST | /api/auth/register | Register new user |
| POST | /api/auth/login | User login |
| GET | /api/auth/user/{studentId} | Get user details |
| PUT | /api/auth/user/{studentId}/avatar | Update avatar |
DELETE | /api/auth/user/{studentId} | Deactivate account |
| GET | /api/auth/health | Health check |

## 📋 Prerequisites

### Required Software

```bash
# Flutter SDK 3.22.0 or higher
flutter --version

# Dart 3.4.0 or higher
dart --version

# Java JDK 17 or higher
java --version

# Maven 3.8.0 or higher
mvn --version

# Git
git --version