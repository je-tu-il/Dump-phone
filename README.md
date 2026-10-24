# 📱 StackLaunch (Dump-phone) — Lanceur Minimaliste & Détox Numérique pour iOS

[![Release](https://img.shields.io/github/v/release/je-tu-il/Dump-phone?color=teal&label=Version)](https://github.com/je-tu-il/Dump-phone/releases/latest)
[![Build iOS](https://github.com/je-tu-il/Dump-phone/actions/workflows/build.yml/badge.svg)](https://github.com/je-tu-il/Dump-phone/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/Plateforme-iPhone%20(iOS%2017%2B)-black.svg)](https://github.com/je-tu-il/Dump-phone/releases/latest)

> **StackLaunch** transforme votre iPhone en un véritable *« Dumb Phone »* textuel et épuré. En supprimant les icônes colorées addictives et les flux de notifications, il vous aide à reprendre le contrôle de votre temps d'écran et de votre attention.

---

## 📲 Téléchargement Direct & Installation

Téléchargez le binaire compilé sur la page [**Releases GitHub**](https://github.com/je-tu-il/Dump-phone/releases/latest) :

1. Téléchargez le fichier **`StackLaunch-unsigned.ipa`**.
2. Installez-le en quelques secondes via :
   - 🍏 **AltStore / SideStore** : Onglet *My Apps* > bouton `+` > sélectionnez `StackLaunch-unsigned.ipa`.
   - 💻 **Sideloadly** : Glissez le fichier `.ipa` et lancez l'installation par câble USB.
   - ⚡ **TrollStore** : Installation directe sans expiration de certificat.

---

## ✨ Fonctionnalités Clés

- 🧘 **Interface Textuelle Pure (Zéro Icône Distrayante)** : Vos applications favorites sont affichées sous forme de texte clair et minimaliste. Fini les pastilles de notification anxiogènes et les logos flashy.
- 📱 **Widgets Écran d'Accueil Dédiés (WidgetKit)** : Intégrez votre lanceur directement sous forme de widget large ou moyen sur votre écran d'accueil iOS.
- 🔍 **Recherche Instantanée & Filtrage** : Tapez une ou deux lettres pour ouvrir directement l'application souhaitée sans vous perdre dans la bibliothèque d'apps.
- 📚 **Base d'Applications Intégrée (`PredefinedAppsDatabase`)** : Prise en charge native des URL Schemes pour lancer Téléphone, Messages, Safari, Notes, Podcasts, Spotify, Transports et bien d'autres en un éclair.
- 🎨 **Personnalisation Épurée** :
  - Mode sombre profond (OLED Black) pour économiser la batterie.
  - Choix des typographies (monospace, serif élégant, sans-serif moderne).
  - Sélection des applications prioritaires (Dock de 4 à 6 essentiels).

---

## 🛠️ Stack Technique

- **Langage** : Swift 5.9+ / SwiftUI
- **Frameworks** : WidgetKit, CoreServices, Combine
- **Partage de données** : App Groups (`group.com.pixelthings.stacklaunch`)
- **Cible** : iOS 17.0+
- **CI/CD** : GitHub Actions (compilation Release IPA sous macOS)

---

## 📄 Licence

Ce projet est sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.
