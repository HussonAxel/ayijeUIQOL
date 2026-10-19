# ayijeUIQOL — consignes du projet

- Les fonctionnalités QoL doivent être **activées par défaut**, y compris les
  prochains ajouts. Chaque fonctionnalité reste désactivable dans les options.
- Conserver les choix déjà enregistrés : un changement de valeur par défaut ne
  doit pas réactiver une fonctionnalité explicitement désactivée.
- Cette règle concerne l'activation des fonctionnalités, pas tous les réglages
  secondaires. Préserver notamment le choix d'afficher uniquement les apparences
  manquantes par défaut, autres classes incluses.
- Intégrer les options à `/aui` > Extras > Quality of Life avec les composants
  existants d'AyijeUI. Les sections de réglages doivent être repliables et fermées
  par défaut.

- Les trackers personnalisés utilisent `TrackerContent` comme espace privé pour
  les fournisseurs de données. Garder le rendu et les réglages dans les composants
  AyijeUI ; ne pas réintroduire de dépendance à FunelQOL ou à son mode édition.
- Les panneaux sont dans `module.db.customTrackers` (profils AyijeUI). Les mémoires
  hebdomadaires sont dans `ayijeUIQOLCharacterDB` (par personnage), avec expiration.
- Préserver les exclusions Git des catalogues locaux RareData/TeleportData et de
  TrackerSavedPanels ; conserver leurs attributions dans THIRD_PARTY.md.

- `TrackerInteractions.lua` gère les clics directs et le graphe d’ancres des
  trackers : refuser les cycles, convertir les écarts selon l’échelle et libérer
  les suiveurs sans saut lors d’une suppression. Garder les menus et déplacements
  liés à l’identité du panneau et du profil ; aucun ancien menu ne doit modifier
  un panneau réutilisé ou un autre profil. Préserver les déplacements AyijeUI.

- Les ancres externes des trackers utilisent des clés stables et des résolveurs
  de frames (`RegisterAnchorTarget`). Les barres QoL exposent leur host via
  `ProgressBars:GetAnchorFrame`. Découvrir seulement les movers AyijeUI ; utiliser les repères sûrs de GlobalAnchors pour
  les frames protégées, exclure les frames interdites et conserver les liens aux cibles non encore
  créées et ne pas utiliser les cibles masquées pour l’accroche automatique.

- `fitAnchorWidth` est actif par défaut : les trackers visibles au-dessus/en dessous
  d’une même cible externe partagent sa largeur, y compris leurs chaînes gauche /
  droite. Calculer les tailles en unités écran, soustraire les espacements puis
  convertir selon l’échelle de chaque panneau. Ne jamais écraser `cfg.width` :
  c’est la largeur manuelle restaurée au détachement. Le rendu des lignes doit
  utiliser la largeur effective, avec rafraîchissement après redimensionnement.

- `GlobalAnchors.lua` est le graphe commun des movers AyijeUI : stockage par profil
  dans `globalAnchors.links`, identifiants stables, cycles contrôlés avec le graphe
  des trackers. Le pont dans `AyijeUI_Options/Mover/Handles.lua` encadre les débuts /
  validations de déplacements ; ne pas contourner les movers natifs.
- Ne lire / écrire la géométrie des sources sécurisées qu’hors combat. Les trackers
  ciblent des proxies indépendants, jamais une action bar sécurisée directement.
  Conserver l’identité du profil au commit, restaurer positions / clamping quand
  le QoL est désactivé et conserver les systèmes natifs de layout.
