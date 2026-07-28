<div align="center">
  <img src="repo/ifetch-banner.png" alt="iFetch" width="100%">
</div>

<div align="center">
  <a href="README.md">English</a> · <strong>Русский</strong>
</div>

# iFetch

[![Сборка rootless-артефакта](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml/badge.svg)](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml)

iFetch — приложение для диагностики iPhone с rootless-джейлбрейком на iOS
14–17. В комплект входят приложение на UIKit, виджеты домашнего экрана, модуль
Control Center и команда `ifetch` для NewTerm и SSH.

<div align="center">
  <img src="assets/ru1.png" alt="Главный экран iFetch" width="48%">
  <img src="assets/ru2.png" alt="Диагностика iFetch" width="48%">
</div>

## Возможности

- мониторинг CPU, ОЗУ, хранилища, батареи, температуры и сети;
- диспетчер процессов с информацией о твиках и завершением процесса;
- данные Wi-Fi, DNS, VPN, публичный IP, скорость сети и задержка;
- jailbreak-окружение, хук-инжектор, установленные твики и crash-логи;
- виджеты WidgetKit малого, среднего и большого размера;
- модуль CCSupport 2×2 для Control Center;
- английский и русский интерфейс.

## Установка

Добавьте репозиторий в Sileo и установите **iFetch**:

```text
https://weekanya.github.io/iFetch/
```

Поддерживается только rootless-джейлбрейк. Архитектура пакета —
`iphoneos-arm64`, минимальная версия системы — iOS 14.0.

## Терминал

Запустите `ifetch` в NewTerm или по SSH. Основные параметры:

```sh
ifetch --watch
ifetch --json
ifetch --processes 10
ifetch --network
ifetch --battery
ifetch --lang ru
```

## Сборка

Для локальной сборки нужны Theos, Swift 5.8 и iOS SDK 16.5 или новее:

```sh
make -C src clean package FINALPACKAGE=1
```

Или запустите
[Build Rootless Artifact](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml),
чтобы сразу собрать проект на GitHub.

## Приватность

Системные данные собираются локально. Запрос к `api.ipify.org` используется
только для определения публичного IP.

## Лицензия

MIT. Подробнее — в [LICENSE](LICENSE).
