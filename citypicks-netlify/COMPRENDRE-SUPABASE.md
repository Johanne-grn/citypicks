# Comprendre Supabase (et pourquoi on en a besoin)

## Le problème de départ

Un site Netlify, c'est juste des fichiers (HTML, photos) envoyés au navigateur de chaque visiteur. Netlify ne **retient** rien :
- si Sacha enregistre un favori, il reste dans **son** navigateur, et Timothée ne le verra jamais ;
- impossible de savoir **qui** est connecté ;
- impossible de garder les propositions de spots pour les modérer.

Il nous faut donc un endroit sur Internet qui **stocke les données** et **reconnaît les utilisateurs**. C'est Supabase.

## Supabase en une phrase

Supabase est un service gratuit qui nous fournit **une base de données en ligne + un système de comptes (inscription, connexion)**, sans écrire de serveur.

## La métaphore du cours : l'app est un restaurant

| Partie de l'app | Métaphore | Chez CityPick's |
|---|---|---|
| Interface | La salle | `index.html` sur Netlify |
| Base de données | Le garde-manger | **Supabase** : tables `spots`, `favorites`, `proposals`, `profiles` |
| Authentification | Le vestiaire | **Supabase Auth** : e-mail + mot de passe |
| API (fournisseurs) | Les fournisseurs | Gemini (l'IA), Google Maps |

## Comment ça marche, concrètement

```
 Visiteur (navigateur)                         Supabase
 ─────────────────────                         ────────
 1. Ouvre le site Netlify
 2. Le site demande : « donne-moi les spots » ─────► table spots
                                         ◄───── 90 spots
 3. Il s'inscrit (e-mail + mot de passe) ──────────► Auth crée le compte
                                                     + crée son profil (pseudo)
 4. Il clique ♡ sur le Colisée ─────────────────────► table favorites :
                                                     (son id, s58)
 5. Un autre utilisateur demande ses favoris ───────► Supabase vérifie QUI demande
                                         ◄───── seulement SES favoris
```

## Les 4 tables (comme des feuilles Excel)

| Table | Une ligne = | Exemple |
|---|---|---|
| `spots` | une adresse | s58, Rome, Colisée, Culture, €€ |
| `profiles` | un utilisateur | Johanne, ville préférée : Paris |
| `favorites` | « tel utilisateur aime tel spot » | Johanne ♡ s58 |
| `proposals` | une proposition de spot | « Bar X à Berlin », en attente |
| `admins` | un membre de l'équipe | l'id de Johanne |

Vous pouvez les voir dans Supabase → **Table Editor**, comme un tableur.

## La sécurité : les règles « RLS »

Le site utilise une clé **publique** (la clé *anon*). N'importe qui peut la lire dans le code. Ce n'est pas grave, car Supabase applique des **règles** sur chaque table (Row Level Security, « sécurité ligne par ligne ») :

| Table | Règle écrite dans `1_schema.sql` |
|---|---|
| `spots` | Tout le monde lit. Seuls les admins ajoutent ou modifient. |
| `favorites` | Chacun ne voit, n'ajoute et ne supprime **que les siens**. |
| `profiles` | Chacun voit et modifie le sien. Les admins voient les pseudos (pour la modération). |
| `proposals` | L'auteur voit les siennes. Les admins voient tout et décident. |

Même si quelqu'un bidouille le site, c'est **la base** qui refuse. C'est exactement le point « un utilisateur ne voit que ses propres données » de l'atelier 3, et ce que l'audit croisé va vérifier.

À ne jamais faire : mettre la clé **service_role** (ou *secret*) dans le site. Elle ignore toutes les règles.

## Ce que font les 2 fichiers SQL

On ne clique pas pour créer les tables : on colle un script qui les crée d'un coup.

- **`1_schema.sql`** crée les 5 tables, les règles de sécurité, et 2 automatismes :
  - à chaque inscription, le profil (pseudo, ville) est créé tout seul ;
  - la fonction « supprimer mon compte » efface le compte et toutes ses données.
- **`2_spots.sql`** remplit la table `spots` avec les 90 adresses.

On les colle dans **SQL Editor → New query → Run**, dans cet ordre.

## Comment le site trouve VOTRE base

Chaque projet Supabase a une adresse et une clé publique. On les colle dans `config.js` :

```js
SUPABASE_URL: "https://abcdxyz.supabase.co",   // l'adresse de VOTRE base
SUPABASE_ANON_KEY: "eyJhbGciOi..."              // la clé publique
```

Tant que c'est vide, le site tourne en **mode démo** : il marche, mais sans comptes.

## Et l'assistant IA dans tout ça ?

```
 Navigateur ──question──► Fonction Netlify (serveur) ──► Gemini (Google)
                               │    ▲                         │
                               │    └──── réponse + spots ◄───┘
                               └──► Supabase : lit la liste des spots
```

La fonction Netlify est un mini-serveur. Elle seule connaît la clé Gemini (rangée dans les variables Netlify). Elle va chercher les spots dans Supabase pour que l'IA ne recommande que de vraies adresses du catalogue.

## Le récap en 5 gestes

1. Créer un projet sur supabase.com (gratuit, région Europe).
2. SQL Editor : coller et lancer `1_schema.sql` puis `2_spots.sql`.
3. Copier l'URL et la clé *anon* dans `config.js`.
4. Authentication : désactiver « Confirm email » pour l'atelier.
5. Après avoir créé votre compte sur le site : lancer la petite requête « admins » du guide pour avoir la page Modération.

Tout le détail, clic par clic : `GUIDE-PUBLICATION.md`.
