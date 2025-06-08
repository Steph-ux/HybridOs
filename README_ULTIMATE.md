# HybridOS Ultimate v2.0

## 🎯 Fonctionnalités Complètes

### 📁 Système de Fichiers
- `ls` - Lister les fichiers/dossiers  
- `cd <dir>` - Changer de répertoire
- `pwd` - Afficher le répertoire courant
- `mkdir <nom>` - Créer un dossier
- `touch <nom>` - Créer un fichier vide
- `cat <fichier>` - Afficher le contenu
- `cp <src> <dest>` - Copier un fichier
- `mv <old> <new>` - Renommer/déplacer
- `rm <fichier>` - Supprimer
- `find <pattern>` - Chercher des fichiers
- `grep <text> <file>` - Chercher dans un fichier

### ✍️ Éditeur de Texte Intégré
- `edit <fichier>` - Ouvrir l'éditeur
- **Ctrl+S** - Sauvegarder
- **Ctrl+X** - Quitter
- Support de l'édition complète

### 🎮 Jeux Intégrés
- `snake` - Jeu du serpent (WASD pour bouger)
- `pong` - Jeu de pong (WS pour la raquette)
- `graphics` - Mode graphique VGA

### 🔧 Gestion des Processus
- `ps` - Lister les processus
- `kill <pid>` - Terminer un processus

### 🌐 Réseau
- `ping <host>` - Ping une adresse
- `http` - Serveur HTTP simple

### 💻 Développement
- `compile <file.c>` - Compiler du C
- `basic <code>` - Interpréteur BASIC
- `run <program>` - Exécuter un programme

### ⌨️ Interface Avancée
- **Flèches haut/bas** - Historique des commandes
- **Tab** - Autocomplétion des commandes
- **Couleurs** - Interface colorée
- **Prompt intelligent** - Affiche le répertoire courant

## 🚀 Démarrage Rapide

```bash
# Compilation
make

# Lancement
make run

# Exemple d'utilisation
cd home/user
cat readme.txt
edit hello.c
snake
```

## 📂 Structure par Défaut
```
/
├── home/
│   └── user/
│       └── readme.txt (documentation complète)
├── bin/     (exécutables)
├── etc/     (configuration)
├── tmp/     (temporaire)
└── games/   (jeux)
```

## 🎯 Démonstrations Recommandées

1. **FileSystem**: `ls`, `cd home/user`, `cat readme.txt`
2. **Editor**: `edit test.c`, écrire du code, Ctrl+S, Ctrl+X
3. **Games**: `snake` (WASD + Q pour quitter)
4. **Graphics**: `graphics` (mode VGA)
5. **Network**: `ping google.com`, `http`
