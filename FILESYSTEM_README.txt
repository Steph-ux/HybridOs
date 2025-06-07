=== HybridOS File System Edition ===

NOUVELLES COMMANDES:
-------------------
ls [path]        - Liste le contenu d'un répertoire
cd <path>        - Change de répertoire
pwd              - Affiche le répertoire courant
mkdir <nom>      - Crée un répertoire
touch <nom>      - Crée un fichier vide
cat <fichier>    - Affiche le contenu d'un fichier
echo text        - Affiche du texte
echo text > file - Écrit du texte dans un fichier
rm <fichier>     - Supprime un fichier ou répertoire vide
tree             - Affiche l'arborescence
clear            - Efface l'écran
help             - Affiche l'aide

STRUCTURE DES FICHIERS:
----------------------
/
├── home/        (Répertoires utilisateurs)
│   └── user/
│       └── readme.txt
├── bin/         (Exécutables)
├── etc/         (Configuration)
│   ├── motd     (Message du jour)
│   └── version  (Version du système)
├── tmp/         (Fichiers temporaires)
└── var/         (Données variables)

EXEMPLES:
---------
cd /home/user
echo "Hello World" > hello.txt
cat hello.txt
mkdir projects
cd projects
touch main.c
ls
cd ..
tree

NOTES:
------
- Les fichiers sont stockés en RAM
- Limite: 128 fichiers, 4KB par fichier
- Redémarrage = perte des données
