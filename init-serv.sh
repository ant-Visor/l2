#!/usr/bin/env bash
# Использование:
# wget -qO "init-serv.sh" "https://raw.githubusercontent.com/ant-Visor/l2/refs/heads/main/init-serv.sh" && bash init-serv.sh

GITHUB_USERNAME="ant-Visor"
PROJ="legasy" # репозиторий для которого настраиваем

if [ -z "$GITHUB_USERNAME" ] || [ -z "$PROJ" ]; then
  echo "❌ Не переданы аргументы: GITHUB_USERNAME PROJ"
  exit 1
fi

# ================================================================ #
setup_apt() {
  sudo apt-get update -q
  sudo apt-get install -q -y vim git curl

  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker "$USER"
    echo "⚠️  Добавлен в группу docker. Для применения перелогинься или выполни: newgrp docker"
  fi
  echo "✅ Docker установлен"

  if ! docker compose version >/dev/null 2>&1 ; then
    sudo apt-get install -q -y docker-compose-plugin
  fi
  echo "✅ Docker Compose установлен"
}

# ================================================================ #
setup_ssh() {
  mkdir -p  "$HOME/.ssh/keys/${PROJ}" "$HOME/.ssh/services"
  chmod 700 "$HOME/.ssh/keys"         "$HOME/.ssh/services"

  # Генерация ключей
  ssh-keygen -t ed25519 -C "github_${PROJ}" -f "$HOME/.ssh/keys/${PROJ}/id_github" -N "" -q
  ssh-keygen -t ed25519 -C "deploy_${PROJ}" -f "$HOME/.ssh/keys/${PROJ}/id_deploy" -N "" -q
  echo "✅ Ключи созданы в $HOME/.ssh/keys/${PROJ}"

  # Добавляем deploy-ключ в authorized_keys
  mkdir -p $HOME/.ssh
  cat "$HOME/.ssh/keys/${PROJ}/id_deploy.pub" >> "$HOME/.ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
  echo "✅ deploy.pub добавлен в authorized_keys"

  # Главный ssh config (Include только если ещё нет)
  if ! grep -q "Include services/\*.conf" "$HOME/.ssh/config" 2>/dev/null ; then
    cat > "$HOME/.ssh/config" << 'EOF'
# Include service configs
Include services/*.conf

# Global defaults
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    echo "✅ Создан $HOME/.ssh/config"
  fi

  # Конфиг проекта (перезаписываем)
  cat > "$HOME/.ssh/services/${PROJ}.conf" << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile $HOME/.ssh/keys/${PROJ}/id_github
    IdentitiesOnly yes
EOF
  echo "✅ Создан $HOME/.ssh/services/${PROJ}.conf"

  # Итоговые инструкции
  echo ""
  echo " ___________________________________________"
  echo "|  🔑 ПУБЛИЧНЫЙ КЛЮЧ ДЛЯ GITHUB DEPLOY KEY |"
  echo "|___________________________________________|"
  echo "Добавьте на:"
  echo "https://github.com/${GITHUB_USERNAME}/${PROJ}/settings/keys/new"
  echo ""
  cat "$HOME/.ssh/keys/${PROJ}/id_github.pub"

  echo ""
  echo " ___________________________________________"
  echo "| 🔐 ПРИВАТНЫЙ КЛЮЧ ДЛЯ GITHUB SECRET       |"
  echo "|___________________________________________|"
  echo "Добавьте на:"
  echo "https://github.com/${GITHUB_USERNAME}/${PROJ}/settings/secrets/actions/new"
  echo "Имя секрета: SERVER_SSH_KEY"
  echo ""
  cat "$HOME/.ssh/keys/${PROJ}/id_deploy"

  echo ""
  echo " ___________________________________________"
  echo "|                                           |"
  echo "|         ✅ Настройка завершена!           |"
  echo "|___________________________________________|"
  echo "  Остальные GitHub Secrets:"
  echo "    SERVER_HOST = $(wget -qO- icanhazip.com 2>/dev/null)"
  echo "    SERVER_USER = $(whoami)"
  echo "    SERVER_PORT = 22"
  echo ""
  echo "  Следующие шаги на сервере:"
  echo "    cd ~"
  echo "    git clone git@github.com:${GITHUB_USERNAME}/${PROJ}.git"
  echo "    cd ${PROJ}"
  echo "    cp cred.ini.example cred.ini && nano cred.ini"
  echo "    docker compose up -d"
  echo "_____________________________________________"
}

# ================================================================ #
echo ""
echo "======================================="
echo "  Настройка сервера: $PROJ"
echo "======================================="
echo ""

setup_apt

# Проверка существующих ключей
if [ -f "$HOME/.ssh/keys/${PROJ}/id_github" ] || [ -f "$HOME/.ssh/keys/${PROJ}/id_deploy" ]; then
  echo ""
  echo "⚠️  Ключи для $PROJ уже существуют:"
  ls -la "$HOME/.ssh/keys/${PROJ}/"
  echo ""
fi

echo ""
read -rn1 -p "Настроить SSH ключи? (y/n): "; echo
[ "${REPLY,,}" = "y" ] && setup_ssh
