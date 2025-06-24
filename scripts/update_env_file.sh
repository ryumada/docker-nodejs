#!/bin/bash

# This script updates the .env file from $TEMPLATE_ENV_FILE then add the value from the old .env.

function getDate() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")]"
}

function main() {
  CURRENT_DIR=$(dirname "$(readlink -f "$0")")
  CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
  PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
  SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
  REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

  TEMPLATE_ENV_FILE=${1:-.env.example}
  BACKUP_ENV_FILE=${2:-.env.bak}

  echo "-------------------------------------------------------------------------------"
  echo " UPDATE ENV FILE FOR $SERVICE_NAME @ $(date +"%A, %d %B %Y %H:%M %Z")"
  echo "-------------------------------------------------------------------------------"

  echo "$(getDate) Path to Odoo: $PATH_TO_ROOT_REPOSITORY"
  cd "$PATH_TO_ROOT_REPOSITORY" || exit 1

  if [ -f "$PATH_TO_ROOT_REPOSITORY/.env" ]; then
    echo "$(getDate) Backup current .env file"
    cp "$PATH_TO_ROOT_REPOSITORY/.env" "$BACKUP_ENV_FILE"
    chown "$REPOSITORY_OWNER": "$BACKUP_ENV_FILE"
  else
    echo "$(getDate) $PATH_TO_ROOT_REPOSITORY/.env file not found. Backup skipped"
  fi

  if [ -f "$PATH_TO_ROOT_REPOSITORY/$TEMPLATE_ENV_FILE" ]; then
    echo "$(getDate) Copy $PATH_TO_ROOT_REPOSITORY/$TEMPLATE_ENV_FILE to .env"
    cp "$PATH_TO_ROOT_REPOSITORY/$TEMPLATE_ENV_FILE" "$PATH_TO_ROOT_REPOSITORY/.env"
  else
    echo "$(getDate) $PATH_TO_ROOT_REPOSITORY/$TEMPLATE_ENV_FILE file not found."
    exit 1
  fi

  if [ -f "$BACKUP_ENV_FILE" ]; then
    echo "$(getDate) Importing values from $BACKUP_ENV_FILE to .env"
    while IFS= read -r line; do
      if [[ "$line" =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*= ]]; then # Check if line is a variable assignment
        variable_name=$(echo "$line" | cut -d'=' -f1)
        variable_value=$(echo "$line" | cut -d'=' -f2-)

        if grep -q "^$variable_name=" .env && [ -n "$variable_value" ]; then
          echo "$(getDate) 🟦 Update $variable_name"
          sed -i "s|^$variable_name=.*|$variable_name=$variable_value|" .env
        fi
      fi
    done < "$BACKUP_ENV_FILE"
  else
    echo "$(getDate) 🔴 $BACKUP_ENV_FILE file not found. Import skipped."
  fi

  echo "$(getDate) Update .env file with current user and group."
  chown "$REPOSITORY_OWNER": "$PATH_TO_ROOT_REPOSITORY/.env"

  echo "$(getDate) ✅ Update finished"
}

main "$@"
