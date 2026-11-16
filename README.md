# <div align="center"> AI Emergency Response System 🚑</div>

<div align="center">

<img src="https://readme-typing-svg.herokuapp.com?font=Fira+Code&size=28&pause=1000&color=FF4B4B&center=true&vCenter=true&width=850&lines=AI-Powered+Emergency+Response;Real-Time+Emergency+Assistance;AI+First-Aid+Guidance;Nearby+Responder+Network;Built+With+Flutter+%26+Python+%F0%9F%9A%91" alt="Typing SVG" />

</div>

---

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![PostGIS](https://img.shields.io/badge/PostGIS-4A90E2?style=for-the-badge&logo=postgresql&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![WebSocket](https://img.shields.io/badge/WebSocket-000000?style=for-the-badge&logo=socketdotio&logoColor=white)
![AI](https://img.shields.io/badge/AI-FF4B4B?style=for-the-badge&logo=openai&logoColor=white)

</div>

---

## 🚨 Overview

An **AI-powered emergency response system** designed to help people take the right first steps during critical situations while connecting them with nearby qualified responders.

The system combines:

- 🤖 AI-powered first-aid guidance
- 📍 Real-time location sharing
- 👨‍⚕️ Nearby responder discovery
- ⚡ Real-time emergency tracking
- 📞 Emergency service communication
- 🗄️ Geospatial emergency data management

Our goal is to reduce the gap between the moment an emergency happens and the arrival of professional assistance.

---

# ✨ Features

## 🤖 AI First-Aid Assistant

The AI assistant helps users understand what to do during an emergency while professional help is being contacted.

### Supported Emergency Types

- 🩸 Bleeding
- 🔥 Burns
- 🫁 Breathing Problems
- 😵 Unconsciousness
- 🦴 Fractures
- 🫨 Choking

### AI Pipeline

```text
User Description
       ↓
Natural Language Processing
       ↓
Emergency Classification
       ↓
RAG / Knowledge Retrieval
       ↓
First-Aid Guidance
       ↓
Safety Check
       ↓
User Instructions
```

### AI Responsibilities

- Understand the user's emergency description.
- Identify the relevant emergency category.
- Retrieve information from a trusted first-aid knowledge base.
- Generate clear step-by-step instructions.
- Provide safety-oriented guidance.
- Determine when professional emergency assistance should be contacted.

> ⚠️ The AI assistant provides first-aid support and does not replace professional medical care or official emergency services.

---

# 🚑 Emergency Help

When an emergency happens, every second matters.

The application allows the user to request emergency assistance with a simple action.

### Emergency Flow

```text
User Requests Help
        ↓
Location Detected
        ↓
Emergency Created
        ↓
Nearby Responders Found
        ↓
Responders Notified
        ↓
Responder Assigned
        ↓
Live Tracking
        ↓
Responder Arrived
```

### Main Emergency Functions

- 🚨 Request emergency help
- 📍 Automatically detect user location
- 📤 Share emergency location
- 👨‍⚕️ Find nearby qualified responders
- 🔔 Notify available responders
- ⚡ Track response status
- 📡 Track responder location
- 📞 Contact official emergency services

---

# 📍 Location & Emergency Services

The system uses location services to identify the user's current position and connect the emergency with nearby assistance.

### Technologies

- GPS
- Google Maps
- Firebase
- PostGIS

### Location Features

- 📍 Current latitude and longitude detection
- 🗺️ Emergency location visualization
- 👨‍⚕️ Nearby responder search
- 📏 Distance calculation
- 🧭 Navigation support
- 🔄 Real-time responder location updates

### Nearby Responder Search

```text
Emergency Location
        ↓
PostGIS Geographic Search
        ↓
Nearby Responders
        ↓
Qualification Check
        ↓
Availability Check
        ↓
Responder Notification
```

---

# ⚡ Real-Time Emergency Tracking

The system keeps the user updated throughout the emergency response process.

### Emergency Status

```text
🚨 Request Sent
      ↓
👨‍⚕️ Responder Assigned
      ↓
🚗 Responder On The Way
      ↓
📍 Live Location Tracking
      ↓
🏥 Responder Arrived
```

Real-time communication is handled using **WebSocket technology**.

### Real-Time Information

- Responder status
- Responder location
- Estimated arrival time
- Emergency status
- Assignment updates
- Response progress

---

# 📱 Mobile Application

The mobile application is the main interface between users and the emergency response system.

Built using:

- Flutter
- Dart

### Main Screens

- 🏠 Home
- 🚨 Emergency Help
- 🤖 AI First-Aid Assistant
- 👨‍⚕️ Nearby Responders
- 📍 Emergency Location
- ⚡ Live Response Tracking
- 👤 User Profile
- 📋 Emergency History

### Application Flow

```text
Home
 ↓
Emergency Help
 ↓
Emergency Details
 ↓
Location Detection
 ↓
AI First-Aid Guidance
 ↓
Nearby Responders
 ↓
Responder Assignment
 ↓
Live Tracking
 ↓
Emergency Completed
```

---

# 🧩 System Architecture

```text
                         ┌──────────────────────┐
                         │      Flutter App     │
                         │       Dart           │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │     FastAPI Backend  │
                         │       Python         │
                         └───────┬───────┬──────┘
                                 │       │
                    ┌────────────┘       └─────────────┐
                    ▼                                  ▼
          ┌──────────────────┐              ┌──────────────────┐
          │    PostgreSQL    │              │    AI Service    │
          │     + PostGIS    │              │     NLP / RAG    │
          └────────┬─────────┘              └────────┬─────────┘
                   │                                 │
                   └────────────┬────────────────────┘
                                ▼
                     ┌────────────────────┐
                     │     WebSocket      │
                     │   Real-Time Layer  │
                     └────────────────────┘
                                │
                                ▼
                     ┌────────────────────┐
                     │ Firebase Services  │
                     │ Notifications      │
                     └────────────────────┘
```

---

# 🏗️ Project Architecture

The project is divided into multiple layers to keep the system organized and scalable.

```text
AI-Emergency-Response-System/
│
├── 📱 mobile/
│   │
│   ├── lib/
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── services/
│   │   ├── models/
│   │   ├── providers/
│   │   └── main.dart
│   │
│   ├── assets/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── ⚙️ backend/
│   │
│   ├── app/
│   │   ├── api/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── websocket/
│   │   ├── core/
│   │   ├── database.py
│   │   └── main.py
│   │
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── 🤖 ai/
│   │
│   ├── models/
│   ├── classifiers/
│   ├── rag/
│   ├── knowledge_base/
│   ├── services/
│   └── requirements.txt
│
├── 🗄️ database/
│   │
│   ├── schema/
│   ├── migrations/
│   └── seed/
│
├── 📊 analytics/
│   │
│   ├── notebooks/
│   ├── datasets/
│   └── dashboards/
│
├── 📚 docs/
│   │
│   ├── architecture/
│   ├── diagrams/
│   ├── reports/
│   └── presentation/
│
├── 🖼️ screenshots/
│
├── .gitignore
├── LICENSE
└── README.md
```

---

# ⚙️ Backend & API

The backend acts as the central communication layer between the mobile application, database, AI service, and emergency services.

### Technologies

- Python
- FastAPI
- REST API
- JWT
- WebSocket

### Core Responsibilities

#### 🔗 REST APIs

Allow the mobile application to communicate with the backend.

#### 🔐 Authentication

Handle secure user authentication and authorization.

#### 🚨 Emergency Management

Create, update, and manage emergency requests.

#### 👨‍⚕️ Responder Management

Manage:

- Responder profiles
- Qualifications
- Availability
- Response status
- Current location

#### 🧠 AI Integration

Connect the backend with the AI emergency assistant.

#### ⚡ Real-Time Communication

Send emergency status updates through WebSocket connections.

---

# 🗄️ Database & Real-Time Layer

The database layer stores and manages the core system information.

### Technologies

- PostgreSQL
- PostGIS
- WebSocket

### Main Data

```text
Users
 ↓
Responders
 ↓
Qualifications
 ↓
Emergencies
 ↓
Locations
 ↓
Response History
```

### PostgreSQL

Stores:

- Users
- Responders
- Emergencies
- Qualifications
- Emergency history
- Response status

### PostGIS

Used for geographic operations such as:

- Nearby responder search
- Distance calculation
- Location-based queries
- Geographic filtering

### WebSocket

Used for real-time:

- Emergency status
- Responder location
- Estimated arrival time
- Response updates

---

# 👨‍⚕️ Responder Network

The system connects emergency users with nearby qualified responders.

### Responder Types

Responders may include:

- 👨‍⚕️ Doctors
- 👩‍⚕️ Nurses
- 🚑 Paramedics
- 🩹 Certified First-Aid Volunteers

### Responder Matching

The system considers:

```text
Distance
   +
Availability
   +
Qualification
   +
Current Response Status
```

The system then identifies responders who may be able to assist with the emergency.

---

# 📊 Data & Analytics

The Data & Analytics layer collects and analyzes emergency and responder activity.

### Technologies

- Python
- Pandas
- NumPy
- Power BI

### Data Collection

Collect information from:

- Emergency requests
- Emergency types
- Responder activity
- Response times
- Locations
- Completed responses

### Data Cleaning

Prepare collected data by handling:

- Missing values
- Inconsistent values
- Duplicate records
- Invalid records

### Response Analysis

Measure:

- Average response time
- Responder acceptance rate
- Average distance to emergency
- Number of completed responses

### Emergency Patterns

Analyze:

- Most common emergency types
- Emergency frequency
- Geographic patterns
- Time-based patterns

---

# 📈 Key Performance Indicators

The system can measure important operational metrics.

| KPI | Description |
|---|---|
| ⏱️ Average Response Time | Average time required for responders to reach emergencies |
| 👨‍⚕️ Acceptance Rate | Percentage of emergency requests accepted by responders |
| 📍 Average Distance | Average distance between responders and emergencies |
| 🚑 Completed Responses | Number of successfully completed emergency responses |
| 🚨 Emergency Types | Most frequently reported emergency categories |

---

# 📊 Power BI Dashboard

The collected data can be presented through interactive dashboards.

### Dashboard Examples

- 📈 Emergency Trends
- 🗺️ Emergency Locations
- ⏱️ Response Time Analysis
- 👨‍⚕️ Responder Performance
- 🚨 Emergency Type Distribution
- 📍 Geographic Analysis

---

# 🔐 Security

Security is an important part of the emergency response system.

### Security Features

- 🔑 Authentication
- 🛡️ Authorization
- 🔐 JWT-based access
- 👤 Role-based permissions
- 🔒 Protected API endpoints
- 📍 Controlled location sharing

Sensitive information should never be committed to the repository.

### Environment Variables

```text
.env
API_KEYS
DATABASE_URL
JWT_SECRET
FIREBASE_CREDENTIALS
GOOGLE_MAPS_API_KEY
```

These values should remain private.

---

# 📁 Environment Configuration

Create a `.env` file for local development.

Example:

```env
DATABASE_URL=your_database_url
JWT_SECRET=your_secret_key
GOOGLE_MAPS_API_KEY=your_google_maps_key
FIREBASE_PROJECT_ID=your_project_id
```

> Never commit real credentials, API keys, private certificates, or service account files to GitHub.

---

# 🛠️ Technologies Used

## 📱 Mobile

- Flutter
- Dart

## ⚙️ Backend

- Python
- FastAPI
- REST API
- JWT
- WebSocket

## 🤖 Artificial Intelligence

- Python
- NLP
- Machine Learning
- PyTorch / Scikit-learn
- RAG
- Knowledge Base

## 🗄️ Database

- PostgreSQL
- PostGIS

## 🔔 Cloud & Notifications

- Firebase

## 📍 Location

- GPS
- Google Maps
- PostGIS

## 📊 Data Analytics

- Python
- Pandas
- NumPy
- Power BI

---

# 📥 Installation

## 1️⃣ Clone Repository

```bash
git clone https://github.com/YOUR-USERNAME/AI-Emergency-Response-System.git
```

```bash
cd AI-Emergency-Response-System
```

---

# 📱 Mobile Setup

Navigate to the mobile directory:

```bash
cd mobile
```

Install Flutter dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

---

# ⚙️ Backend Setup

Navigate to the backend:

```bash
cd backend
```

Create a virtual environment:

```bash
python -m venv venv
```

Activate it on Windows:

```bash
venv\Scripts\activate
```

Activate it on Linux / macOS:

```bash
source venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the backend:

```bash
uvicorn app.main:app --reload
```

The API will be available locally at:

```text
http://127.0.0.1:8000
```

---

# 🤖 AI Setup

Navigate to the AI directory:

```bash
cd ai
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Configure the required environment variables and knowledge base before running the AI service.

---

# 🗄️ Database Setup

Create a PostgreSQL database and enable the PostGIS extension.

Example:

```sql
CREATE DATABASE emergency_response;
```

Enable PostGIS:

```sql
CREATE EXTENSION postgis;
```

Configure the database connection inside the backend environment configuration.

---

# 🐳 Docker

The project can be containerized for easier deployment.

Build the containers:

```bash
docker compose build
```

Start the system:

```bash
docker compose up
```

Stop the containers:

```bash
docker compose down
```

---

# 🧪 Testing

Backend tests can be executed using:

```bash
pytest
```

Flutter tests:

```bash
flutter test
```

---

# 📸 Application Preview

<div align="center">

<!-- Add your screenshots here -->

<img src="screenshots/home.png" width="250">

<img src="screenshots/emergency.png" width="250">

<img src="screenshots/ai-assistant.png" width="250">

</div>

---

# 🔄 Emergency Response Example

Example of a complete emergency scenario:

```text
User experiences an emergency
             ↓
      Opens the application
             ↓
       Requests help
             ↓
      Location detected
             ↓
 AI provides first-aid guidance
             ↓
 Nearby responders searched
             ↓
 Available responders notified
             ↓
     Responder accepts
             ↓
      Live tracking starts
             ↓
      Responder arrives
             ↓
       Emergency completed
```

---

# 🧠 AI Example

### User Input

```text
"My friend is bleeding heavily from his leg."
```

### AI Processing

```text
Natural Language Input
        ↓
Emergency Detection
        ↓
Bleeding Classification
        ↓
Knowledge Retrieval
        ↓
First-Aid Instructions
        ↓
Safety Guidance
```

### Expected System Behavior

The system provides clear first-aid guidance while directing the user toward appropriate professional emergency assistance.

---

# 🚧 Project Status

<div align="center">

## 🛠️ Currently In Development

</div>

The project is currently under development.

The team is working on:

- 📱 Mobile application
- ⚙️ Backend services
- 🤖 AI emergency assistant
- 🗄️ Database
- 📍 Location services
- ⚡ Real-time communication
- 📊 Analytics

---

# 🔮 Future Improvements

- 🗣️ Voice-based emergency reporting
- 🌍 Multi-language AI assistance
- 🧠 Improved emergency classification
- 📞 Automated emergency calling
- 🗺️ Advanced route optimization
- 📡 Improved live tracking
- 🔔 Smart responder notifications
- 🏥 Healthcare organization integration
- 📊 Advanced analytics
- 🚨 More emergency categories
- 🤖 Improved AI safety layer

---

# 👥 Team

<div align="center">

| 👤 Member | 💻 Responsibility |
|:---:|:---|
| **Mazen Araby** | 📊 Data & Analytics |
| **Mohamed Hassan** | 📍 Location & Emergency Services |
| **Mohamed Medhat** | 🗄️ Database & Real-Time |
| **Menna Sherif** | 🤖 AI Emergency Assistant |
| **Yasmin Ramadan** | ⚙️ Backend & API |
| **Omnia Ayman** | 📱 Mobile Core Developer |

</div>

---

# 📚 Documentation

Additional project documentation can be found in the `docs/` directory.

```text
docs/
│
├── architecture/
│   ├── system-architecture.png
│   └── system-flow.png
│
├── diagrams/
│   ├── use-case.png
│   ├── er-diagram.png
│   └── sequence-diagram.png
│
├── reports/
│
└── presentation/
    └── project-presentation.pdf
```

---

# ⚠️ Medical Safety Disclaimer

This project is an academic and technological prototype.

The AI assistant is intended to provide general first-aid guidance while professional assistance is being contacted.

It must not be considered a replacement for:

- Professional medical advice
- Doctors
- Paramedics
- Hospitals
- Official emergency services

In a real emergency, users should contact the appropriate official emergency service.

---

# 📄 License

This project is developed for educational and academic purposes.

See the `LICENSE` file for more information.

---

<div align="center">

# 🚑 AI Emergency Response System

### When every second matters, the right first step matters.

---

Made with ❤️ by the AI Emergency Response Team

</div>
