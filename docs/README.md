# Call Center System Documentation

## Overview

This is a complete call center system designed for a brand new Ubuntu 24.04 VPS. It consists of three main components:
1. **Asterisk 20 PBX**: Handles SIP routing, WebRTC/WebSocket connections, and server-side call recording via MixMonitor.
2. **Laravel Backend**: Provides REST API endpoints for the mobile app, stores call records and shipments, and hosts the web dashboard.
3. **Flutter Mobile App**: A clean interface for agents to view shipments and make SIP calls over WebSocket.

Because the agents use Xiaomi/Redmi phones which block local call recording, this system uses Asterisk's `MixMonitor` to record all calls on the server side. After a call ends, Asterisk triggers a webhook to the Laravel API to save the recording details.

## Deployment Guide

### 1. VPS Setup (Asterisk + Laravel)

You need a fresh Ubuntu 24.04 LTS server. SSH into your server as `root` and run the provided setup script.

First, upload the `call-center-system.zip` file to your server and extract it:
```bash
unzip call-center-system.zip
cd call-center-system/scripts
chmod +x setup-vps.sh
./setup-vps.sh
```

The script will automatically:
* Install MySQL 8, PHP 8.3, Composer, and Node.js
* Compile and install Asterisk 20 with PJSIP and WebSocket support
* Configure Asterisk with 25 agents (`agent1` to `agent25`)
* Install Laravel, set up the database, and run migrations/seeders
* Configure Supervisor to keep the Laravel application running
* Configure UFW firewall to allow necessary ports

Once the script finishes, it will display a summary with your server IP, dashboard URL, and database credentials.

### 2. Flutter App Setup

The Flutter app is located in the `flutter` directory. Before building the APK, you need to update the API base URL to point to your new VPS.

If you have Flutter installed on your local machine, you can use the provided build script:
```bash
cd call-center-system/scripts
./build-flutter-apk.sh YOUR_VPS_IP_ADDRESS
```

Alternatively, you can manually edit `flutter/lib/services/api_service.dart`:
```dart
// Change this line to your VPS IP address
static const String baseUrl = 'http://YOUR_VPS_IP:8000/api';
```
Then build the APK:
```bash
cd ../flutter
flutter build apk --release
```

## System Architecture

### Asterisk Configuration
* **Transport**: PJSIP over WebSocket (Port 8088)
* **Agents**: 25 pre-configured endpoints (`agent1` to `agent25`)
* **Passwords**: `AgentPass[N]2024` (e.g., `AgentPass12024`)
* **Recording**: `MixMonitor` is configured in `extensions.conf` to record all calls to `/var/spool/asterisk/recording/`.
* **Webhook**: The `h` (hangup) extension uses `curl` to send a POST request to the Laravel API with the recording filename and call details.

### Laravel API Endpoints
* `POST /api/login`: Authenticates the agent and returns a Sanctum token along with SIP credentials.
* `GET /api/shipments`: Returns a list of shipments assigned to the agent.
* `POST /api/webhook/call-ended`: Internal endpoint called by Asterisk to log the call and recording file.
* `GET /api/recordings`: Returns the agent's call history.
* `GET /api/recordings/{id}/play`: Streams the audio file for playback in the dashboard.

### Web Dashboard
The dashboard is accessible at `http://YOUR_VPS_IP:8000/`. It displays system statistics and a table of all call recordings with an inline audio player.

## Troubleshooting

If you encounter permission issues with call recordings not playing in the dashboard, run the quick-fix script:
```bash
cd call-center-system/scripts
./fix-permissions.sh
```

If the Flutter app cannot connect to the SIP server, ensure that port 8088 (TCP) and ports 10000-20000 (UDP) are open on your VPS firewall.
