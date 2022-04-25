#!/bin/bash

echo "Starting the NordVPN Add-IPs-to-UFW and Create-OpenVPN-Profile script."
echo " "
echo " "


read -rp "Which country would you like to connect to? Use the two-letter country code, please. " country
if test "$#" -ne 2; then
    echo "Please use only two letters. Please run the script again."
fi
echo "OK. We will only include NordVPN IPs from $country."
echo " "
echo " "

read -rp "Please enter your NordVPN username: " userName
read -rsp  "Please enter your NordVPN password: " passWord
echo "...OK."
echo " "
echo " "

read -rp "Please enter your SSH port: " sshPort
echo "...OK."
echo " "
echo " "

echo "Checking your local network's IP range."
echo " "
ip addr | grep inet
echo " "
read -rp "Please enter your network's IP range (ex. 192.168.1.0/24): " networkRange
echo "...OK."
echo " "
echo " "



echo "Getting dependencies..."
echo "Install OpenVPN, UFW, Unzip, Curl, and Ping if they haven't been installed already."
echo " "
echo " "
apt install unzip -y
apt install openvpn -y
apt install ufw -y
apt install curl -y
apt install ping -y
echo " "
echo " "
echo "...done."
echo " "


echo "Get Nord OVPNs and save only 64 random UDP configs (the maximum allowed by OpenVPN)."
curl https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip -o ovpn.zip
unzip -qq -o ovpn.zip
rm -rf ovpn_tcp
rm ovpn.zip
echo "...done."
echo " "


echo "Start cleaning and making scripts"
# Get only files from country
mkdir ovpn_configs
#grep -lir '$country' ovpn_udp/* | xargs mv -t ovpn_configs
find . -type f -name "$country*" -exec mv -t ovpn_configs {} +

# Get only 64 IPs (maximum allowed by OpenVPN)
mkdir ovpn_selected
shuf -n 64 -e ovpn_configs/* | xargs -i mv {} ovpn_selected
grep -h  --exclude="ips.txt" "remote " ovpn_selected/* > ips.txt
sed -i 's/remote //' ips.txt
sed -i 's/ 1194//' ips.txt
sed 's/$/ port 1194 proto udp/' ips.txt > rules.txt

echo "...done."
echo " "


echo "Making scripts for adding and removing IPs to UFW."
sed 's/^/sudo ufw allow out to /' rules.txt > add-to-ufw.sh
sed 's/^/sudo ufw delete allow out to /' rules.txt > delete-from-ufw.sh
sed -i '1i#!/bin/bash\' add-to-ufw.sh
sed -i '1i#!/bin/bash\' delete-from-ufw.sh
chmod a+x add-to-ufw.sh
chmod a+x delete-from-ufw.sh
rm rules.txt
echo " "
echo " "
echo "Finished making script for adding NordVPN IPs to UFW. Run with: ./add-to-ufw.sh if needed later."
echo "Finished making script for removing NordVPN IPs from UFW. Run with: ./add-to-ufw.sh if needed later."
echo " "
echo " "


echo "Making login.txt file. Adding your UserName and Password to this file."
echo > /etc/openvpn/login.txt
sed -i "1i $passWord" /etc/openvpn/login.txt
sed -i "1i $userName" /etc/openvpn/login.txt
chown root:root /etc/openvpn/login.txt
chmod 400 /etc/openvpn/login.txt
echo "...done."
echo " "
echo " "


echo "Making OpenVPN configuration file. We will use this file to log into random NordVPN addresses from $country."
find ovpn_configs -type f | shuf -n 1 | xargs -i cp {} random-config.txt
sed '/remote /Q' random-config.txt > config-top.txt
sed -n '/resolv-retry infinite/,$p' random-config.txt > config-bottom.txt
sed 's/^/remote /' ips.txt > config-mid.txt
sed -i 's/$/ 1194/' config-mid.txt
cat config-top.txt config-mid.txt config-bottom.txt > nordvpn.ovpn
sed -i '/auth-user-pass/ s/$/ login.txt/' nordvpn.ovpn

# Cleaning Up Files
rm random-config.txt
rm config-top.txt
rm config-bottom.txt
rm config-mid.txt
rm ips.txt

echo "...done."
echo " "


# echo "Editing OpenVPN config to autostart our NordVPN config."
# mv nordvpn.ovpn /etc/openvpn/nordvpn.conf
# sed '/^#AUTOSTART="ALL"/a AUTOSTART="nordvpn"' /etc/default/openvpn
# systemctl daemon-reload
# systemctl restart openvpn
# echo "...done."
# echo " "
# echo " "


echo "Testing current IP addresses."
echo "Current IPs:"
host -4 myip.opendns.com resolver1.opendns.com
host myip.opendns.com resolver1.opendns.com
echo " "
echo " "


echo "Adding rules and starting UFW."
ufw allow $sshPort/tcp
ufw allow in to $networkRange
ufw allow out to $networkRange
source add-to-ufw.sh
# source delete-from-ufw.sh
ufw default deny outgoing
ufw default deny incoming
ufw allow out on tun0 from any to any
ufw --force enable 
systemctl enable ufw
echo "You can remove these UFW rules by running this script: sudo bash delete-from-ufw.sh"
echo "You can add these UFW rules again by running this script: add-to-ufw.sh"
echo " "
echo " "
echo " "
echo "Optionally use 'sudo ufw allow in on tun0 from any to any' if you are running a server."
echo "If anything doesn't work, disable and reset ufw with these commands: sudo ufw disable / sudo ufw reset"
echo " "
echo " "


echo "Starting and Autostarting OpenVPN"
mv nordvpn.ovpn /etc/openvpn/nordvpn.conf
systemctl start openvpn@nordvpn
systemctl enable openvpn@nordvpn

# Wait for OpenVPN to connect
sleep 10
echo "VPN'd IPs:"
host -4 myip.opendns.com resolver1.opendns.com
host myip.opendns.com resolver1.opendns.com
echo " "
echo " "
echo "Please check to see that the IP addresses before and after the UFW section are different (the vpn works). You can also try: sudo traceroute 8.8.8.8"
echo " "
echo "Testing for DNS leaks"
curl https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh -o dnsleaktest.sh
chmod +x dnsleaktest.sh
bash dnsleaktest.sh
echo " "
echo " "


echo "Cleaning up leftovers..."
# Clean up directories
rm -rf ovpn_configs
rm -rf ovpn_udp
rm -rf ovpn_selected
rm dnsleaktest.sh
echo "...done."
echo " "

# Use these to reset the script
# rm /etc/openvpn/login.txt
# rm /etc/openvpn/nordvpn.conf


echo "That's it! Please provide suggestions to improve this script."
echo " "
echo " "
echo " "
exit 0






# Thanks to https://www.comparitech.com/blog/vpn-privacy/how-to-make-a-vpn-kill-switch-in-linux-with-ufw/
# Thanks to https://gist.github.com/Necklaces/18b68e80bf929ef99312b2d90d0cded2
# Thanks to https://github.com/macvk/dnsleaktest
