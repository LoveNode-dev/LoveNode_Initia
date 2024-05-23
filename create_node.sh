
#!/bin/bash

echo "============================================================"
echo "Starting Initia Node Installation"
echo "============================================================"

# Update and install necessary packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl tar wget clang pkg-config libssl-dev jq build-essential git ncdu make lz4

# Install Go
GO_VERSION="1.22.2"
cd $HOME
wget "https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$GO_VERSION.linux-amd64.tar.gz"
rm "go$GO_VERSION.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version

# Clone and build Initia
cd $HOME
rm -rf initia
git clone https://github.com/initia-labs/initia.git
cd initia
git checkout v0.2.14
make build
make install
initiad version

# Initialize Initia Node
MONIKER="YOUR_MONIKER"
initiad init $MONIKER --chain-id initiation-1

# Update pruning settings
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.initia/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.initia/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"20\"/" $HOME/.initia/config/app.toml

# Download genesis and address book files
wget https://initia.s3.ap-southeast-1.amazonaws.com/initiation-1/genesis.json -O $HOME/.initia/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/initia-testnet/addrbook.json > $HOME/.initia/config/addrbook.json

# Configure seeds and peers
SEEDS="cd69bcb00a6ecc1ba2b4a3465de4d4dd3e0a3db1@initia-testnet-seed.itrocket.net:51656"
PEERS="3f472746f46493309650e5a033076689996c8881@initia-testnet.rpc.kjnodes.com:17959,aee7083ab11910ba3f1b8126d1b3728f13f54943@initia-testnet-peer.itrocket.net:11656,dae24101e66118156701ca2ad80b45bf008939a2@158.220.96.33:26656,767fdcfdb0998209834b929c59a2b57d474cc496@207.148.114.112:26656,633775ca828f8fc7f5c689a8c950664e7f198223@184.174.32.188:26656,9f0ae0790fae9a2d327d8d6fe767b73eb8aa5c48@176.126.87.65:22656,7317b8c930c52a8183590166a7b5c3599f40d4db@185.187.170.186:26656,6a64518146b8c902ef5930dfba00fe61a15ec176@43.133.44.152:26656,a45314423c15f024ff850fad7bd031168d937931@162.62.219.188:26656,35e4b461b38107751450af25e03f5a61e7aa0189@43.133.229.136:26656,3762209e1122580ce885d4e0fcc091d8602708b1@31.220.89.237:26656,d5b2a720e062d5b6b3ced8dfd3d57bf0a05080ce@217.76.57.121:51656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.initia/config/config.toml

# Reset and download snapshot
initiad tendermint unsafe-reset-all --home $HOME/.initia
if curl -s --head curl https://testnet-files.itrocket.net/initia/snap_initia.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://testnet-files.itrocket.net/initia/snap_initia.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.initia
else
  echo "No snapshot available"
fi

# Create systemd service for Initia
sudo tee /etc/systemd/system/initiad.service > /dev/null << EOF
[Unit]
Description=Initia Node
After=network-online.target

[Service]
User=root
WorkingDirectory=$HOME/.initia
ExecStart=$(which initiad) start --home $HOME/.initia
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Start Initia Node
sudo systemctl daemon-reload
sudo systemctl enable initiad
sudo systemctl restart initiad
sudo journalctl -u initiad -f

# Instructions for creating a wallet and validator
echo "Node setup complete. Please follow the instructions below to create a wallet and validator."
echo "1. Create a wallet: initiad keys add YOUR_WALLET_NAME"
echo "2. Request test tokens from the faucet: https://faucet.testnet.initia.xyz/"
echo "3. Create a validator: initiad tx mstaking create-validator --amount 1000000uinit --pubkey \$(initiad tendermint show-validator) --moniker \"YOUR_MONIKER\" --from YOUR_WALLET_NAME --chain-id initiation-1 --commission-rate 0.05 --commission-max-rate 0.20 --commission-max-change-rate 0.05 --identity \"YOUR_KEYBASE_ID\" --details \"YOUR_DETAILS\" --website \"YOUR_WEBSITE\" --fees 6000uinit"
