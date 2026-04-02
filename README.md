# Dialler - Call Center System

A complete call center system with **Asterisk PBX**, **Laravel API/Dashboard**, and **Flutter Dialer App**.

## Components

| Component | Description |
|-----------|-------------|
| `asterisk/` | Asterisk 20 PJSIP configs (25 agents, WebSocket, MixMonitor) |
| `laravel/` | Laravel API + Web Dashboard (login, recordings, shipments) |
| `flutter/` | Simple Dialer Flutter App (dial pad, mic recording, auto-upload) |
| `scripts/` | Setup and deploy scripts |

## Quick Start

### First-time VPS Setup
```bash
git clone https://github.com/angelitoforbeast/Dialler.git
cd Dialler
chmod +x scripts/*.sh
sudo ./scripts/setup-vps.sh
```

### Deploy Updates (after git push)
```bash
cd /root/Dialler
git pull
./scripts/deploy.sh
```

### Build Flutter APK
```bash
cd flutter
flutter pub get
flutter build apk --release
```

## Git Workflow

1. Make changes to code locally
2. `git add . && git commit -m "your message"`
3. `git push`
4. SSH to VPS: `cd /root/Dialler && git pull && ./scripts/deploy.sh`

## Dashboard
- URL: `http://YOUR_VPS_IP:8000`
- APK downloads available on dashboard

## API Endpoints
- `POST /api/login` — Agent login
- `GET /api/shipments` — List shipments
- `POST /api/upload-recording` — Upload call recording
- `GET /api/recordings/all` — List all recordings

## Default Credentials
- Email: `agent1@demo.com`
- Password: `password123`
