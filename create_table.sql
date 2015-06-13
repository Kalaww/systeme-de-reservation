-- CREATION DES TABLES

-- CLIENT
CREATE TABLE client(
       id_client SERIAL PRIMARY KEY,
       nom VARCHAR(255) NOT NULL,
       prenom VARCHAR(255),
       naissance DATE,
      inscription DATE NOT NULL,
      reduction int
);


-- STUDIO
CREATE TABLE studio(
       id_studio SERIAL PRIMARY KEY,
       adresse VARCHAR(255) NOT NULL,
       ville VARCHAR(255) NOT NULL,
       code_postal int NOT NULL,
       prix int NOT NULL,
       nbJour_max int NOT NULL
);


-- MATERIEL
CREATE TABLE materiel(
       id_materiel SERIAL PRIMARY KEY,
       modele VARCHAR(255) NOT NULL,
       prix int NOT NULL,
       poids int,
       emprunt_min int,
       emprunt_max int,
       id_studio int,
       FOREIGN KEY (id_studio) REFERENCES studio(id_studio)
);


-- OBJECTIFS
CREATE TABLE objectif(
       longueur int,
       zoom_min int,
       zoom_max int,
       ouverture_min DECIMAL(5,2),
       ouverture_max DECIMAL(5,2)
) INHERITS (materiel);


-- CAMERA
CREATE TABLE camera(
       marque VARCHAR(255),
       nb_dimension int,
       format VARCHAR(255)
) INHERITS (materiel);


-- SON
CREATE TABLE son(
       marque VARCHAR(255)
) INHERITS (materiel);


-- ACCESSOIRE
CREATE TABLE accessoire(
       nom VARCHAR(255) NOT NULL
) INHERITS (materiel);


-- VEHICULE
CREATE TABLE vehicule(
       nb_place int
) INHERITS (materiel);


-- LUMIERE
CREATE TABLE lumiere(
       type VARCHAR(100),
       puissance VARCHAR(255),
       couleur VARCHAR(255)
) INHERITS (materiel);


-- RESERVATION
CREATE TABLE reservation(
       id_reservation SERIAL PRIMARY KEY,
       heure_debut int NOT NULL,
       date_commande DATE NOT NULL,
       date_debut DATE NOT NULL,
       date_fin DATE NOT NULL,
       id_client int NOT NULL,
       id_studio int,
       FOREIGN KEY (id_client) REFERENCES client(id_client),
       FOREIGN KEY (id_studio) REFERENCES studio(id_studio)
);


-- MATERIEL RESERVE
CREATE TABLE materiel_reserve(
       id_reservation int,
       id_materiel int,
       duree int,
       PRIMARY KEY(id_reservation, id_materiel)
);
