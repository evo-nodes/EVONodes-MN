#!/bin/bash
# EVONodes Masternode Setup Script V1.0.0 for Ubuntu LTS
#
# Script will attempt to autodetect primary public IP address
# and generate masternode private key unless specified in command line
#
# Usage:
# bash evonodesauto.sh
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#TCP port
PORT=18050
RPC=18051

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'evo_nodesd' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop evo_nodesd${NC}"
        evo_nodes-cli stop
        sleep 30
        if pgrep -x 'evo_nodesd' > /dev/null; then
            echo -e "${RED}evo_nodesd daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            sudo pkill -9 evo_nodesd
            sleep 30
            if pgrep -x 'evo_nodesd' > /dev/null; then
                echo -e "${RED}Can't stop evo_nodesd! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}

#Process command line parameters
genkey=$1
clear

echo -e "${GREEN} ------- EVONodes MASTERNODE INSTALLER V1.0.0--------+
 |                                                  |
 |                                                  |::
 |       The installation will install and run      |::
 |        the masternode under a user EVO.          |::
 |                                                  |::
 |        This version of installer will setup      |::
 |           fail2ban and ufw for your safety.      |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::S${NC}"
echo "Do you want me to generate a masternode private key for you?[y/n]"
read DOSETUP

if [[ $DOSETUP =~ "n" ]] ; then
          read -e -p "Enter your private key:" genkey;
              read -e -p "Confirm your private key: " genkey2;
    fi

#Confirming match
  if [ $genkey = $genkey2 ]; then
     echo -e "${GREEN}MATCH! ${NC} \a"
else
     echo -e "${RED} Error: Private keys do not match. Try again or let me generate one for you...${NC} \a";exit 1
fi
sleep .5
clear

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi
if [ -d "/var/lib/fail2ban/" ];
then
    echo -e "${GREEN}Packages already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano
sudo apt-get install unzip
fi

#Generating Random Password for  JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi

#Installing Daemon
cd ~
rm -rf /usr/local/bin/evonodes*
wget https://github.com/evo-nodes/EVONodes/releases/download/v1.0/EVONodes-ubuntu-daemon.tar.gz
tar -xzvf EVONodes-ubuntu-daemon.tar.gz
sudo chmod -R 755 evo_nodes-cli
sudo chmod -R 755 evo_nodesd
cp -p -r evo_nodesd /usr/local/bin
cp -p -r evo_nodes-cli /usr/local/bin

sudo mkdir ~/.evonodes-params
cd ~/.evonodes-params && wget https://github.com/evo-nodes/EVONodes-MN/raw/main/params/sapling-output.params && wget https://github.com/evo-nodes/EVONodes-MN/raw/main/params/sapling-spend.params

 evo_nodes-cli stop
 sleep 5
 #Create datadir
 if [ ! -f ~/.evonodes/evonodes.conf ]; then
        sudo mkdir ~/.evonodes

 fi

cd ~
clear
echo -e "${YELLOW}Creating evonodes.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.evonodes/evonodes.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
server=1
daemon=1

EOF

    sudo chmod 755 -R ~/.evonodes/evonodes.conf

    #Starting daemon first time just to generate masternode private key
    evo_nodesd
sleep 7
while true;do
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    genkey=$(evo_nodes-cli createmasternodekey)
    if [ "$genkey" ]; then
        break
    fi
sleep 7
done
    fi

    #Stopping daemon to create evonodes.conf
    evo_nodes-cli stop
    sleep 5
cd ~/.evonodes/ && rm -rf blocks chainstate sporks evodb
cd ~/.evonodes/ && wget https://github.com/evo-nodes/EVONodes/releases/download/v1.0/bootstrap.zip
cd ~/.evonodes/ && unzip bootstrap.zip
sudo rm -rf ~/.evonodes/bootstrap.zip



# Create evonodes.conf
cat <<EOF > ~/.evonodes/evonodes.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
rpcport=$RPC
port=$PORT
listen=1
server=1
daemon=1

logtimestamps=1
maxconnections=256
masternode=1
externalip=$publicip:$PORT
masternodeaddr=$publicip:$PORT
masternodeprivkey=$genkey
addnode=209.38.22.238
addnode=64.225.77.31
addnode=134.122.49.134
addnode=64.225.66.129
addnode=64.227.78.147
addnode=64.225.77.0




EOF
    evo_nodesd -daemon
#Finally, starting daemon with new evonodes.conf
printf '#!/bin/bash\nif [ ! -f "~/.evonodes/evo_nodes.pid" ]; then /usr/local/bin/evo_nodesd -daemon ; fi' > /root/evonodesauto.sh
chmod -R 755 /root/evonodesauto.sh
#Setting auto start cron job for Evonodes
if ! crontab -l | grep "evonodesauto.sh"; then
    (crontab -l ; echo "*/5 * * * * /root/evonodesauto.sh")| crontab -
fi

echo -e "========================================================================
${GREEN}Masternode setup is complete!${NC}
========================================================================
Masternode was installed with VPS IP Address: ${GREEN}$publicip${NC}
Masternode Private Key: ${GREEN}$genkey${NC}
Now you can add the following string to the masternode.conf file
======================================================================== \a"
echo -e "${GREEN}EVO_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
echo -e "========================================================================
Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it
into your ${GREEN}masternode.conf${NC} file and replace:
    ${GREEN}EVO_mn1${NC} - with your desired masternode name (alias)
    ${GREEN}TxId${NC} - with Transaction Id from getmasternodeoutputs
    ${GREEN}TxIdx${NC} - with Transaction Index (0 or 1)
     Remember to save the masternode.conf and restart the wallet!
To introduce your new masternode to the Evonodes network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'Is Synced' status will change
to 'true', which will indicate a comlete sync, although it may take
from several minutes to several hours depending on the network state.
Your initial Masternode Status may read:
    ${GREEN}Node just started, not yet activated${NC} or
    ${GREEN}Node  is not in masternode list${NC}, which is normal and expected.
"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}
Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in evonodes.conf:
${GREEN}cat ~/.evonodes/evonodes.conf${NC}
Here is your evonodes.conf generated by this script:
-------------------------------------------------${GREEN}"
echo -e "${GREEN}EVO_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
cat ~/.evonodes/evonodes.conf
echo -e "${NC}-------------------------------------------------
NOTE: To edit evonodes.conf, first stop the evo_nodesd daemon,
then edit the evonodes.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the evo_nodesd daemon back up:
to stop:              ${GREEN}evo_nodes-cli stop${NC}
to start:             ${GREEN}evo_nodesd${NC}
to edit:              ${GREEN}nano ~/.evonodes/evonodes.conf${NC}
to check mn status:   ${GREEN}evo_nodes-cli getmasternodestatus${NC}
========================================================================
To monitor system resource utilization and running processes:
                   ${GREEN}htop${NC}
========================================================================
"