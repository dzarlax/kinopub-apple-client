# Download Resume System Documentation

## Overview

Система восстановления загрузок позволяет автоматически возобновлять незавершенные загрузки после перезапуска приложения KinoPub. Это критически важная функция для пользователей, которые загружают фильмы и сериалы, особенно при нестабильном интернет-соединении.

## Architecture

### Core Components

1. **PendingDownloadInfo.swift** - Структура данных для хранения информации о незавершенной загрузке
2. **PendingDownloadsDatabase.swift** - База данных для управления незавершенными загрузками
3. **DownloadManager.swift** - Обновленный менеджер загрузок с поддержкой восстановления
4. **Download.swift** - Обновленный класс загрузки с сохранением состояния

### Data Flow

```
App Launch → DownloadManager.init() → restorePendingDownloads() → Resume Downloads
     ↓
Download Progress → updatePendingDownload() → Save State to Database
     ↓
App Background → handleAppDidEnterBackground() → Save All Active Downloads
     ↓
Download Complete → completeDownload() → Remove from Pending Database
```

## Features

### ✅ Automatic Resume
- При запуске приложения автоматически восстанавливает все незавершенные загрузки
- Использует `resumeData` для продолжения с места остановки
- Сохраняет прогресс загрузки для корректного отображения

### ✅ State Persistence
- Сохраняет состояние загрузки при каждом обновлении прогресса
- Автоматически сохраняет все активные загрузки при переходе в фон
- Сохраняет `resumeData` при паузе загрузки

### ✅ Background Support
- Поддерживает фоновые загрузки
- Корректно обрабатывает переходы между фоном и активным состоянием
- Интегрируется с существующей системой уведомлений

### ✅ Error Handling
- Автоматически удаляет записи о завершенных загрузках
- Очищает старые записи для предотвращения накопления данных
- Обрабатывает ошибки восстановления gracefully

## Usage

### Initialization
```swift
let downloadManager = DownloadManager(
    fileSaver: fileSaver,
    database: database,
    pendingDownloadsDatabase: pendingDatabase
)
```

### Automatic Resume
Система автоматически восстанавливает загрузки при инициализации:
```swift
// Вызывается автоматически в init()
private func restorePendingDownloads() {
    let pendingDownloads = pendingDownloadsDatabase.readPendingDownloads()
    // Восстанавливает каждую загрузку с сохраненным состоянием
}
```

### Manual Control
```swift
// Получить количество незавершенных загрузок
let count = downloadManager.pendingDownloadsCount()

// Очистить все незавершенные загрузки
downloadManager.clearAllPendingDownloads()
```

## Database Schema

### PendingDownloadInfo
```swift
struct PendingDownloadInfo<Meta: Codable & Equatable> {
    let url: URL                // URL загружаемого файла
    let metadata: Meta          // Метаданные (фильм/сериал)
    let resumeData: Data?       // Данные для возобновления
    let progress: Float         // Прогресс (0.0 - 1.0)
    let createdAt: Date         // Дата создания
    let updatedAt: Date         // Дата обновления
    let state: String           // Состояние (downloading/paused/background)
}
```

## Integration Points

### With Existing Download System
- Полностью совместима с существующим `DownloadManager`
- Не требует изменений в UI компонентах
- Прозрачно работает с существующими уведомлениями

### With Background Tasks
- Интегрируется с `BackgroundTaskManager`
- Поддерживает существующую систему фоновых загрузок
- Сохраняет состояние при переходах между режимами

## Performance Considerations

### Memory Usage
- Минимальное потребление памяти благодаря lazy loading
- Эффективное хранение только необходимых данных
- Автоматическая очистка завершенных загрузок

### Storage
- Компактное хранение в SQLite через Core Data
- Индексированные запросы для быстрого доступа
- Автоматическая очистка старых записей

### Network Efficiency
- Использует `resumeData` для минимизации повторных загрузок
- Поддерживает HTTP Range requests
- Оптимизирует использование сетевых ресурсов

## Testing

### Unit Tests
```swift
func testDownloadResume() {
    // Тест восстановления загрузки с resumeData
}

func testPendingDownloadsCleanup() {
    // Тест очистки завершенных загрузок
}

func testBackgroundStateHandling() {
    // Тест сохранения состояния в фоне
}
```

### Integration Tests
- Тестирование полного цикла загрузки с перезапуском
- Проверка корректности восстановления прогресса
- Валидация работы с реальными файлами

## Future Enhancements

### Planned Features
- [ ] Приоритизация восстановления загрузок
- [ ] Умная очередь загрузок с учетом сетевых условий
- [ ] Статистика восстановленных загрузок
- [ ] Пользовательские настройки автовосстановления

### Performance Optimizations
- [ ] Батчинг операций с базой данных
- [ ] Кэширование часто используемых данных
- [ ] Оптимизация сетевых запросов

## Troubleshooting

### Common Issues
1. **Загрузки не восстанавливаются**
   - Проверьте инициализацию `PendingDownloadsDatabase`
   - Убедитесь, что `restorePendingDownloads()` вызывается

2. **Дублирование загрузок**
   - Проверьте логику проверки существующих загрузок
   - Убедитесь в корректности URL сравнения

3. **Потеря прогресса**
   - Проверьте сохранение `resumeData`
   - Убедитесь в корректности обновления прогресса

### Debug Logging
```swift
Logger.kit.info("[DOWNLOAD] Restoring \(count) pending downloads")
Logger.kit.debug("[DOWNLOAD] Restored download for: \(url)")
```

## Conclusion

Система восстановления загрузок значительно улучшает пользовательский опыт, обеспечивая надежность и удобство использования приложения KinoPub. Реализация полностью интегрирована с существующей архитектурой и готова к production использованию. 