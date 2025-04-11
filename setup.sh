#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo -e "\e[31mThis script must be run as root.\e[0m"
  echo "Usage: sudo $0"
  exit 1
fi

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
  "default_entry: 2"
)

# Search for limine.conf recursively under /boot
find_limine_conf() {
  find /boot -type f -name "limine.conf" 2>/dev/null | head -n 1
}

# Ask the user if they want to reboot
prompt_reboot() {
  echo
  read -rp "$(echo -e "${YELLOW}Do you want to reboot now to apply the changes? [y/N]: ${RESET}")" reboot
  if [[ "$reboot" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Rebooting...${RESET}"
    reboot
  else
    echo -e "${GREEN}Operation completed. Please reboot later to apply the changes.${RESET}"
  fi
}

# Install the theme and modify limine.conf
install_theme() {
  limine_conf=$(find_limine_conf)
  if [[ -z "$limine_conf" ]]; then
    echo -e "${RED}Error:${RESET} limine.conf not found in /boot."
    return
  fi

  echo -e "${GREEN}Found:${RESET} $limine_conf"
  backup_file="${limine_conf}${BACKUP_SUFFIX}"
  create_backup=true

  if [[ -f "$backup_file" ]]; then
    read -rp "$(echo -e "${YELLOW}A backup already exists. Overwrite it? [y/N]: ${RESET}")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      cp "$limine_conf" "$backup_file"
      echo -e "${GREEN}Backup overwritten:${RESET} $backup_file"
    else
      echo -e "${YELLOW}Continuing without modifying the existing backup.${RESET}"
      create_backup=false
    fi
  else
    cp "$limine_conf" "$backup_file"
    echo -e "${GREEN}Backup created:${RESET} $backup_file"
  fi

  echo -e "${CYAN}Removing old parameters...${RESET}"
  for param in "${PARAMS[@]}"; do
    key="${param%%:*}"
    sed -i "/^$key:/d" "$limine_conf"
  done

  echo -e "${CYAN}Adding new parameters to the top...${RESET}"
  temp_file=$(mktemp)
  printf '%s\n' "${PARAMS[@]}" | cat - "$limine_conf" > "$temp_file"
  mv "$temp_file" "$limine_conf"

  theme_dir=$(dirname "$limine_conf")
  echo -e "${CYAN}Copying theme image to $theme_dir...${RESET}"
  cp "./cachyos.png" "$theme_dir/"

  echo -e "${GREEN}${BOLD}Theme installed successfully!${RESET}"

  prompt_reboot
}

# Restore the backup and remove the theme
remove_theme() {
  limine_conf=$(find_limine_conf)
  if [[ -z "$limine_conf" ]]; then
    echo -e "${RED}Error:${RESET} limine.conf not found in /boot."
    return
  fi

  echo -e "${GREEN}Found:${RESET} $limine_conf"
  backup_file="${limine_conf}${BACKUP_SUFFIX}"

  if [[ ! -f "$backup_file" ]]; then
    echo -e "${RED}No backup found to restore.${RESET}"
    return
  fi

  echo -e "${CYAN}Restoring backup...${RESET}"
  cp "$backup_file" "$limine_conf"
  rm -f "$backup_file"

  theme_dir=$(dirname "$limine_conf")
  echo -e "${CYAN}Removing theme image from $theme_dir...${RESET}"
  rm -f "$theme_dir/cachyos.png"

  echo -e "${GREEN}${BOLD}Theme removed and backup restored!${RESET}"

  prompt_reboot
}

# Function to choose the editor
choose_editor() {
    echo
    echo "Choose a text editor to open the file:"
    echo "1) nano"
    echo "2) micro"
    echo "3) vim"
    echo "4) vi"
    echo "5) ne"
    echo "6) joe"
    echo "7) emacs (terminal mode)"
    echo "8) other (type the name)"
    read -rp "Option [1-8]: " choice

    case "$choice" in
        1) editor_cmd="nano" ;;
        2) editor_cmd="micro" ;;
        3) editor_cmd="vim" ;;
        4) editor_cmd="vi" ;;
        5) editor_cmd="ne" ;;
        6) editor_cmd="joe" ;;
        7) editor_cmd="emacs -nw" ;;
        8)
            read -rp "Enter the editor name: " editor_cmd
            ;;
        *)
            echo "Invalid option. Using nano as default."
            editor_cmd="nano"
            ;;
    esac

    local editor_bin
    editor_bin=$(awk '{print $1}' <<< "$editor_cmd")

    if ! command -v "$editor_bin" >/dev/null 2>&1; then
        echo
        echo "[ERROR] The editor '$editor_bin' is not installed on the system."
        echo "Install it before trying again."
        echo
        return 1
    fi
}

# Function to pause (for consistent user interaction)
pause() {
    echo
    read -r -p "Press Enter to return to the main menu..." < /dev/tty
    clear
}

# Manually edit limine.conf using the selected editor
edit_limine_conf() {
    limine_conf=$(find_limine_conf)
    if [[ -z "$limine_conf" ]]; then
        echo -e "${RED}Error:${RESET} limine.conf not found in /boot."
        pause
        return
    fi

    choose_editor || {
        echo -e "${RED}Editor selection canceled.${RESET}"
        pause
        return
    }

    echo -e "${GREEN}Opening:${RESET} $limine_conf with: ${YELLOW}$editor_cmd${RESET}"
    sleep 1
    $editor_cmd "$limine_conf"
    echo -e "${GREEN}Editing completed.${RESET}"
    pause
}


# Main menu loop
while true; do
  clear
  echo
  echo -e "${BOLD}Choose an option:${RESET}"
  echo -e "${CYAN}1)${RESET} Install theme"
  echo -e "${CYAN}2)${RESET} Remove theme and restore backup"
  echo -e "${CYAN}3)${RESET} Edit limine.conf manually"
  echo -e "${RED}4)${RESET} Exit"
  read -rp "$(echo -e "${YELLOW}Option: ${RESET}")" option

  case "$option" in
    1) clear; install_theme ;;
    2) clear; remove_theme ;;
    3) clear; edit_limine_conf ;;
    4) echo -e "${YELLOW}Exiting.${RESET}"; exit 0 ;;
    *) echo -e "${RED}Invalid option.${RESET}"; sleep 1 ;;
  esac
done
