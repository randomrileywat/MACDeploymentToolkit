#!/bin/bash
#
# MacDeploymentToolkit - macOS Development Setup Script
# Run this on your macOS VM to set up the development environment
#

set -e

echo "=========================================="
echo "  Mac Deployment Toolkit - Setup Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo "Please complete the installation dialog, then run this script again."
    exit 0
else
    echo -e "${GREEN}✓ Xcode Command Line Tools installed${NC}"
fi

# Check Swift version
SWIFT_VERSION=$(swift --version 2>&1 | head -1)
echo -e "${GREEN}✓ Swift: ${SWIFT_VERSION}${NC}"

# Check for Homebrew (we'll need it for the app anyway)
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
else
    echo -e "${GREEN}✓ Homebrew installed${NC}"
fi

# Ask user preference
echo ""
echo "Which editor do you want to use?"
echo "  1) Xcode (Recommended - has SwiftUI previews)"
echo "  2) VS Code"
echo "  3) Both"
read -p "Enter choice [1-3]: " EDITOR_CHOICE

case $EDITOR_CHOICE in
    1)
        USE_XCODE=true
        USE_VSCODE=false
        ;;
    2)
        USE_XCODE=false
        USE_VSCODE=true
        ;;
    3)
        USE_XCODE=true
        USE_VSCODE=true
        ;;
    *)
        echo "Invalid choice, defaulting to Xcode"
        USE_XCODE=true
        USE_VSCODE=false
        ;;
esac

# Setup Xcode
if [ "$USE_XCODE" = true ]; then
    echo ""
    echo -e "${YELLOW}Checking for Xcode...${NC}"
    
    if ! [ -d "/Applications/Xcode.app" ]; then
        echo -e "${YELLOW}Xcode not found. Please install from the Mac App Store.${NC}"
        echo "Opening App Store..."
        open "macappstore://itunes.apple.com/app/id497799835"
        echo ""
        echo "After installing Xcode, run this script again."
    else
        echo -e "${GREEN}✓ Xcode installed${NC}"
        
        # Accept license if needed
        sudo xcodebuild -license accept 2>/dev/null || true
    fi
fi

# Setup VS Code
if [ "$USE_VSCODE" = true ]; then
    echo ""
    echo -e "${YELLOW}Setting up VS Code...${NC}"
    
    if ! command -v code &> /dev/null; then
        echo "Installing VS Code via Homebrew..."
        brew install --cask visual-studio-code
    else
        echo -e "${GREEN}✓ VS Code installed${NC}"
    fi
    
    # Install Swift extension
    echo "Installing VS Code Swift extension..."
    code --install-extension sswg.swift-lang 2>/dev/null || true
    
    # Install SourceKit-LSP for better code completion
    echo "Installing sourcekit-lsp..."
    # SourceKit-LSP comes with Xcode/Swift toolchain
    
    echo -e "${GREEN}✓ VS Code configured for Swift${NC}"
fi

# Navigate to project directory (assume script is in project folder)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo ""
echo -e "${YELLOW}Building project...${NC}"

# Try to build using xcodebuild
if xcodebuild -project MacDeploymentToolkit.xcodeproj -scheme MacDeploymentToolkit -configuration Debug build 2>&1 | tail -20; then
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
else
    echo ""
    echo -e "${RED}Build failed. Check errors above.${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}  Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "To run the app:"
echo ""

if [ "$USE_XCODE" = true ]; then
    echo "  Xcode:  open MacDeploymentToolkit.xcodeproj"
    echo "          Then press ⌘+R to run"
    echo ""
fi

if [ "$USE_VSCODE" = true ]; then
    echo "  VS Code:  code ."
    echo "            Build with: xcodebuild -project MacDeploymentToolkit.xcodeproj -scheme MacDeploymentToolkit build"
    echo ""
fi

echo "  Command Line:  xcodebuild -project MacDeploymentToolkit.xcodeproj -scheme MacDeploymentToolkit build"
echo ""

# Offer to open now
read -p "Open project now? [y/N]: " OPEN_NOW
if [[ "$OPEN_NOW" =~ ^[Yy]$ ]]; then
    if [ "$USE_XCODE" = true ]; then
        open MacDeploymentToolkit.xcodeproj
    elif [ "$USE_VSCODE" = true ]; then
        code .
    fi
fi

echo ""
echo "Happy coding! 🚀"
