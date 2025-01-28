#!/bin/bash

# Удаляем ярлык на рабочем столе (если он существует)
DESKTOP_DIR=$(xdg-user-dir DESKTOP)
DESKTOP_FILE="$DESKTOP_DIR/npos-api-control.desktop"
if [ -f "$DESKTOP_FILE" ]; then
    echo "Удаляем ярлык $DESKTOP_FILE..."
    rm -f "$DESKTOP_FILE"
fi

# Директория для установки
INSTALL_DIR="$HOME/wildberries/offline/npos-api"
APP_NAME="npos-api"  # Имя приложения
SCRIPT_NAME="npos-api-manager"  # Имя управляющего скрипта
SERVICE_NAME="npos-api-manager"  # Имя сервиса

# Путь к рабочему столу
DESKTOP_DIR=$(xdg-user-dir DESKTOP)
if [ -z "$DESKTOP_DIR" ]; then
    echo "Ошибка: Не удалось определить путь к рабочему столу."
    exit 1
fi

# Создание директории, если она не существует
mkdir -p "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось создать директорию $INSTALL_DIR."
    exit 1
fi

# Удаление старого файла, если он существует
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    echo "Удаление старого файла $INSTALL_DIR/$SCRIPT_NAME..."
    rm -f "$INSTALL_DIR/$SCRIPT_NAME"
fi

# Копирование управляющего скрипта в директорию
echo "Создание управляющего скрипта $INSTALL_DIR/$SCRIPT_NAME..."
cat << 'EOF' > "$INSTALL_DIR/$SCRIPT_NAME"
#!/bin/bash

# Цвета для вывода в терминал
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# Пути
APP_PATH="$HOME/wildberries/offline/npos-api/npos-api"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="npos-api-manager"  # Имя сервиса
SERVICE_FILE="$USER_SERVICE_DIR/$SERVICE_NAME.service"

# Проверка, запущен ли сервис
is_running() {
    systemctl --user is-active "$SERVICE_NAME" > /dev/null 2>&1
    return $?
}

# Внутренняя функция для установки/обновления
_install_app() {
    echo -e "${YELLOW}Загружаем и распаковываем Офлайн...${RESET}"
    mkdir -p "$HOME/wildberries/offline"
    wget --no-check-certificate \
        "https://static-basket-02.wbbasket.ru/vol24/branch_office_apps/offline-plus/latest.tar.gz" \
        -O /tmp/latest.tar.gz
    tar -xzf /tmp/latest.tar.gz -C "$HOME/wildberries/offline"
    rm -f /tmp/latest.tar.gz
    echo -e "${GREEN}Файлы успешно обновлены/установлены.${RESET}"
}

# Установка приложения
install() {
    if [ -f "$APP_PATH" ]; then
        echo -e "${YELLOW}Офлайн уже установлен.${RESET}"
        return
    fi

    _install_app
    echo -e "${GREEN}Установка завершена.${RESET}"
}

# Обновление приложения
update() {
    echo -e "${YELLOW}Обновляем Офлайн...${RESET}"
    _install_app
    restart
    echo -e "${GREEN}Обновление завершено.${RESET}"
}

# Запуск приложения через systemd
start() {
    if is_running; then
        echo -e "${GREEN}Офлайн уже запущен.${RESET}"
        return
    fi

    if [ ! -f "$APP_PATH" ]; then
        echo -e "${YELLOW}Офлайн не найден. Устанавливаем...${RESET}"
        install
    fi

    # Создаём systemd сервис, если он не существует
    if [ ! -f "$SERVICE_FILE" ]; then
        mkdir -p "$USER_SERVICE_DIR"
        cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=npos-api Manager
After=network.target

[Service]
ExecStart=$APP_PATH
Restart=always
RestartSec=3
StandardOutput=syslog
StandardError=syslog
WorkingDirectory=$(dirname "$APP_PATH")

[Install]
WantedBy=default.target
EOL
        systemctl --user daemon-reload
        systemctl --user enable "$SERVICE_NAME"
    fi

    systemctl --user start "$SERVICE_NAME"
    echo -e "${GREEN}Офлайн запущен через systemd.${RESET}"
}

# Проверка статуса приложения
status() {
    if is_running; then
        echo -e "${GREEN}Офлайн запущен.${RESET}"
    else
        echo -e "${RED}Офлайн не работает.${RESET}"
    fi
}

# Остановка приложения
stop() {
    echo -e "${YELLOW}Останавливаем Офлайн...${RESET}"
    systemctl --user stop "$SERVICE_NAME"
    echo -e "${RED}Офлайн остановлен.${RESET}"
}

# Перезапуск приложения
restart() {
    stop
    start
}

# Очистка экрана
clear_screen() {
    clear
}

# Интерактивное меню
interactive_menu() {
    while true; do
        echo -e "\nУправление Офлайн:"
        echo "1) Запустить Офлайн"
        echo "2) Проверить статус Офлайн"
        echo "3) Остановить Офлайн"
        echo "4) Перезапустить Офлайн"
        echo "5) Обновить Офлайн"
        echo "6) Выйти"
        read -p "Выберите опцию: " choice

        case $choice in
            1) clear_screen; start ;;
            2) clear_screen; status ;;
            3) clear_screen; stop ;;
            4) clear_screen; restart ;;
            5) clear_screen; update ;;
            6) break ;;
            *) echo -e "${RED}Неверный выбор. Попробуйте снова.${RESET}" ;;
        esac
    done
}

# Основная логика
if [ $# -eq 0 ]; then
    interactive_menu
else
    case $1 in
        install) install ;;
        update) update ;;
        start) start ;;
        status) status ;;
        stop) stop ;;
        restart) restart ;;
        *) echo -e "${RED}Неверная команда. Используйте: install, update, start, status, stop, restart${RESET}" ;;
    esac
fi
EOF

# Делаем управляющий скрипт исполняемым
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Проверяем наличие файла приложения (npos-api) перед созданием systemd сервиса
if [ -f "$INSTALL_DIR/$APP_NAME" ]; then
    # Создание systemd сервиса
    echo "Создание systemd сервиса..."
    SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"

    cat <<EOL > "$SERVICE_DIR/$SERVICE_NAME.service"
[Unit]
Description=npos-api Manager
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$APP_NAME
Restart=always
RestartSec=3
StandardOutput=syslog
StandardError=syslog
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=default.target
EOL

    # Включение и запуск сервиса
    echo "Включение и запуск сервиса..."
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user start "$SERVICE_NAME"
else
    echo "Приложение не установлено. Пропускаем создание systemd сервиса."
fi

# Путь к директории для логотипа
ICON_DIR="$HOME/wildberries/offline"
ICON_URL="https://offline-promo.wildberries.ru/images/icons/logo.svg"
ICON_FILE="$ICON_DIR/logo.svg"

# Проверка и создание директории для логотипа
mkdir -p "$ICON_DIR"

# Скачивание лого
echo "Скачиваем лого..."
wget -q --no-check-certificate "$ICON_URL" -O "$ICON_FILE"

# Создание ярлыка на рабочем столе
echo "Создание ярлыка на рабочем столе..."
DESKTOP_FILE="$DESKTOP_DIR/npos-api.desktop"

cat <<EOL > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=npos-api Manager
Comment=Управление npos-api
Exec=$INSTALL_DIR/$SCRIPT_NAME
Icon=$ICON_FILE
Terminal=true
Categories=Development;
EOL

chmod +x "$DESKTOP_FILE"

echo "Установка завершена! Ярлык создан на рабочем столе."
