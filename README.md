# Cortex Control sous Linux

Fait tourner **Cortex Control** (Neural DSP, Windows uniquement) sous Wine et le relie au
**Quad Cortex mini** en USB : détection de l'appareil, édition des presets, interface complète.

Testé sur CachyOS (KDE Plasma, Wayland) avec Wine 11.20, DXVK 3.1.1 et Cortex Control 4.1.0.

> Projet indépendant, sans lien avec Neural DSP. Cortex Control n'est pas fourni : télécharge
> l'installeur Windows sur le site de Neural DSP.

## Comment ça marche

Le Quad Cortex mini (USB `152a:892f`) expose trois interfaces : l'audio (UAC2), le MIDI et un
canal HID propriétaire (rapport n° 1 en entrée, n° 2 en sortie, 128 octets chacun). Linux gère
nativement l'audio et le MIDI. Cortex Control pilote l'appareil par le canal HID, que Wine relaie à
l'application Windows par son backend `hidraw`. Le pilote USB Windows de Neural DSP (Thesycon)
n'est pas nécessaire.

Deux obstacles, deux corrections :

- **Accès USB** : par défaut, `/dev/hidrawN` n'est accessible qu'à root. La règle udev
  `udev/70-quad-cortex.rules` en donne l'accès à l'utilisateur connecté (tag `uaccess`), et à
  personne d'autre.
- **Fenêtre noire** : Cortex Control est une application JUCE 8 qui dessine en Direct2D. Avec le
  Direct3D 11 de Wine, la fenêtre reste noire. Avec [DXVK](https://github.com/doitsujin/dxvk),
  installé dans le préfixe, l'interface s'affiche normalement. Désactiver le `d2d1` de Wine ne
  marche pas : l'application ne démarre plus.

## Prérequis

- Une version récente de Wine (testé avec 11.20) et winetricks
- Un pilote graphique compatible Vulkan (pour DXVK)
- Facultatif : `7z` et ImageMagick (`magick`), pour récupérer l'icône de l'application

| Distribution    | Commande                                              |
|-----------------|-------------------------------------------------------|
| Arch, CachyOS   | `sudo pacman -S wine winetricks 7zip imagemagick`     |
| Fedora          | `sudo dnf install wine winetricks p7zip-plugins ImageMagick` |
| Debian, Ubuntu  | `sudo apt install wine winetricks 7zip imagemagick`   |

Sur CachyOS, `wine-cachyos` convient aussi. Sur Debian et Ubuntu, une version récente de Wine
s'obtient via le [dépôt WineHQ](https://gitlab.winehq.org/wine/wine/-/wikis/Download).

## Installation

```sh
git clone https://github.com/T13nou/cortex-control-linux.git
cd cortex-control-linux
```

1. Règle udev (seule étape qui demande les droits root) :

   ```sh
   sudo install -m 644 udev/70-quad-cortex.rules /etc/udev/rules.d/
   sudo udevadm control --reload
   sudo udevadm trigger --subsystem-match=hidraw --subsystem-match=usb
   ```

   Débranche et rebranche ensuite le Quad Cortex mini.

2. Installation de Cortex Control dans un préfixe Wine dédié
   (`~/.local/share/wineprefixes/cortex-control`, modifiable par la variable `CORTEX_PREFIX`) :

   ```sh
   ./cortex-control install ~/Téléchargements/"Cortex Control v4.1.0.exe"
   ```

   Le script crée le préfixe (Windows 10), installe DXVK, lance l'installeur et ajoute une entrée
   « Cortex Control » au menu des applications, avec l'icône d'origine. Si l'installeur propose le
   pilote USB Neural DSP / Thesycon, ignore-le.

3. Vérification :

   ```sh
   ./cortex-control doctor
   ```

4. Lancement depuis le menu, ou avec `./cortex-control run`.

## Commandes

| Commande                        | Rôle                                                      |
|---------------------------------|-----------------------------------------------------------|
| `cortex-control doctor`         | Vérifie Wine, l'accès USB, l'audio, le préfixe et DXVK    |
| `cortex-control install <exe>`  | Crée le préfixe, installe DXVK puis Cortex Control        |
| `cortex-control run`            | Lance Cortex Control                                      |
| `cortex-control stop`           | Ferme de force tous les processus Wine du préfixe        |
| `cortex-control dxvk`           | Ajoute DXVK à un préfixe existant (fenêtre noire)         |
| `cortex-control desktop`        | Recrée l'entrée de menu et son icône                      |
| `cortex-control uninstall`      | Supprime le préfixe, l'entrée de menu et l'icône          |

Le journal Wine est écrit dans `~/.local/state/cortex-control.log`.

## Dépannage

- **L'appareil n'est pas détecté** : `cortex-control doctor` doit indiquer « Canal HID accessible ».
  Ferme toute autre application qui utilise le Quad Cortex en MIDI. Pour voir ce que fait Wine :
  `WINEDEBUG=+hid,+hidraw cortex-control run`, puis cherche `152a` dans le journal.
- **Fenêtre noire** : `cortex-control dxvk`, puis relance.
- **Sous fish** : `~` n'est pas développé après un `=` (`env WINEPREFIX=~/…` échoue) ; utilise `$HOME`.
- **Dernier recours** : une machine virtuelle Windows (virt-manager) avec le Quad Cortex passé en USB.

## Limites connues

- Seul le **Quad Cortex mini** (`152a:892f`) est couvert. Le Quad Cortex grand format devrait
  fonctionner de la même manière, mais son identifiant USB n'est pas encore dans la règle udev :
  `lsusb | grep -i cortex` donne l'identifiant à y ajouter, et une contribution est bienvenue.
- Pas encore vérifié : la mise à jour du firmware sous Wine. Par prudence, fais-la depuis Windows
  ou macOS : une coupure USB pendant l'écriture peut laisser l'appareil dans un état délicat.
- Pas encore vérifiés non plus : la connexion au compte Neural DSP et la synchronisation avec
  Cortex Cloud.

## Désinstallation

```sh
./cortex-control uninstall
sudo rm /etc/udev/rules.d/70-quad-cortex.rules
sudo udevadm control --reload
```
