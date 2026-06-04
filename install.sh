#!/bin/bash
set -e

# Copy .config
echo "Copy config files"
cp -R resources/.config ~/
cp -R resources/.icons ~/
cp -R resources/.local ~/
# Copy .dot file user
echo "Copy dot files"
cp resources/.Xresources ~/
cp resources/.zshrc ~/
cp resources/.bashrc ~/
cp resources/.profile ~/
cp resources/.gtkrc-2.0 ~/
sudo cp resources/environment /etc/environment
# Install packages
echo "Install official packages"
sudo pacman -S --needed --noconfirm - < packages
# Install packages aur
echo "Install aur packages"
yay -S --needed --noconfirm - < packages-aur
# Wallpaper
echo "Set wallpaper"
cp resources/wallpaper.jpg ~/Pictures
nitrogen --set-auto ~/Pictures/wallpaper.jpg
echo "Install ohmyzsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
echo "Create ln to the plugins for zsh"
ln -s /usr/share/zsh/plugins/zsh-syntax-highlighting ~/.oh-my-zsh/plugins 
ln -s /usr/share/zsh/plugins/zsh-autosuggestions ~/.oh-my-zsh/plugins 


# Activate lightdm
sudo cp resources/etc/lightdm/* /etc/lightdm/
systemctl enable lightdm

#Change shell to zsh
sudo chsh -s /usr/bin/zsh $USER
