# ewolf-static-template

Template de **site statique eWolf** — sans build, prêt à déployer. Clone-le (ou « Use this template » sur GitHub) pour démarrer un nouveau site en quelques minutes.

Inclus :
- **Page d'accueil par défaut** (`public/index.html`) avec le logo eWolf et les prochaines étapes.
- **SEO + découvrabilité LLM** via [`@ewolf/seo-kit`](https://github.com/ewolf-studio/ewolf-seo-kit) : `llms.txt`, `robots.txt`, `sitemap.xml` et balises `<head>` générés depuis `seo.config.json`.
- **Déploiement SSH durci** (`deploy.sh`) : `tar` over `ssh`, mirror, chargement strict du `.env` (anti-injection). Aucune dépendance à `rsync`.

## Démarrage

```bash
npm install            # installe `serve` (dev local)
npm run dev            # http://localhost:3000

# édite public/index.html, public/styles/main.css, seo.config.json …

npm run seo            # génère llms.txt/robots/sitemap + injecte les balises SEO
```

## Déploiement

```bash
cp .env.example .env   # renseigne SSH_HOST / SSH_USER / SSH_PORT / SSH_PATH
npm run deploy:dry     # aperçu (rien n'est envoyé)
npm run deploy         # lance `npm run seo` (predeploy) puis publie public/
```

`predeploy` régénère automatiquement le SEO avant chaque déploiement, donc `llms.txt`/balises restent synchronisés avec `seo.config.json`.

## Structure

```
.
├─ public/                 # le site (seul contenu déployé)
│  ├─ index.html           # page — pas de <title> en dur (seo-kit le gère)
│  ├─ assets/              # images, logo…
│  ├─ styles/main.css
│  └─ (llms.txt · robots.txt · sitemap.xml   ← générés par `npm run seo`)
├─ seo.config.json         # source de vérité SEO / llms
├─ deploy.sh · .env.example
├─ package.json · .gitignore · readme.md
```

## Notes

- **Sans build** : modules ES et CSS servis tels quels. Pas de bundler.
- Le `<head>` ne doit pas contenir de `<title>`/`<meta description>` en dur — `npm run seo` les injecte entre marqueurs (idempotent).
- `npm run seo:check` échoue si les artefacts ne sont pas à jour (utile en CI / pre-commit).
