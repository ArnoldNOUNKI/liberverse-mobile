# Liberverse — application mobile (Flutter)

Application Android (et iOS) native de Liberverse, écrite en Flutter.
Elle utilise **la même API, les mêmes comptes et les mêmes données** que le site https://liberverse.fr (dépôt `velours`).

## Fonctionnalités

| Écran | Contenu |
|---|---|
| Écran 18+ et accueil | Fond nuit animé (orbites), code d'invitation, connexion, choix de la langue |
| Connexion / inscription | Fenêtres claires. Inscription en 3 étapes : type de profil, ville par listes ou position GPS, consentements |
| Activation | Confirmation de l'e-mail, photos, selfie de vérification avec code, choix de l'adhésion |
| Rencontres | Cartes à glisser (droite = j'aime, gauche = passer, haut = super-like) avec tampons, ou grille avec ✕ ♥ ★ ; filtres complets (curseur de distance) ; écran « C'est un match » |
| Likes | « Ils vous ont liké » (Premium / Prestige), aperçu flouté sinon |
| Messages | Nouveaux matchs en carrousel, conversations, chat avec accusés de lecture, photos jointes, menu (profil, signaler, retirer le match) |
| Salons | Invitations, mes salons, découverte ; discussion de groupe, soirées avec inscription, membres et demandes (accepter / refuser sous le nom), réglages |
| Profil | Photos de profil et album privé, présentation, envies, ville |
| Parrainage | 5 invitations, codes copiables, filleuls |
| Adhésion | Offres en euros avec équivalent dans la monnaie locale, paiement (démo ou Stripe) |
| Paramètres | Confidentialité, position, notifications, langue, monnaie, thème clair / sombre / système, verrouillage par empreinte ou Face ID, e-mail, mot de passe, suppression du compte |

Le style suit le site :
- couleurs bordeaux, noir, blanc et or ;
- logo L + masque ;
- icônes d'onglets aux tracés identiques ;
- thème clair par défaut.

## Langues

Les textes sont écrits en français dans le code et passent par `tr('…')`. Les traductions sont téléchargées depuis le site (`/i18n/<langue>.json`, 9 langues) et gardées sur l'appareil.

Corriger une traduction côté site (dépôt `velours`, dossier `i18n/`) corrige aussi l'app, sans republier.

Pour un nouveau texte de l'app :
1. l'ajouter dans `velours/i18n/app.json` ;
2. ajouter sa traduction dans `velours/i18n/<langue>.txt` ;
3. lancer `npm run i18n` dans `velours`.

## Démarrer

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) 3.50 ou plus récent (Dart 3.14), Android Studio ou le SDK Android, Java 17 ou plus récent.

```bash
flutter pub get
flutter run                                            # sur un téléphone branché ou un émulateur
flutter run --dart-define=LIBERVERSE_URL=http://10.0.2.2:3000   # serveur local depuis l'émulateur Android
flutter build apk --release                            # APK : build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release                      # AAB pour le Play Store
```

Par défaut, l'app se connecte à `https://liberverse.fr`. Pour changer de serveur : `--dart-define=LIBERVERSE_URL=...`.

## Publier sur le Play Store

1. Créer la clé de signature, une seule fois, et la conserver précieusement :
   ```bash
   keytool -genkey -v -keystore ~/liberverse-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias liberverse
   ```
2. Créer `android/key.properties` (ce fichier n'est jamais commité) :
   ```
   storePassword=...
   keyPassword=...
   keyAlias=liberverse
   storeFile=/chemin/vers/liberverse-release.jks
   ```
3. Lancer `flutter build appbundle --release`, puis téléverser `build/app/outputs/bundle/release/app-release.aab` dans la Google Play Console.
4. Remplir la fiche :
   - classification du contenu : app de rencontre, **18+** ;
   - politique de confidentialité : https://liberverse.fr/cgu.html ;
   - suppression de compte : disponible dans l'app (Paramètres → Supprimer mon compte).

Identifiant de l'app : `fr.liberverse.app`. Version : `version:` dans `pubspec.yaml`. Augmenter le nombre après `+` à chaque envoi.

## iOS (plus tard)

Le projet `ios/` est prêt :
- identifiant `fr.liberverse.app` ;
- textes d'autorisation pour la position, l'appareil photo, les photos et Face ID ;
- affichage en portrait.

Il faut un Mac avec Xcode. Lancer `flutter build ipa`, puis envoyer sur App Store Connect.

## Structure

```
lib/
  main.dart                 démarrage, thème, aiguillage (18+ / accueil / activation / app)
  core/api.dart             client HTTP (cookie de session conservé sur l'appareil), envoi de photos
  core/i18n.dart            traductions partagées avec le site
  core/state.dart           membre connecté, compteurs, thème, langue, monnaie
  core/theme.dart           charte Liberverse (clair / sombre)
  core/lock.dart            verrouillage empreinte / Face ID
  widgets/                  logo, icônes, images protégées, sélecteur de lieu, photos
  screens/                  écrans (accueil, inscription, rencontres, likes, messages, salons, profil…)
assets/icon.svg             logo
tool/make_icons.js          régénère les icônes Android / iOS depuis le logo (Node + sharp)
```

## Mises à jour

- **Données, traductions, offres, règles côté serveur :** prises en compte immédiatement après un redéploiement du site sur Coolify.
- **Écrans et fonctions de l'app :** nouvelle version à publier sur le store.
