#!/bin/bash

echo "==================================================="
echo "  Xanvir LayerEdge Light Node Installation Script  "
echo "==================================================="

check_requirements() {
    echo "Checking system requirements..."
    
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Installing git..."
        sudo apt-get update
        sudo apt-get install -y git
    fi
    
    if ! command -v go &> /dev/null; then
        echo "Go is not installed. Installing Go 1.18 or higher..."
        wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        rm go1.21.0.linux-amd64.tar.gz
        
        export PATH=$PATH:/usr/local/go/bin
        
        if [ -f "$HOME/.bashrc" ]; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        fi
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
        fi
        
        if [ -f /usr/local/go/bin/go ]; then
            echo "Go installed successfully at /usr/local/go/bin/go"
            GO_VERSION=$(/usr/local/go/bin/go version | awk '{print $3}' | sed 's/go//')
            echo "Installed Go version: $GO_VERSION"
        else
            echo "Failed to install Go. Please install Go 1.18 or higher manually."
            exit 1
        fi
    else
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        if [ "$(printf '%s\n' "1.18" "$GO_VERSION" | sort -V | head -n1)" != "1.18" ]; then
            echo "Go version $GO_VERSION detected. Required: 1.18 or higher."
            echo "Upgrading Go..."
            wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
            sudo rm -rf /usr/local/go
            sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
            rm go1.21.0.linux-amd64.tar.gz
            echo "Go upgraded successfully."
            
            export PATH=$PATH:/usr/local/go/bin
        fi
    fi
    
    if ! command -v rustc &> /dev/null; then
        echo "Rust is not installed. Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
        fi
    else
        RUST_VERSION=$(rustc --version | awk '{print $2}')
        if [ "$(printf '%s\n' "1.81.0" "$RUST_VERSION" | sort -V | head -n1)" != "1.81.0" ]; then
            echo "Rust version $RUST_VERSION detected. Required: 1.81.0 or higher."
            echo "Updating Rust..."
            rustup update
        fi
    fi
    
    echo "All requirements satisfied."
}

install_risc0() {
    echo "Installing Risc0 Toolchain..."
    curl -L https://risczero.com/install | bash
    
    CURRENT_SHELL=$(basename "$SHELL")
    
    if [ -d "$HOME/.risc0/bin" ]; then
        export PATH="$PATH:$HOME/.risc0/bin"
        echo "Added ~/.risc0/bin to PATH"
    fi
    
    if [ "$CURRENT_SHELL" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
        echo "Sourcing .zshrc to update environment..."
        source "$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        echo "Sourcing .bashrc to update environment..."
        source "$HOME/.bashrc"
    fi
    
    if command -v rzup &> /dev/null; then
        echo "Running rzup install..."
        rzup install
    elif [ -f "$HOME/.risc0/bin/rzup" ]; then
        echo "Using full path to rzup..."
        "$HOME/.risc0/bin/rzup" install
    else
        echo "Warning: Could not find rzup executable."
        echo "Please run the following commands manually after this script completes:"
        echo "  1. Restart your shell with: exec $SHELL -l"
        echo "  2. Run: rzup install"
    fi
    
    echo "Risc0 Toolchain installation completed."
}

clone_repo() {
    echo "Cloning LayerEdge Light Node repository..."
    git clone https://github.com/Layer-Edge/light-node.git
    cd light-node
    echo "Repository cloned successfully."
}

configure_env() {
    echo "Configuring environment variables..."
    
    echo "Please enter your CLI node private key:"
    read -r PRIVATE_KEY
    
    while [ -z "$PRIVATE_KEY" ]; do
        echo "Private key cannot be empty. Please enter your CLI node private key:"
        read -r PRIVATE_KEY
    done
    
    cat > .env << EOF
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
POINTS_API=http://127.0.0.1:8080
PRIVATE_KEY='$PRIVATE_KEY'
EOF
    
    export GRPC_URL=grpc.testnet.layeredge.io:9090
    export CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
    export ZK_PROVER_URL=http://127.0.0.1:3001
    export API_REQUEST_TIMEOUT=100
    export POINTS_API=http://127.0.0.1:8080
    export PRIVATE_KEY="$PRIVATE_KEY"
    
    echo "Environment variables configured with your private key."
}

setup_merkle_service() {
    echo "Setting up Merkle service..."
    cd risc0-merkle-service
    cargo build && cargo run &
    MERKLE_PID=$!
    cd ..
    echo "Merkle service started with PID: $MERKLE_PID"
    echo "Waiting for Merkle service to initialize..."
    sleep 10
}

build_light_node() {
    echo "Building LayerEdge Light Node..."
    go build
    echo "Light Node built successfully."
}

setup_services() {
    echo "Setting up system services for automatic startup..."
    
    sudo tee /etc/systemd/system/layeredge-merkle.service > /dev/null << EOF
[Unit]
Description=LayerEdge Merkle Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD/risc0-merkle-service
ExecStart=$HOME/.cargo/bin/cargo run
Restart=on-failure
RestartSec=10
Environment="RUST_LOG=info"

[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/layeredge-lightnode.service > /dev/null << EOF
[Unit]
Description=LayerEdge Light Node
After=layeredge-merkle.service
Requires=layeredge-merkle.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD
ExecStart=$PWD/light-node
Restart=on-failure
RestartSec=10
EnvironmentFile=$PWD/.env

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable layeredge-merkle.service
    sudo systemctl enable layeredge-lightnode.service
    
    echo "Services created and enabled."
}

print_instructions() {
    echo ""
    echo "============================================="
    echo "  LayerEdge Light Node Setup Complete!      "
    echo "============================================="
    echo ""
    echo "To start the services:"
    echo "  sudo systemctl start layeredge-merkle.service"
    echo "  sudo systemctl start layeredge-lightnode.service"
    echo ""
    echo "To check service status:"
    echo "  sudo systemctl status layeredge-merkle.service"
    echo "  sudo systemctl status layeredge-lightnode.service"
    echo ""
    echo "To view logs:"
    echo "  sudo journalctl -u layeredge-merkle.service -f"
    echo "  sudo journalctl -u layeredge-lightnode.service -f"
    echo ""
    echo "Your private key has been stored in the .env file."
    echo ""
    echo "Connecting to LayerEdge Dashboard:"
    echo "1. Fetch points via CLI:"
    echo "   https://light-node.layeredge.io/api/cli-node/points/{walletAddress}"
    echo "   Replace {walletAddress} with your actual CLI wallet address."
    echo ""
    echo "2. Connect to Dashboard:"
    echo "   - Navigate to dashboard.layeredge.io"
    echo "   - Connect your wallet"
    echo "   - Link your CLI node's Public Key"
    echo ""
    echo "NOTE: One CLI wallet can only link to one dashboard wallet."
    echo "      Linking is mandatory, even if the CLI and dashboard wallets are identical."
    echo "============================================="
}

main() {
    check_requirements
    install_risc0
    clone_repo
    configure_env
    build_light_node
    setup_services
    print_instructions
}

main

exit 0
