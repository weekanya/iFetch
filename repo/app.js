const repositoryURL = "https://weekanya.github.io/iFetch/";

const translations = {
  en: {
    navPackages: "Packages",
    navAbout: "About",
    heroEyebrow: "Rootless repository · iOS 14–17",
    heroTitle: "System tools made for jailbroken iPhones.",
    heroDescription: "A focused repository for native diagnostics, monitoring and utilities. Built for Sileo and modern rootless jailbreaks.",
    addSileo: "Add to Sileo",
    copySource: "Copy source",
    copied: "Source copied",
    featuredPackage: "Featured package",
    showcaseText: "Live diagnostics, widgets, process control, crash reports and a full terminal client.",
    liveMonitoring: "Live monitoring",
    statPackages: "Packages",
    statCompatibility: "Compatibility",
    statEnvironment: "Environment",
    statArchitecture: "Architecture",
    packagesKicker: "Repository catalog",
    packagesTitle: "Packages",
    packagesDescription: "Select a package to see its version, requirements and complete description.",
    searchPlaceholder: "Search packages",
    emptyTitle: "Nothing found",
    emptyText: "Try a different package name or identifier.",
    aboutTitle: "Your iPhone, explained.",
    aboutText: "iFetch combines native system information with live charts, process inspection, jailbreak health checks, network details, WidgetKit widgets and an SSH-friendly CLI.",
    featureWidgets: "Native widgets",
    featureProcesses: "Process manager",
    featureCrashes: "Crash reports",
    featureNetwork: "Network monitor",
    featureControlCenter: "Control Center",
    featureCLI: "Terminal CLI",
    installKicker: "Ready to install",
    installTitle: "Add the source once. Updates appear automatically.",
    openSileo: "Open in Sileo",
    footerText: "Rootless iOS Repository",
    details: "View details",
    downloadDeb: "Download .deb",
    viewDepiction: "View depiction",
    version: "Version",
    architecture: "Architecture",
    compatibility: "Compatibility",
    dependencies: "Dependencies",
    maintainer: "Maintainer",
    section: "Section",
    packageLoadError: "Live package index is temporarily unavailable. Showing cached package information."
  },
  ru: {
    navPackages: "Пакеты",
    navAbout: "О проекте",
    heroEyebrow: "Rootless-репозиторий · iOS 14–17",
    heroTitle: "Системные инструменты для iPhone с джейлбрейком.",
    heroDescription: "Репозиторий нативной диагностики, мониторинга и утилит. Создан для Sileo и современных rootless-джейлбрейков.",
    addSileo: "Добавить в Sileo",
    copySource: "Скопировать репозиторий",
    copied: "Адрес репозитория скопирован",
    featuredPackage: "Главный пакет",
    showcaseText: "Живая диагностика, виджеты, процессы, crash-логи и полноценный клиент для терминала.",
    liveMonitoring: "Живой мониторинг",
    statPackages: "Пакеты",
    statCompatibility: "Совместимость",
    statEnvironment: "Окружение",
    statArchitecture: "Архитектура",
    packagesKicker: "Каталог репозитория",
    packagesTitle: "Пакеты",
    packagesDescription: "Выберите пакет, чтобы посмотреть версию, требования и полное описание.",
    searchPlaceholder: "Поиск пакетов",
    emptyTitle: "Ничего не найдено",
    emptyText: "Попробуйте другое название или идентификатор пакета.",
    aboutTitle: "Всё об iPhone в одном месте.",
    aboutText: "iFetch объединяет системную информацию, живые графики, диспетчер процессов, Jailbreak Health, сетевые детали, виджеты WidgetKit и удобный CLI для SSH.",
    featureWidgets: "Нативные виджеты",
    featureProcesses: "Диспетчер процессов",
    featureCrashes: "Crash-логи",
    featureNetwork: "Мониторинг сети",
    featureControlCenter: "Control Center",
    featureCLI: "CLI для терминала",
    installKicker: "Готово к установке",
    installTitle: "Добавьте репозиторий один раз. Обновления появятся автоматически.",
    openSileo: "Открыть в Sileo",
    footerText: "Rootless iOS-репозиторий",
    details: "Подробнее",
    downloadDeb: "Скачать .deb",
    viewDepiction: "Открыть описание",
    version: "Версия",
    architecture: "Архитектура",
    compatibility: "Совместимость",
    dependencies: "Зависимости",
    maintainer: "Автор",
    section: "Раздел",
    packageLoadError: "Индекс пакетов временно недоступен. Показана сохранённая информация."
  }
};

const fallbackPackages = [
  {
    Package: "com.wee1ka.ifetch",
    Name: "iFetch",
    Version: "5.0.1",
    Architecture: "iphoneos-arm64",
    Description: "Advanced system diagnostics, process monitor and CLI fetch for rootless jailbreak devices on iOS 14–17",
    Maintainer: "wee1ka",
    Author: "wee1ka",
    Section: "Tweaks",
    Depends: "firmware (>= 14.0), firmware (<< 18.0), mobilesubstrate, com.opa334.ccsupport",
    Icon: `${repositoryURL}ifetch-icon.png`,
    SileoDepiction: `${repositoryURL}sileodepiction.json`,
    Filename: "debs/com.wee1ka.ifetch_5.0.1_iphoneos-arm64.deb"
  }
];

let currentLanguage = localStorage.getItem("ifetch-repo-language") || (navigator.language.toLowerCase().startsWith("ru") ? "ru" : "en");
let allPackages = fallbackPackages;
let activePackage = null;
let toastTimer = null;

const packageGrid = document.getElementById("package-grid");
const packageSearch = document.getElementById("package-search");
const packageModal = document.getElementById("package-modal");
const toast = document.getElementById("toast");

function t(key) {
  return translations[currentLanguage][key] || translations.en[key] || key;
}

function applyLanguage() {
  document.documentElement.lang = currentLanguage;
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const value = t(element.dataset.i18n);
    if (value) {
      element.textContent = value;
    }
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.placeholder = t(element.dataset.i18nPlaceholder);
  });
  document.querySelectorAll("[data-language]").forEach((button) => {
    button.classList.toggle("active", button.dataset.language === currentLanguage);
  });
  document.querySelectorAll("[data-en-src]").forEach((image) => {
    image.src = currentLanguage === "ru" ? image.dataset.ruSrc : image.dataset.enSrc;
  });
  renderPackages(packageSearch.value);
  if (activePackage) {
    fillModal(activePackage);
  }
}

function parsePackages(contents) {
  return contents
    .trim()
    .split(/\n\s*\n/)
    .map((block) => {
      const record = {};
      let activeKey = null;
      block.split("\n").forEach((line) => {
        if (/^\s/.test(line) && activeKey) {
          record[activeKey] = `${record[activeKey]} ${line.trim()}`.trim();
          return;
        }
        const separator = line.indexOf(":");
        if (separator < 1) {
          return;
        }
        activeKey = line.slice(0, separator).trim();
        record[activeKey] = line.slice(separator + 1).trim();
      });
      return record;
    })
    .filter((record) => record.Package);
}

function versionParts(version) {
  return String(version || "0")
    .replace(/^[^0-9]*/, "")
    .split(/[^0-9]+/)
    .filter(Boolean)
    .map(Number);
}

function compareVersions(left, right) {
  const a = versionParts(left);
  const b = versionParts(right);
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    const difference = (a[index] || 0) - (b[index] || 0);
    if (difference !== 0) {
      return difference;
    }
  }
  return String(left || "").localeCompare(String(right || ""));
}

function latestPackages(packages) {
  const latest = new Map();
  packages.forEach((item) => {
    const existing = latest.get(item.Package);
    if (!existing || compareVersions(item.Version, existing.Version) > 0) {
      latest.set(item.Package, item);
    }
  });
  return [...latest.values()].sort((left, right) => (left.Name || left.Package).localeCompare(right.Name || right.Package));
}

function packageIcon(item) {
  if (item.Icon && /^https?:\/\//i.test(item.Icon)) {
    return item.Icon;
  }
  return item.Package === "com.wee1ka.ifetch" ? "ifetch-icon.png" : "CydiaIcon@2x.png";
}

function absoluteAsset(path) {
  if (!path) {
    return "#";
  }
  if (/^(https?:|sileo:)/i.test(path)) {
    return path;
  }
  return new URL(path.replace(/^\/+/, ""), repositoryURL).href;
}

function cardForPackage(item) {
  const article = document.createElement("article");
  article.className = "package-card";
  article.tabIndex = 0;
  article.setAttribute("role", "button");
  article.setAttribute("aria-label", `${t("details")}: ${item.Name || item.Package}`);

  const icon = document.createElement("img");
  icon.className = "package-icon";
  icon.src = packageIcon(item);
  icon.alt = "";
  icon.loading = "lazy";
  icon.addEventListener("error", () => {
    icon.src = "CydiaIcon@2x.png";
  }, { once: true });

  const main = document.createElement("div");
  main.className = "package-main";

  const titleRow = document.createElement("div");
  titleRow.className = "package-title-row";

  const titleBox = document.createElement("div");
  const title = document.createElement("h3");
  title.textContent = item.Name || item.Package;
  const identifier = document.createElement("div");
  identifier.className = "package-id";
  identifier.textContent = item.Package;
  titleBox.append(title, identifier);

  const version = document.createElement("span");
  version.className = "version-pill";
  version.textContent = item.Version || "—";
  titleRow.append(titleBox, version);
  main.append(titleRow);

  const description = document.createElement("p");
  description.className = "package-description";
  description.textContent = item.Description || "";

  const tags = document.createElement("div");
  tags.className = "package-tags";
  [item.Section || "Utilities", item.Architecture || "iphoneos-arm64", "iOS 14–17"].forEach((value) => {
    const tag = document.createElement("span");
    tag.textContent = value;
    tags.append(tag);
  });

  const open = document.createElement("div");
  open.className = "package-open";
  const openLabel = document.createElement("span");
  openLabel.textContent = t("details");
  open.innerHTML = '<span></span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-5-5 5 5-5 5"/></svg>';
  open.firstElementChild.replaceWith(openLabel);

  article.append(icon, main, description, tags, open);
  article.addEventListener("click", () => openPackage(item));
  article.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      openPackage(item);
    }
  });
  return article;
}

function renderPackages(query = "") {
  const normalized = query.trim().toLowerCase();
  const visible = latestPackages(allPackages).filter((item) => {
    const haystack = `${item.Name || ""} ${item.Package || ""} ${item.Description || ""} ${item.Section || ""}`.toLowerCase();
    return haystack.includes(normalized);
  });
  packageGrid.replaceChildren(...visible.map(cardForPackage));
  document.getElementById("empty-state").hidden = visible.length !== 0;
  document.getElementById("package-count").textContent = String(latestPackages(allPackages).length);
  const iFetch = allPackages.find((item) => item.Package === "com.wee1ka.ifetch");
  if (iFetch?.Version) {
    document.getElementById("hero-version").textContent = iFetch.Version;
  }
}

function metadataRow(label, value) {
  const wrapper = document.createElement("div");
  const term = document.createElement("dt");
  const definition = document.createElement("dd");
  term.textContent = label;
  definition.textContent = value || "—";
  wrapper.append(term, definition);
  return wrapper;
}

function fillModal(item) {
  document.getElementById("modal-icon").src = packageIcon(item);
  document.getElementById("modal-title").textContent = item.Name || item.Package;
  document.getElementById("modal-identifier").textContent = item.Package;
  document.getElementById("modal-version").textContent = item.Version || "—";
  document.getElementById("modal-section").textContent = item.Section || "Utilities";
  document.getElementById("modal-description").textContent = item.Description || "";

  const metadata = document.getElementById("modal-metadata");
  metadata.replaceChildren(
    metadataRow(t("version"), item.Version),
    metadataRow(t("architecture"), item.Architecture),
    metadataRow(t("compatibility"), "iOS 14–17 · Rootless"),
    metadataRow(t("section"), item.Section),
    metadataRow(t("maintainer"), item.Maintainer || item.Author),
    metadataRow(t("dependencies"), item.Depends)
  );

  const download = document.getElementById("modal-download");
  download.href = absoluteAsset(item.Filename);
  download.hidden = !item.Filename;

  const depictionValue = item.SileoDepiction || item.Sileodepiction || item.Depiction;
  const depiction = document.getElementById("modal-depiction");
  depiction.href = absoluteAsset(depictionValue);
  depiction.hidden = !depictionValue;

  document.getElementById("modal-gallery").hidden = item.Package !== "com.wee1ka.ifetch";
}

function openPackage(item, updateHistory = true) {
  activePackage = item;
  fillModal(item);
  packageModal.hidden = false;
  document.body.classList.add("modal-open");
  document.querySelector(".modal-close").focus();
  if (updateHistory) {
    const url = new URL(window.location.href);
    url.searchParams.set("package", item.Package);
    history.pushState({ package: item.Package }, "", url);
  }
}

function closeModal(updateHistory = true) {
  if (packageModal.hidden) {
    return;
  }
  packageModal.hidden = true;
  document.body.classList.remove("modal-open");
  activePackage = null;
  if (updateHistory) {
    const url = new URL(window.location.href);
    url.searchParams.delete("package");
    history.pushState({}, "", url);
  }
}

function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add("visible");
  toastTimer = setTimeout(() => toast.classList.remove("visible"), 2400);
}

async function copySource() {
  try {
    await navigator.clipboard.writeText(repositoryURL);
  } catch {
    const area = document.createElement("textarea");
    area.value = repositoryURL;
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.append(area);
    area.select();
    document.execCommand("copy");
    area.remove();
  }
  showToast(t("copied"));
}

async function loadPackages() {
  try {
    const response = await fetch(`Packages?time=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(String(response.status));
    }
    const parsed = parsePackages(await response.text());
    if (parsed.length > 0) {
      allPackages = parsed;
    }
  } catch {
    allPackages = fallbackPackages;
    showToast(t("packageLoadError"));
  }
  renderPackages(packageSearch.value);
  const identifier = new URL(window.location.href).searchParams.get("package");
  const requested = identifier && allPackages.find((item) => item.Package === identifier);
  if (requested) {
    openPackage(requested, false);
  }
}

document.querySelectorAll("[data-language]").forEach((button) => {
  button.addEventListener("click", () => {
    currentLanguage = button.dataset.language;
    localStorage.setItem("ifetch-repo-language", currentLanguage);
    applyLanguage();
  });
});

document.getElementById("copy-source").addEventListener("click", copySource);
packageSearch.addEventListener("input", () => renderPackages(packageSearch.value));
document.querySelectorAll("[data-close-modal]").forEach((button) => {
  button.addEventListener("click", () => closeModal());
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeModal();
  }
});

window.addEventListener("popstate", () => {
  const identifier = new URL(window.location.href).searchParams.get("package");
  const requested = identifier && allPackages.find((item) => item.Package === identifier);
  if (requested) {
    openPackage(requested, false);
  } else {
    closeModal(false);
  }
});

applyLanguage();
loadPackages();
