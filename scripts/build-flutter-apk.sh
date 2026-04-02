#!/bin/bash
# =============================================================================
# Flutter APK Build Script
# Run this on a machine with Flutter SDK installed
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if VPS IP is provided
if [ -z "$1" ]; then
    echo -e "${RED}Usage: ./build-flutter-apk.sh <VPS_IP_ADDRESS>${NC}"
    echo -e "Example: ./build-flutter-apk.sh 203.0.113.50"
    exit 1
fi

VPS_IP=$1
FLUTTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../flutter" && pwd)"

echo -e "${YELLOW}Building Call Center APK...${NC}"
echo -e "VPS IP: ${VPS_IP}"

# Update API base URL
echo -e "\n${YELLOW}Updating API URL to http://${VPS_IP}:8000/api ...${NC}"
sed -i "s|YOUR_VPS_IP|${VPS_IP}|g" ${FLUTTER_DIR}/lib/services/api_service.dart

echo -e "${GREEN}API URL updated.${NC}"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter SDK not found. Please install Flutter first.${NC}"
    echo -e "Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

cd ${FLUTTER_DIR}

echo -e "\n${YELLOW}Getting dependencies...${NC}"
flutter pub get

echo -e "\n${YELLOW}Building APK...${NC}"
flutter build apk --release

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN}APK built successfully!${NC}"
echo -e "${GREEN}Location: ${FLUTTER_DIR}/build/app/outputs/flutter-apk/app-release.apk${NC}"
echo -e "${GREEN}=============================================${NC}"
