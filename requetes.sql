-- REQUETES IMPOSEES

-- 1 - Taux d'occupation (pourcentage de jours occupé) d'un studio en 2014
PREPARE   q1 AS
SELECT    id_studio,
          ROUND(100.0 * SUM(
            CASE
              WHEN  date_fin > date '12/31/2014' THEN date '12/31/2014' ELSE date_fin
            END
            -
            CASE
              WHEN date_debut < date '01/01/2014' THEN date '01/01/2014' ELSE date_debut
            END
          ) / (date '12/31/2014' - date '01/01/2014'), 2) AS taux_occupation
FROM      reservation
WHERE     (EXTRACT(year FROM date_debut) = 2014
  OR      EXTRACT(year FROM date_fin) = 2014)
  AND     id_studio IS NOT NULL
GROUP BY  id_studio
ORDER BY id_studio;

-- 2 - Recette du mois en cours, par type de modèle de materiel, en ordre croissant de recettes
PREPARE   q2 AS
SELECT    modele,
          SUM(prix)
FROM      materiel
WHERE     id_materiel IN (
            SELECT  id_materiel
            FROM    materiel_reserve
            WHERE   id_reservation IN (
                        SELECT    id_reservation
                        FROM      reservation
                        WHERE     EXTRACT(year FROM date_debut) = EXTRACT(year FROM NOW())
                          AND     EXTRACT(month FROM date_debut) = EXTRACT(month FROM NOW())
                          OR      EXTRACT(year FROM date_fin) = EXTRACT(year FROM NOW())
                          AND     EXTRACT(month FROM date_fin) = EXTRACT(month FROM NOW())
                    )
          )
GROUP BY  modele
ORDER BY  SUM(prix);


-- 3 - Liste des modeles de materiel n'ayant fait l'objet d'aucune réservation le mois dernier
PREPARE   q3 AS
SELECT    modele
FROM      materiel
WHERE     modele NOT IN(
            SELECT    modele
            FROM      materiel
            WHERE     id_materiel IN(
                        SELECT    id_materiel
                        FROM      materiel_reserve
                        WHERE     id_reservation IN(
                                    SELECT    id_reservation
                                    FROM      reservation
                                    WHERE     EXTRACT(year FROM date_debut) = EXTRACT(year FROM NOW())
                                      AND     EXTRACT(month FROM date_debut) = EXTRACT(month FROM NOW())-1
                                      OR      EXTRACT(year FROM date_fin) = EXTRACT(year FROM NOW())
                                      AND     EXTRACT(month FROM date_fin) = EXTRACT(month FROM NOW())-1
                        )
                      )
          )
GROUP BY  modele;

-- 5 - En moyenne, combien de jours à l'avance les clients font-il une réservation ?
PREPARE q5 AS
SELECT  AVG(date_debut - date_commande)
FROM    reservation;


-- 6 - Pour chaque mois de 2014, identifiez le client ayant le plus dépensé sur le site
PREPARE q6 AS
SELECT    mois,
          id_client
FROM      (
          SELECT    mois,
                    MAX(depense) as max_d
          FROM (
            SELECT    EXTRACT(month FROM date_commande) AS mois,
                      id_client,
                      SUM(sum_prix) AS depense
            FROM      reservation NATURAL JOIN (
                        SELECT    id_reservation,
                                  SUM(prix) AS sum_prix
                        FROM      materiel_reserve NATURAL JOIN (
                                    SELECT    id_materiel,
                                              prix
                                    FROM      materiel
                                  ) AS materiel_prix
                        GROUP BY  id_reservation
                      ) AS materiel_reserve_prix
            WHERE     EXTRACT(year FROM date_commande) = 2014
            GROUP BY  mois, id_client
          ) AS prix_client_mois
          GROUP BY  mois
        ) AS t1 NATURAL JOIN (
          SELECT    EXTRACT(month FROM date_commande) AS mois,
                    id_client,
                    SUM(sum_prix) AS max_d
          FROM      reservation NATURAL JOIN (
                      SELECT    id_reservation,
                                SUM(prix) AS sum_prix
                      FROM      materiel_reserve NATURAL JOIN (
                                  SELECT    id_materiel,
                                            prix
                                  FROM      materiel
                                ) AS materiel_prix
                      GROUP BY  id_reservation
                    ) AS materiel_reserve_prix
          WHERE     EXTRACT(year FROM date_commande) = 2014
          GROUP BY  mois, id_client
        ) AS t2
ORDER BY  mois;


-- 7 - Pour chaque trimestre 2014, calcul du pourcentage (sur le chiffre
-- d'affaire total) représenté par les recettes générées par les cameras
PREPARE q7 AS
SELECT  trimestre,
        100.0 * (somme_prix_camera::double precision / somme_prix_materiel::double precision) AS pourcentage
FROM (
    SELECT    EXTRACT(quarter FROM date_commande) AS trimestre,
              SUM(prix) AS somme_prix_materiel
    FROM      (reservation JOIN materiel_reserve USING (id_reservation)) JOIN materiel USING (id_materiel)
    WHERE     EXTRACT(year FROM date_commande) = 2014
    GROUP BY  EXTRACT(quarter FROM date_commande)
  ) AS t1
  NATURAL JOIN (
    SELECT    EXTRACT(quarter FROM date_commande) AS trimestre,
              SUM(prix) AS somme_prix_camera
    FROM      (reservation JOIN materiel_reserve USING (id_reservation)) JOIN camera USING (id_materiel)
    WHERE     EXTRACT(year FROM date_commande) = 2014
    GROUP BY  EXTRACT(quarter FROM date_commande)
  ) AS t2;


-- 8 - Clients qui ont commandé au moins une fois par semaine ces 6 derniers mois
PREPARE    q8 AS
SELECT    id_client
FROM      reservation
WHERE     id_client IN(
            SELECT    id_client
            FROM      reservation
            WHERE     date_commande >= NOW() - interval '1 month'
            GROUP BY  id_client, EXTRACT(week FROM date_commande)
            HAVING    COUNT(EXTRACT(week FROM date_commande)) > 1*4
          );


-- 10 - Les clients qui viennent toujours les mêmes jours qu'un autre
PREPARE   q10 AS
SELECT    id_client,
          id_client_2
FROM      (
            (
              SELECT    id_client,
                        COUNT(DISTINCT date_commande) AS count_date_1
              FROM      reservation
              GROUP BY  id_client
            ) AS a1 JOIN (
              SELECT    t1.id_client AS id_client,
                        t2.id_client AS id_client_2,
                        COUNT(t2.id_client) AS count_couple
              FROM      reservation AS t1,
                        reservation AS t2
              WHERE     t1.date_commande = t2.date_commande
                AND     t1.id_client != t2.id_client
              GROUP BY  t1.id_client, t2.id_client
            ) AS a2 USING (id_client)
          ) AS a3 JOIN (
            SELECT    id_client AS id_client_2,
                      COUNT(DISTINCT date_commande) AS count_date_2
            FROM      reservation
            GROUP BY  id_client
          ) AS a4 USING (id_client_2)
WHERE
  CASE
    WHEN  count_date_1 > count_date_2 THEN count_date_1 = count_couple
    ELSE  count_date_2 = count_couple
  END
ORDER BY  id_client, id_client_2;




-- REQUETES PERSONNELLES

-- 11 - Tous les modeles de camera qui on au moins deux exemplaires disponibles
-- Requete avec 3 tables, GROUP BY et HAVING
PREPARE   q11 AS
SELECT    modele
FROM      (reservation JOIN materiel_reserve USING (id_reservation)) JOIN camera USING (id_materiel)
WHERE     date_fin < NOW()
GROUP BY  modele
HAVING    COUNT(modele) > 2;


-- 12 - Pour chaque vehicule, le nombre de fois qu'il a été reservé
-- Requete avec 2 tables, sous-requete dans le SELECT
PREPARE   q12 AS
SELECT    id_materiel,
          (
            SELECT    COUNT(id_materiel)
            FROM      materiel_reserve
            WHERE     id_materiel = v.id_materiel
          )
FROM      vehicule AS v;


-- 13 - Les studios réservés en 2015 ayant une valeur de plus de 2000 €
-- Requete avec 2 tables, sous-requete dans le WHERE, GROUP BY et HAVING
PREPARE   q13 AS
SELECT    id_studio,
          SUM(prix) AS valeur
FROM      materiel
WHERE     id_studio IS NOT NULL
  AND     id_studio IN (
            SELECT  id_studio
            FROM    reservation
            WHERE   EXTRACT(year FROM date_debut) = 2015
              OR    EXTRACT(year FROM date_fin) = 2015
          )
GROUP BY  id_studio
HAVING    SUM(prix) > 2000
ORDER BY  id_studio;


-- 14 - L'identifiant et d'adresse du studio qui contient le plus grand nombre
--      de materiel
-- Requete avec 2 table, sous-requete dans le FROM
PREPARE q14 AS
SELECT  id_studio,
        adresse,
        ville,
        code_postal
FROM    (
          SELECT    id_studio,
                    COUNT(id_materiel) AS nb_materiel
          FROM      materiel
          WHERE     id_studio IS NOT NULL
          GROUP BY  id_studio
          ORDER BY COUNT(id_materiel) DESC
          LIMIT 1
        ) AS nb_materiel_studio NATURAL JOIN studio;


-- 15 - Le nom, prenom et la dépense total (materiel et studio) de chaque client par ordre decroissant
-- Requete avec 4 tables, sous-requete correlée dans le SELECT, COALESCE
PREPARE   q15 AS
SELECT    nom,
          prenom,
          COALESCE((
            SELECT    SUM(prix)
            FROM      materiel NATURAL JOIN materiel_reserve
            WHERE     id_reservation IN (
                        SELECT    id_reservation
                        FROM      reservation
                        WHERE     id_client = c.id_client
                      )
          ) + (
            COALESCE(
              (SELECT    SUM(prix)
              FROM      reservation NATURAL JOIN studio
              WHERE     id_client = c.id_client
            ), 0)
          ), 0) AS depense
FROM      client AS c
ORDER BY  depense DESC;


-- 16 - Les cameras disponibles en reservation le 13 avril 2015
-- Requete avec 3 tables, sous-requete dans le WHERE
PREPARE   q16 AS
SELECT    modele,
          COUNT(modele) AS nombre_disponible
FROM      camera
WHERE     id_materiel NOT IN (
            SELECT    id_materiel
            FROM      materiel_reserve NATURAL JOIN reservation
            WHERE     (date '04/13/2015' > date_debut
              AND     date '04/13/2015' < date_fin)
            GROUP BY  id_materiel
          )
  AND     id_studio IS NULL
GROUP BY  modele
ORDER BY  modele;


-- 17 - Pour chaque modele de camera qui on été réservé, le pourcentage de
--      réservation du client 1
-- Requete avec 3 tables, LEFT JOIN, sous-requete dans le FROM
PREPARE   q17 AS
SELECT    modele,
          ROUND(
            100.0 * (COUNT(id_reservation) / SUM(total_resa)), 2
          ) AS pourcentage_reservation
FROM      (
            SELECT    id_materiel,
                      modele,
                      COUNT(prix) AS total_resa
            FROM      camera JOIN (
                        materiel_reserve
                        NATURAL JOIN reservation
                      ) AS a USING (id_materiel)
            GROUP BY  id_materiel, modele, prix
          ) AS c LEFT JOIN (
            SELECT    id_materiel,
                      id_reservation
            FROM      materiel_reserve NATURAL JOIN (
                        SELECT    id_reservation
                        FROM      reservation
                        WHERE     id_client = 1
                      ) AS b
          ) AS d USING (id_materiel)
GROUP BY  modele
ORDER BY  modele;


-- 18 - Reservation d'un matériel pour une plage de temps donnée pour le client
--      d'identifiant 5

PREPARE   q18a AS
INSERT INTO reservation(id_client,date_commande,date_debut,date_fin,heure_debut,id_studio)
  VALUES
  (5,NOW(),'06/10/2015','06/12/2015',9,null);

PREPARE   q18b AS
INSERT INTO materiel_reserve(id_reservation, id_materiel, duree)
  VALUES
  (
    (SELECT    id_reservation
    FROM      reservation
    WHERE     id_client = 5
      AND     date_commande = NOW()
      AND     date_debut = '06/10/2015'
      AND     date_fin = '06/12/2015'
    LIMIT 1),
    8, 6
  );


-- 19 - Reduction obtenu pour chaque client sur les réservations effectuées il y a moins d'un an
--      Réduction de 50€, s'il y a eu plus de 5 réservations
PREPARE   q19 AS
SELECT    nom,
          prenom,
          (CASE
            WHEN nbr_reservation > 5
              THEN  50
              ELSE 0
          END) AS reduction_obtenu
FROM      client NATURAL JOIN (
            SELECT    id_client,
                      COUNT(id_reservation) AS nbr_reservation
            FROM      reservation
            WHERE     date_commande < (NOW() - interval '1 year')
            GROUP BY  id_client
          ) AS a;


