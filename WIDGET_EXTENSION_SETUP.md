# 📱 Настройка Widget Extension для Live Activities

## 🎯 Пошаговая инструкция

### **Шаг 1: Создание Widget Extension в Xcode**

1. Откройте проект в Xcode:
   ```bash
   open KinoPubAppleClient.xcodeproj
   ```

2. **File → New → Target**

3. Выберите **Widget Extension**:
   ```
   iOS ← Platform
   Widget Extension ← Product
   ```

4. Настройки target:
   ```
   Product Name: KinoPubWidgetExtension
   Team: [Ваш Developer Team]
   Bundle Identifier: com.dzarlax.kinopub.widgetextension
   Language: Swift
   Include Configuration Intent: ❌
   Include Live Activity: ✅ (ВАЖНО!)
   ```

5. **Activate "KinoPubWidgetExtension" scheme?** → **Activate**

### **Шаг 2: Замена файлов**

Запустите наш скрипт для автоматического копирования:

```bash
./setup_widget_extension.sh
```

**Или вручную скопируйте файлы:**
- `KinoPubWidgetExtension/` → `KinoPubAppleClient/KinoPubWidgetExtension/`

### **Шаг 3: Настройка Bundle Identifier**

В **KinoPubWidgetExtension → Build Settings**:
```
Bundle Identifier: com.dzarlax.kinopub.widgetextension
```

### **Шаг 4: Проверка Dependencies**

В **KinoPubWidgetExtension → Build Phases → Link Binary with Libraries**:
- ✅ `WidgetKit.framework`
- ✅ `SwiftUI.framework` 
- ✅ `ActivityKit.framework`

### **Шаг 5: Build и Test**

```bash
# Сборка с Widget Extension
xcodebuild -scheme KinoPubAppleClient build

# Запуск на симуляторе
xcodebuild -scheme KinoPubAppleClient \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=latest" \
  build
```

## 🔧 Apple Developer Console

### **Настройка App ID:**
1. **App IDs** → **Configure**
2. **Capabilities** → **Live Activities** ✅
3. **Save Configuration**

### **Provisioning Profile:**
1. **Profiles** → **Edit**
2. **Re-generate** с новыми capabilities
3. **Download** и установите

## 📱 Тестирование

### **Включить Live Activities на устройстве:**
```
Settings → Face ID & Passcode → Live Activities: ✅
Settings → Notifications → [KinoPub] → Live Activities: ✅
```

### **Запуск Live Activity:**
1. Откройте KinoPub app
2. Начните загрузку видео
3. Live Activity должна появиться на Lock Screen

## 🐛 Troubleshooting

### **Ошибка: "Live Activities not supported"**
- ✅ iOS 26+ симулятор/устройство
- ✅ Live Activities включены в настройках
- ✅ Правильные entitlements

### **Ошибка: "BGContinuedProcessingTask failed"**
- ✅ Background App Refresh включен
- ✅ Правильные background modes в Info.plist
- ✅ Task identifiers настроены

### **Live Activity не появляется:**
- ✅ Widget Extension правильно настроен
- ✅ DownloadActivityAttributes экспортирован
- ✅ LiveActivityManager интегрирован в DownloadManager

## 📋 Проверочный список

- [ ] Widget Extension создан в Xcode
- [ ] Live Activity опция включена при создании
- [ ] Файлы скопированы из `KinoPubWidgetExtension/`
- [ ] Bundle Identifier настроен
- [ ] Build успешно
- [ ] Apple Developer настройки обновлены
- [ ] Live Activities включены в iOS Settings
- [ ] Тестирование на устройстве/симуляторе

## 🎉 Результат

После успешной настройки вы получите:

### **Lock Screen:**
```
┌─────────────────────────────┐
│ 🎬 Железный человек         │
│ Серия 1 из 10               │
│ ████████░░ 80%              │  
│ 45 MB/s • 2 мин осталось    │
│ [⏸️] [❌]                   │
└─────────────────────────────┘
```

### **Dynamic Island (iPhone 14 Pro+):**
```
Compact: [🎬 80%] 
Minimal: [📥]
Expanded: Full progress + controls
``` 