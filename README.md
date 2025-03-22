# LayerEdge Light Node

This repository contains the installation script and instructions for setting up a LayerEdge Light Node.

## Overview

LayerEdge Light Node allows you to participate in the LayerEdge network, connecting to the LayerEdge Dashboard for analytics and earning rewards.

## Requirements

- Linux-based operating system
- Sudo privileges
- Internet connection

## Quick Installation

You can install the LayerEdge Light Node using either curl or wget:

### Using curl

```bash
curl -L https://raw.githubusercontent.com/WINGFO-HQ/LayerEdgeCLI/refs/heads/main/layeredge.sh -o layeredge.sh && chmod +x layeredge.sh && ./layeredge.sh
```

### Using wget

```bash
wget https://raw.githubusercontent.com/WINGFO-HQ/LayerEdgeCLI/refs/heads/main/layeredge.sh && chmod +x layeredge.sh && ./layeredge.sh
```

### Manual Installation

If you prefer to install manually:

1. Clone this repository
2. Make the script executable: chmod +x layeredge.sh
3. Run the script: ./layeredge.sh

### What the installer does

The installation script will:

    1. Check and install required dependencies:

        - Git
        - Go (version 1.18 or higher)
        - Rust (version 1.81.0 or higher)
        - Risc0 Toolchain

    2. Clone the LayerEdge Light Node repository
    3. Configure environment variables
    4. Build and set up the Merkle service and Light Node
    5. Configure systemd services for automatic startup

### Managing Your Node

#### Starting the services

```bash
sudo systemctl start layeredge-merkle.service
sudo systemctl start layeredge-lightnode.service
```

#### Checking status

```bash
sudo systemctl status layeredge-merkle.service
sudo systemctl status layeredge-lightnode.service
```

#### Viewing logs

```bash
sudo journalctl -u layeredge-merkle.service -f
sudo journalctl -u layeredge-lightnode.service -f
```

#### Stopping the services

```bash
sudo systemctl stop layeredge-lightnode.service
sudo systemctl stop layeredge-merkle.service
```

#### Restarting the services

```bash
sudo systemctl restart layeredge-merkle.service
sudo systemctl restart layeredge-lightnode.service
```

### Connecting to LayerEdge Dashboard

1. Fetch points via CLI:

```bash
https://light-node.layeredge.io/api/cli-node/points/{walletAddress}
```

Replace {walletAddress} with your actual CLI wallet address.

2. Connect to Dashboard:
   - Navigate to dashboard.layeredge.io
   - Connect your wallet
   - Link your CLI node's Public Key

### Uninstalling

```bash
# Stop and disable services
sudo systemctl stop layeredge-lightnode.service
sudo systemctl stop layeredge-merkle.service
sudo systemctl disable layeredge-lightnode.service
sudo systemctl disable layeredge-merkle.service

# Remove service files
sudo rm /etc/systemd/system/layeredge-lightnode.service
sudo rm /etc/systemd/system/layeredge-merkle.service
sudo systemctl daemon-reload

# Remove the light-node directory
cd ~
rm -rf light-node

# Optional: Clean up Risc0
rm -rf ~/.risc0
```
