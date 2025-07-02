#!/bin/bash

echo "🚀 Настройка Widget Extension для Live Activities..."

# Проверяем, что Widget Extension target создан в Xcode
WIDGET_TARGET_PATH="KinoPubAppleClient/KinoPubWidgetExtension"
if [ ! -d "$WIDGET_TARGET_PATH" ]; then
    echo "❌ Widget Extension target не найден в $WIDGET_TARGET_PATH"
    echo ""
    echo "   📋 Сначала создайте Widget Extension через Xcode:"
    echo "   1. File → New → Target"
    echo "   2. iOS → Widget Extension"
    echo "   3. Product Name: KinoPubWidgetExtension"
    echo "   4. Include Live Activity: ✅"
    echo "   5. Activate scheme: ✅"
    echo ""
    echo "   После создания запустите этот скрипт снова"
    exit 1
fi

echo "✅ Widget Extension target найден"

# Создаём backup существующих файлов
echo "📦 Создание backup существующих файлов..."
backup_dir="$WIDGET_TARGET_PATH/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Backup существующих файлов если они есть
if [ -f "$WIDGET_TARGET_PATH/KinoPubWidgetExtensionBundle.swift" ]; then
    cp "$WIDGET_TARGET_PATH"/*.swift "$backup_dir/" 2>/dev/null || true
    cp "$WIDGET_TARGET_PATH/Info.plist" "$backup_dir/" 2>/dev/null || true
    echo "✅ Backup создан в $backup_dir"
fi

# Копируем наши файлы
echo "📂 Копирование файлов Live Activities..."

cp "KinoPubWidgetExtension/KinoPubWidgetExtensionBundle.swift" "$WIDGET_TARGET_PATH/"
echo "✅ Скопирован KinoPubWidgetExtensionBundle.swift"

cp "KinoPubWidgetExtension/DownloadActivityAttributes.swift" "$WIDGET_TARGET_PATH/"
echo "✅ Скопирован DownloadActivityAttributes.swift"

cp "KinoPubWidgetExtension/DownloadLiveActivityWidget.swift" "$WIDGET_TARGET_PATH/"
echo "✅ Скопирован DownloadLiveActivityWidget.swift"

cp "KinoPubWidgetExtension/DownloadLiveActivityViews.swift" "$WIDGET_TARGET_PATH/"
echo "✅ Скопирован DownloadLiveActivityViews.swift"

cp "KinoPubWidgetExtension/Info.plist" "$WIDGET_TARGET_PATH/"
echo "✅ Скопирован Info.plist"

# Проверяем, что все файлы скопированы
echo ""
echo "🔍 Проверка скопированных файлов..."
for file in "KinoPubWidgetExtensionBundle.swift" "DownloadActivityAttributes.swift" "DownloadLiveActivityWidget.swift" "DownloadLiveActivityViews.swift" "Info.plist"; do
    if [ -f "$WIDGET_TARGET_PATH/$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - НЕ НАЙДЕН!"
    fi
done

echo ""
echo "🎉 Настройка Widget Extension завершена!"
echo ""
echo "📝 Следующие шаги в Xcode:"
echo "1. Очистите проект: Product → Clean Build Folder"
echo "2. Пересоберите проект: Product → Build"
echo "3. Убедитесь, что Widget Extension target добавлен в Dependencies основного приложения"
echo "4. Проверьте Bundle Identifier для Widget Extension: com.dzarlax.kinopub.widgetextension"
echo ""
echo "🔗 Полезные ссылки:"
echo "• Документация по Widget Extension: https://developer.apple.com/documentation/widgetkit"
echo "• Live Activities Guide: https://developer.apple.com/documentation/activitykit"

echo ""
echo "📱 Для тестирования Live Activities:"
echo "1. Включите Background App Refresh"
echo "2. Включите Live Activities в настройках iOS"
echo "3. Запустите загрузку файла в приложении" 