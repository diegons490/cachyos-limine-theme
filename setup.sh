#!/bin/bash

set -e

# Color definitions
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"
BOLD="\e[1m"

THEME_NAME="cachyos"
BACKUP_SUFFIX=".bak-$THEME_NAME"
PARAMS=(
  "term_palette: 1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
  "term_palette_bright: 585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
  "term_background: ffffffff"
  "term_foreground: cdd6f4"
  "term_background_bright: ffffffff"
  "term_foreground_bright: cdd6f4"
  "timeout: 10"
  "wallpaper: boot():/cachyos.png"
  "interface_branding:"
)

find_limine_conf() {
  find /boot -type f -name "limine.conf" 2>/dev/null | head -n 1
}

prompt_reboot() {
  echo
  read -rp "$(echo -e "${YELLOW}Do you want to reboot now to apply the changes? [y/N]: ${RESET}")" reboot
  if [[ "$reboot" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Rebooting...${RESET}"
    sudo reboot
  else
    echo -e "${GREEN}Operation completed. Reboot later to apply the changes.${RESET}"
    exit 0
  fi
}

install_theme() {
  echo -e "${CYAN}Searching for limine.conf...${RESET}"
  limine_conf=$(find_limine_conf)

  if [[ -z "$limine_conf" ]]; then
    echo -e "${RED}Error:${RESET} limine.conf not found under /boot."
    exit 1
  fi

  echo -e "${GREEN}Found:${RESET} $limine_conf"

  backup_file="${limine_conf}${BACKUP_SUFFIX}"
  create_backup=true

  if [[ -f "$backup_file" ]]; then
    read -rp "$(echo -e "${YELLOW}A backup already exists. Overwrite it? [y/N]: ${RESET}")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      sudo cp "$limine_conf" "$backup_file"
      echo -e "${GREEN}Backup overwritten:${RESET} $backup_file"
    else
      echo -e "${YELLOW}Proceeding without modifying the existing backup.${RESET}"
      create_backup=false
    fi
  else
    sudo cp "$limine_conf" "$backup_file"
    echo -e "${GREEN}Backup created:${RESET} $backup_file"
  fi

  echo -e "${CYAN}Cleaning previous theme parameters...${RESET}"
  for param in "${PARAMS[@]}"; do
    key="${param%%:*}"
    sudo sed -i "/^$key:/d" "$limine_conf"
  done

  echo -e "${CYAN}Adding new parameters to the top...${RESET}"
  temp_file=$(mktemp)
  printf '%s\n' "${PARAMS[@]}" | cat - "$limine_conf" | sudo tee "$temp_file" > /dev/null
  sudo mv "$temp_file" "$limine_conf"

  theme_dir=$(dirname "$limine_conf")
  echo -e "${CYAN}Copying theme image to $theme_dir...${RESET}"
  sudo cp "./cachyos.png" "$theme_dir/"

  echo -e "${GREEN}${BOLD}Theme installed successfully!${RESET}"

  prompt_reboot
}

remove_theme() {
  echo -e "${CYAN}Searching for limine.conf...${RESET}"
  limine_conf=$(find_limine_conf)

  if [[ -z "$limine_conf" ]]; then
    echo -e "${RED}Error:${RESET} limine.conf not found under /boot."
    exit 1
  fi

  echo -e "${GREEN}Found:${RESET} $limine_conf"

  backup_file="${limine_conf}${BACKUP_SUFFIX}"

  if [[ ! -f "$backup_file" ]]; then
    echo -e "${RED}No backup file found to restore.${RESET}"
    exit 1
  fi

  echo -e "${CYAN}Restoring backup...${RESET}"
  sudo cp "$backup_file" "$limine_conf"
  sudo rm -f "$backup_file"

  theme_dir=$(dirname "$limine_conf")
  echo -e "${CYAN}Removing theme image from $theme_dir...${RESET}"
  sudo rm -f "$theme_dir/cachyos.png"

  echo -e "${GREEN}${BOLD}Theme removed and backup restored!${RESET}"

  prompt_reboot
}

while true; do
  echo
  echo -e "${BOLD}Choose an option:${RESET}"
  echo -e "${CYAN}1)${RESET} Install theme"
  echo -e "${CYAN}2)${RESET} Remove theme and restore backup"
  echo -e "${CYAN}3)${RESET} Cancel"
  read -rp "$(echo -e "${YELLOW}Option: ${RESET}")" option

  case "$option" in
    1) install_theme; break ;;
    2) remove_theme; break ;;
    3) echo -e "${YELLOW}Cancelled.${RESET}"; exit 0 ;;
    *) echo -e "${RED}Invalid option.${RESET}" ;;
  esac
done
