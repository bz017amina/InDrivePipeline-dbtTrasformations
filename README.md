# InDrive --- Pipeline Data Engineering




## Q4 --- Quel est le grain de `fact_rides` ?

Dans `fact_rides`, une ligne représente **une course identifiée par un
`ride_id`**. Même si une course génère plusieurs événements au cours de
son cycle de vie --- demande, contre-offre, acceptation, finalisation ou
annulation --- ces événements sont regroupés pour obtenir une vision
consolidée de la course.

Ce choix permet d'analyser une course sans compter plusieurs fois la
même transaction. On retrouve dans cette ligne les informations utiles à
son suivi : son statut final, les tarifs proposés et acceptés, la
distance ainsi que les différents timestamps disponibles.

## Q5 --- Pourquoi utiliser le SCD Type 1 pour `dim_vehicle` et `dim_zone` ?

Pour les dimensions `dim_vehicle` et `dim_zone`, j'ai retenu le **SCD
Type 1**. Les informations stockées décrivent principalement les
caractéristiques d'un véhicule (marque, modèle, plaque, catégorie) ou
d'une zone (nom du quartier, ville). Dans le cadre de cet exercice,
conserver toutes les anciennes versions de ces attributs n'apporte pas
de valeur particulière aux analyses.

Si une information est corrigée, la nouvelle valeur remplace donc
directement l'ancienne. Cela garde les dimensions simples à maintenir,
sans ajouter une gestion d'historique qui n'est pas nécessaire pour ces
données.

## Q6 --- Pourquoi suivre la note des chauffeurs avec un snapshot SCD Type 2 ?

La note d'un chauffeur peut évoluer après chaque course. Elle représente
donc une information qui varie dans le temps et qui peut être
intéressante à analyser : par exemple, pour comprendre si l'évolution de
la note est liée au comportement des clients, au taux d'acceptation ou
aux négociations tarifaires.

Le snapshot `snap_drivers`, configuré avec `strategy='check'` sur la
colonne `rating`, permet de conserver les différentes versions observées
de cette note. On peut ainsi retrouver la valeur connue à une période
donnée, au lieu de ne garder que la note la plus récente.

Ce suivi historique est plus pertinent ici que pour les véhicules ou les
zones, dont les attributs descriptifs changent beaucoup moins souvent.

## Q7 --- Pourquoi utiliser un `LEFT JOIN` dans `int_ride_events_enriched` ?

J'ai choisi le `LEFT JOIN` pour ne pas perdre une course simplement
parce qu'une information liée au chauffeur ou au véhicule est absente.

Avec un `INNER JOIN`, une course qui référence un chauffeur ou un
véhicule introuvable serait éliminée du résultat. L'anomalie deviendrait
alors plus difficile à repérer, puisqu'elle disparaîtrait avant
d'arriver dans les modèles finaux.

Le `LEFT JOIN`, lui, conserve les événements de course et laisse les
colonnes correspondantes à `NULL` lorsque la correspondance n'existe
pas. Les tests dbt peuvent ensuite signaler le problème, notamment grâce
aux contrôles `not_null` et `relationships`. La donnée reste donc
visible dans le pipeline au lieu d'être écartée silencieusement.

## Q9 & Q10 --- Pourquoi ces matérialisations et quelles règles métier sont appliquées ?

Les matérialisations ont été choisies selon le rôle de chaque couche :

-   **Staging --- `view` :** cette couche prépare et standardise les
    données sources sans en créer une copie physique supplémentaire. Les
    vues restent liées aux données disponibles en amont.
-   **Intermediate --- `ephemeral` :** le modèle
    `int_ride_events_enriched` sert à centraliser une transformation
    intermédiaire. dbt l'intègre sous forme de CTE dans les modèles qui
    en dépendent, sans créer une table ou une vue supplémentaire dans
    PostgreSQL.
-   **Marts --- `table` :** les tables finales sont matérialisées pour
    faciliter les consultations et les agrégations. Elles sont destinées
    aux analyses métier et à leur exploitation par des outils de BI.

Côté métier, deux traitements sont notamment importants :

-   L'écart de négociation est calculé avec
    `agreed_fare_mad - proposed_fare_mad`. Il permet de mesurer la
    différence entre le tarif initialement proposé et celui finalement
    accepté.
-   Dans `fct_driver_daily_revenue`, seules les courses dont
    `final_status = 'completed'` sont prises en compte. Une course
    annulée ne doit pas être comptabilisée comme un revenu réellement
    généré par le chauffeur.

Ces règles permettent de produire des indicateurs cohérents avec
l'activité réelle, plutôt que de simplement agréger toutes les courses
présentes dans les données.

## Q12 --- Que se passe-t-il si un `driver_id` inexistant est inséré ?

Pour vérifier le contrôle d'intégrité référentielle, on peut ajouter
dans `raw_ride_events.csv` un événement qui référence un chauffeur
inexistant, par exemple `driver_id = 999`, puis suivre cette donnée
jusqu'à `fact_rides`.

Grâce au `LEFT JOIN` utilisé dans le modèle intermédiaire, la course
n'est pas supprimée : elle arrive jusqu'au mart avec une référence
chauffeur qui ne correspond à aucune ligne de `snap_drivers`.

Dans ce scénario, c'est le test dbt de relation entre
`fact_rides.driver_id` et `snap_drivers.driver_id` qui doit échouer. Les
autres contrôles --- unicité, valeurs non nulles, valeurs autorisées et
relations sur les zones de départ et d'arrivée --- restent valides si
les autres champs de l'enregistrement sont corrects.

Ce résultat est intéressant : il montre que le pipeline conserve la
ligne problématique et que le contrôle de qualité la détecte à l'endroit
prévu, au lieu de masquer l'anomalie pendant une jointure.

## Q14 --- Le modèle éphémère apparaît-il dans le graphe de lignage dbt ?

Oui. Même si `int_ride_events_enriched` est configuré avec
`materialized='ephemeral'` et ne crée donc pas de table ou de vue
physique dans PostgreSQL, il reste un modèle dbt à part entière.

Ses dépendances sont conservées dans les métadonnées du projet. Il
apparaît ainsi dans le graphe de lignage généré par `dbt docs generate`,
puis consultable avec `dbt docs serve`. On peut suivre son rôle entre
les modèles en amont --- staging et snapshot des chauffeurs --- et le
modèle `fact_rides`.

C'est justement l'intérêt de cette matérialisation : garder une
transformation intermédiaire réutilisable et traçable dans le DAG dbt,
sans multiplier les objets physiques dans la base.

------------------------------------------------------------------------

## Preuve que ça tourne

(images/dbtRun.png)
