#!/bin/bash
# Author       : Christo Deale                  
# Date         : 2023-11-14               
# podman_clamav: Utility to Scan system for viruses with CLAMAV from within a container using podman

# Function to check if a package is installed
is_package_installed() {
    if ! rpm -q "$1" >/dev/null 2>&1; then
        return 1
    fi
}

# Function to check if a podman image is pulled
is_image_pulled() {
    if sudo podman images --format "{{.Repository}}" | grep -q "^$1$"; then
        return 0
    else
        return 1
    fi
}

# Install epel-release if not installed
if ! is_package_installed epel-release; then
    sudo yum install epel-release -y
fi

# Install podman if not installed
if ! is_package_installed podman; then
    sudo yum install podman -y
fi

# Start and enable podman services
sudo systemctl start podman
sudo systemctl enable podman

# Check if ClamAV image is pulled
if ! is_image_pulled docker.io/clamav/clamav; then
    # Search and pull top clamav result
    sudo podman search --limit 3 clamav
    sudo podman pull docker.io/clamav/clamav
fi

# Delete default configuration in /etc/clam.d/scan.conf
sudo sed -i -e "s/^Example/#Example/" /etc/clam.d/scan.conf

# Uncomment LocalSocket line in /etc/clam.d/scan.conf
sudo sed -i -e 's/^#LocalSocket/LocalSocket/' /etc/clam.d/scan.conf

# Backup and update freshclam.conf
sudo cp /etc/freshclam.conf /etc/freshclam.conf.bak
sudo sed -i -e "s/^Example/#Example/" /etc/freshclam.conf

# Create freshclam.service file
echo '
[Unit]
Description=freshclam
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/freshclam -d -c 4
Restart=on-failure
PrivateTmp=true
RestartSec=10sec

[Install]
WantedBy=multi-user.target
' | sudo tee /usr/lib/systemd/system/freshclam.service

# Reload and start freshclam service
sudo systemctl daemon-reload
sudo systemctl start freshclam.service
sudo systemctl enable freshclam.service

# Prompt user to select an option
echo "Select an option:"
echo "1. Scan & remove - Home Directory"
echo "2. Scan & remove - Whole System"
echo "q. Quit"

read -r option

case $option in
    1)
        scan_directory="/home/uid885/"
        ;;
    2)
        scan_directory="/"
        ;;
    q)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option. Exiting..."
        exit 1
        ;;
esac

# Create /tmp/clamscan directory if it doesn't exist
if [ ! -d "/tmp/clamscan" ]; then
    sudo mkdir /tmp/clamscan
    sudo chown "uid885" /tmp/clamscan
fi

# Run clamscan command
sudo clamscan --max-filesize=250M -r -l ClamScanLog -i "$scan_directory"
clamscan --infected --recursive --move=/tmp/clamscan --log=/var/log/clamscan.log "$scan_directory"

# Function to exit the program
exit_program() {
    echo "Program finished. Exiting..."
    exit 0
}

# Call the exit_program function
exit_program
