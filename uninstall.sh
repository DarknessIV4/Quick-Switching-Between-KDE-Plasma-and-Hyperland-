#!/bin/bash
set -u
sudo systemctl disable sddm-default-session.service sddm-default-plasma.service 2>/dev/null
sudo rm -f /etc/systemd/system/sddm-default-session.service /etc/systemd/system/sddm-default-plasma.service \
           /etc/sudoers.d/switch-session /usr/local/bin/switch-session \
           /etc/sddm.conf.d/zz-switch-autologin.conf /var/log/switch-session.log
sudo systemctl daemon-reload
rm -f ~/.local/bin/switch-with-outro ~/.local/bin/switch-now ~/.local/bin/outro-logout.lua \
      ~/.local/share/applications/switch-to-hyprland.desktop ~/.cache/switch-outro.log \
      ~/session-switch-instructions.txt
kwriteconfig6 --file kglobalshortcutsrc --group services --group switch-to-hyprland.desktop --key _launch --delete 2>/dev/null
kwriteconfig6 --file kwinrc --group Plugins --key switchintroEnabled false 2>/dev/null
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null
kpackagetool6 --type KWin/Effect --remove switchintro 2>/dev/null
[ -f ~/.config/hypr/hyprland.lua ] && sed -i '/>>> session-switch/,/<<< session-switch/d' ~/.config/hypr/hyprland.lua
kbuildsycoca6 >/dev/null 2>&1
echo "Removed."
