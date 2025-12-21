#!/bin/bash

echo "🔧 Script de correction des migrations Prisma"
echo "============================================="

# Aller dans le dossier backend
cd /Users/dalm1-tt/Desktop/tt-backend

echo "📁 Vérification du dossier backend..."
if [ ! -f "package.json" ]; then
    echo "❌ Erreur: package.json non trouvé. Assurez-vous d'être dans le bon dossier."
    exit 1
fi

echo "🗂️ Sauvegarde du dossier migrations existant..."
if [ -d "prisma/migrations" ]; then
    mv prisma/migrations prisma/migrations_backup_$(date +%Y%m%d_%H%M%S)
    echo "✅ Dossier migrations sauvegardé"
fi

echo "📝 Création du dossier de migration baseline..."
mkdir -p prisma/migrations/0_init

echo "🔄 Génération de la migration baseline..."
npx prisma migrate diff \
  --from-empty \
  --to-schema-datamodel prisma/schema.prisma \
  --script > prisma/migrations/0_init/migration.sql

echo "✅ Migration baseline créée"

echo "🏷️ Marquage de la migration comme appliquée..."
npx prisma migrate resolve --applied 0_init

echo "🎯 Redémarrage des services Docker..."
docker-compose down
docker-compose up -d

echo "✅ Correction terminée!"
echo ""
echo "📋 Prochaines étapes:"
echo "1. Vérifiez que les services démarrent correctement avec: docker-compose logs -f"
echo "2. Testez la connexion/inscription sur le frontend"
