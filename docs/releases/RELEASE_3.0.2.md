# iFetch 3.0.2

This update fixes Wi-Fi information and the Control Center module on rootless jailbreaks.

## Fixed

- Improved Wi-Fi SSID and BSSID detection on iOS 14–17
- Added a MobileWiFi fallback when public iOS APIs return empty values
- Added the required Wi-Fi entitlement for rootless environments
- Fixed iFetch not appearing in the Control Center module list
- Added the missing CCSupport module metadata
- CCSupport is now installed as a required dependency

## Compatibility

- iOS 14–17
- Rootless jailbreaks only
- `iphoneos-arm64`

After installing the update, perform a **Userspace Reboot**. Allow location access when opening Network Details so iFetch can use the standard iOS Wi-Fi APIs.

---

# iFetch 3.0.2 — русский

В этом обновлении исправлено отображение информации о Wi-Fi и работа модуля Control Center на rootless-джейлбрейках.

## Исправлено

- Улучшено определение SSID и BSSID на iOS 14–17
- Добавлен резервный способ получения данных через MobileWiFi, если публичные API iOS возвращают пустые значения
- Добавлено необходимое Wi-Fi-разрешение для rootless-среды
- Исправлено отсутствие iFetch в списке модулей Пункта управления
- Добавлены недостающие метаданные модуля CCSupport
- CCSupport теперь устанавливается как обязательная зависимость

## Совместимость

- iOS 14–17
- Только rootless-джейлбрейки
- `iphoneos-arm64`

После установки обновления выполните **Userspace Reboot**. При открытии раздела «Сетевые детали» разрешите доступ к геолокации, чтобы iFetch мог использовать стандартные Wi-Fi API системы.
