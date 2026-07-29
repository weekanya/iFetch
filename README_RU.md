<div align="center">
  <img src="repo/ifetch-banner.png" alt="iFetch" width="100%">
</div>

<div align="center">
  <a href="README.md">English</a> · <strong>Русский</strong>
</div>

# iFetch

[![Сборка пакетов](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml/badge.svg)](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml)

iFetch — приложение для диагностики iPhone с джейлбрейком на iOS 14–17.
Поддерживаются обычные rootless-окружения и RootHide. В комплект входят
приложение на Swift и UIKit, виджеты домашнего экрана, модуль Control Center и
команда `ifetch` для NewTerm и SSH.

<div align="center">
  <img src="assets/ru1.png" alt="Главный экран iFetch" width="48%">
  <img src="assets/ru2.png" alt="Диагностика iFetch" width="48%">
</div>

## Возможности

- мониторинг CPU, ОЗУ, хранилища, батареи, температуры и сети;
- интерфейс на Swift с визуальным стилем, вдохновлённым iOS 18;
- диспетчер процессов с информацией о твиках и завершением процесса;
- сокеты процессов, Wi-Fi, DNS, VPN, скорость сети и задержка;
- анализ сбоев, карта инъекций, LaunchDaemons и проверка jailbreak;
- снимки системы, уведомления и обратимый режим диагностики;
- тёмные виджеты WidgetKit малого, среднего и большого размера с автообновлением;
- живая панель CCSupport 3×2 для Control Center;
- ручной сброс кэша виджетов и безопасные привилегированные операции;
- английский и русский интерфейс.

## Установка

Добавьте репозиторий в Sileo и установите **iFetch**:

```text
https://weekanya.github.io/iFetch/
```

Sileo выбирает `iphoneos-arm64` для обычного rootless-джейлбрейка или
`iphoneos-arm64e` для RootHide. Минимальная версия системы — iOS 14.0.

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

Для обычной rootless-сборки нужны Theos, Swift 5.8 и iOS SDK 16.5 или новее:

```sh
make -C src clean package FINALPACKAGE=1
```

Для RootHide нужен официальный форк Theos от RootHide:

```sh
THEOS=/path/to/roothide/theos make -C src clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

Или запустите
[Сборку пакетов](https://github.com/weekanya/iFetch/actions/workflows/build-artifact.yml),
чтобы собрать оба пакета на GitHub.

## Приватность

Системные данные собираются локально. Запрос к `api.ipify.org` используется
только для определения публичного IP.

## Лицензия

MIT. Подробнее — в [LICENSE](LICENSE).
