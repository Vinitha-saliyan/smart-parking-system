# 🅿️ AI Smart Parking System

> **Production-ready AI-powered Smart Parking System** with real-time vehicle detection, interactive parking maps, instant slot reservations, and premium mobile experiences.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?style=for-the-badge&logo=fastapi)
![YOLOv11](https://img.shields.io/badge/YOLOv11-Ultralytics-FF6F00?style=for-the-badge)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql)
![Redis](https://img.shields.io/badge/Redis-7-DC382D?style=for-the-badge&logo=redis)

---

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   User App      │     │   Admin App     │
│   (Flutter)     │     │   (Flutter)     │
│                 │     │                 │
│ • Find Parking  │     │ • Dashboard     │
│ • Reserve Slots │     │ • Manage Areas  │
│ • Navigate      │     │ • YOLO Controls │
│ • Pay           │     │ • Analytics     │
└────────┬────────┘     └────────┬────────┘
         │    REST + WebSocket   │
         └──────────┬────────────┘
                    │
         ┌──────────▼──────────┐
         │   FastAPI Backend   │
         │                     │
         │ • Auth (JWT)        │
         │ • Parking CRUD      │
         │ • Reservations      │
         │ • WebSocket Live    │
         │ • YOLOv11 AI        │
         │ • Notifications     │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │   Data Layer        │
         │                     │
         │ • PostgreSQL 16     │
         │ • Redis 7           │
         │ • Firebase          │
         └─────────────────────┘
```

## 📁 Project Structure

```
smart_parking/
├── user_app/          # Flutter User Mobile App
├── admin_app/         # Flutter Admin Dashboard App
├── backend/           # FastAPI Python Backend
└── README.md          # This file
```

## 🚀 Quick Start

For the exact Windows commands, including the PowerShell policy-safe workflow,
see [`WINDOWS_ADMIN_SETUP.md`](WINDOWS_ADMIN_SETUP.md).

### Prerequisites

- **Flutter** 3.24+ ([install](https://docs.flutter.dev/get-started/install))
- **Python** 3.11+ ([install](https://www.python.org/downloads/))
- **Docker** & Docker Compose ([install](https://docs.docker.com/get-docker/))
- **Android Studio** or **VS Code** with Flutter extension

### 1. Start Backend Services

```bash
# Navigate to backend
cd backend

# Start PostgreSQL & Redis via Docker
docker-compose up -d

# Create Python virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Seed the database with demo data
python -m app.seed

# Start the API server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

### 2. Run User App

```bash
cd user_app

# Get dependencies
flutter pub get

# Run on Android emulator or connected device
flutter run

# Run on specific device
flutter run -d <device_id>
```

### 3. Run Admin App

```bash
cd admin_app

# Get dependencies
flutter pub get

# Run on Android emulator or connected device
flutter run
```

## 🔑 Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@smartparking.com | Admin@123 |
| User | (register a new account) | — |

## 🧪 Demo Data

The seed script creates:
- **1 Parking Area**: "Smart Park Central" (New Delhi)
- **20 Parking Slots**: A01-A10, B01-B05, C01-C03 (VIP), D01 (EV), E01 (Disabled)
- Pre-set states: A03, A07, B02 occupied; A05 reserved

## ✨ Features

### User App
- 🔐 JWT Authentication with Firebase
- 🗺️ Interactive parking slot map with real-time updates
- 📊 Live availability dashboard with animated charts
- 🎫 Slot reservation with countdown timer & QR code
- 🔍 Search & filter parking areas
- 🔔 Push notifications
- 🌙 Dark/Light theme
- 🎨 Premium glassmorphism UI

### Admin App
- 📊 Professional analytics dashboard
- 🅿️ Parking area & slot management (CRUD)
- 👥 User management with role-based access
- 📹 Camera management interface
- 🤖 YOLOv11 AI detection controls
- 📈 Revenue & occupancy charts
- 📋 Reservation management
- 🔒 Audit log & security

### Backend
- ⚡ FastAPI with async/await
- 🔄 Real-time WebSocket updates
- 🗄️ PostgreSQL with SQLAlchemy ORM
- 💾 Redis caching & pub/sub
- 🔐 JWT token authentication
- 🤖 YOLOv11 vehicle detection (Phase 2)
- 📱 Firebase Cloud Messaging
- 🐳 Docker containerized

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| User App | Flutter, Riverpod, GoRouter, Dio, Material 3 |
| Admin App | Flutter, Riverpod, GoRouter, fl_chart |
| Backend | Python, FastAPI, SQLAlchemy, Pydantic v2 |
| Database | PostgreSQL 16, Redis 7 |
| AI | YOLOv11 (Ultralytics), OpenCV |
| Auth | JWT, Firebase Authentication |
| Real-time | WebSocket |
| Deployment | Docker, Docker Compose |

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Tablet (responsive layouts)

## 📄 License

This project is proprietary. All rights reserved.

---

Built with ❤️ using Flutter, FastAPI, and YOLOv11
