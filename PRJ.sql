CREATE TABLESPACE SQL3_TBS
DATAFILE 'C:\tbs\SQL3_TBS.dat'
SIZE 100M
AUTOEXTEND ON
ONLINE;

CREATE TABLESPACE SQL3_TempTBS
TEMPFILE 'C:\tbs\SQL3_TempTBS.dat'
SIZE 100M
AUTOEXTEND ON
ONLINE;

CREATE USER SQL3 
IDENTIFIED BY Password123 
DEFAULT TABLESPACE SQL3_TBS 
TEMPORARY TABLESPACE SQL3_TempTBS 
QUOTA UNLIMITED ON SQL3_TBS;

GRANT ALL PRIVILEGES 
TO SQL3;

/* ---------- TYPES ---------- */
CREATE TYPE TExploitation;
/
CREATE TYPE TParcelle;
/
CREATE TYPE TCulture;
/
CREATE TYPE TCampagne;
/
CREATE TYPE TSemis;
/
CREATE TYPE TMaladie;
/
CREATE TYPE TDetection_Maladie;
/
CREATE TYPE TDrone;
/
CREATE TYPE TMission_Drone;
/
CREATE TYPE tset_ref_Parcelle AS TABLE OF ref TParcelle
/
CREATE TYPE tset_ref_Semis AS TABLE OF ref TSemis
/
CREATE TYPE tset_ref_Mission_Drone AS TABLE OF ref TMission_Drone
/
CREATE TYPE tset_ref_Detection_Maladie AS TABLE OF ref TDetection_Maladie
/
CREATE OR Replace TYPE TExploitation AS OBJECT(
    id_exploitation         CHAR(6),
    nom_exploitation        VARCHAR2(50),
    superficie_exploitation NUMBER(38),
    region                  VARCHAR2(50),
    nbr_parcelles           NUMBER(38),
    Exploitation_Parcelle   tset_ref_Parcelle
);
/
CREATE OR Replace TYPE TParcelle AS OBJECT (
    id_parcelle             CHAR(4),
    nom_parcelle            VARCHAR(50),
    superficie_parcelle     INT,
    type_sol                VARCHAR(50),
    Parcelle_Exploitation   ref TExploitation,
    Parcelle_Semis          tset_ref_Semis,
    Parcelle_Maladie        tset_ref_Detection_Maladie,
    Parcelle_Mission        tset_ref_Mission_Drone
);
/
CREATE OR Replace TYPE TCulture AS OBJECT (
    id_culture              CHAR(6),
    nom_culture             VARCHAR(50),
    variete_culture         VARCHAR(50)
);
/
CREATE OR Replace TYPE TCampagne AS OBJECT (
    id_campagne             CHAR(6),
    annee                   INT,
    date_debut              DATE,
    date_fin                DATE,
    Campagne_Semis          tset_ref_Semis,
    Campagne_Maladie        tset_ref_Detection_Maladie,
    Campagne_Mission        tset_ref_Mission_Drone
);
/
CREATE OR Replace TYPE TSemis AS OBJECT (
    id_semis                CHAR(4),
    date_semis              DATE,
    quantite_semis          INT,
    semis_parcelle          ref TParcelle,
    semis_culture           ref TCulture,
    semis_campagne          ref TCampagne
);
/
CREATE OR Replace TYPE TMaladie AS OBJECT (
    id_maladie              CHAR(6),
    nom_maladie             VARCHAR(50),
    type_maladie            VARCHAR(50)
);
/
CREATE OR Replace TYPE TDetection_Maladie AS OBJECT (
    id_detection            CHAR(4),
    date_detection          DATE,
    gravite                 VARCHAR(10),
    maladie_parcelle        ref TParcelle,
    maladie_campagne        ref TCampagne,
    maladie_maladie         ref TMaladie
);
/
CREATE OR Replace TYPE TDrone AS OBJECT (
    id_drone                CHAR(6),
    modele                  VARCHAR(50),
    type_drone              VARCHAR(50),
    capacite_batterie       INT,
    statut_drone            VARCHAR(20),
    Drone_Mission           tset_ref_Mission_Drone
);
/
CREATE OR Replace TYPE TMission_Drone AS OBJECT (
    id_mission              CHAR(6),
    date_mission            DATE,
    type_mission            VARCHAR(50),
    resultats               VARCHAR(255),
    mission_drone           ref TDrone,
    mission_parcelle        ref TParcelle,
    mission_campagne        ref TCampagne,
    mission_maladie         ref TMaladie
);
/

-------------------------------2.1.Surface Totale des Parcelles par Exploitation-------------------------
ALTER TYPE TExploitation ADD MEMBER FUNCTION Surface_Totale_Parcelles RETURN NUMBER CASCADE;
/
CREATE OR REPLACE TYPE BODY TExploitation AS
  MEMBER FUNCTION Surface_Totale_Parcelles RETURN NUMBER IS
    total NUMBER := 0;
    p TParcelle;
  BEGIN
    IF Exploitation_Parcelle IS NOT NULL THEN
      FOR i IN 1 .. Exploitation_Parcelle.COUNT LOOP
        p := DEREF(Exploitation_Parcelle(i));
        total := total + p.superficie_parcelle;
      END LOOP;
    END IF;
    RETURN total;
  END;
END;
/

--------------------------------2.2.Cultures Semées pendant une Campagne Agricole :--------------------------
CREATE TYPE tset_ref_Culture AS TABLE OF ref TCulture;
/ 
ALTER TYPE TExploitation ADD MEMBER FUNCTION Cultures_Serees_Campagne(id_camp CHAR) RETURN tset_ref_Culture CASCADE;
/ 
CREATE OR REPLACE TYPE BODY TExploitation AS
  MEMBER FUNCTION Cultures_Serees_Campagne(id_camp CHAR)
  RETURN tset_ref_Culture IS
    cultures tset_ref_Culture := tset_ref_Culture();  -- collection à retourner
    p TParcelle;
    s TSemis;
    c TCampagne;
  BEGIN
    IF Exploitation_Parcelle IS NOT NULL THEN
      FOR i IN 1 .. Exploitation_Parcelle.COUNT LOOP
        p := DEREF(Exploitation_Parcelle(i));  -- deref la parcelle

        IF p.Parcelle_Semis IS NOT NULL THEN
          FOR j IN 1 .. p.Parcelle_Semis.COUNT LOOP
            s := DEREF(p.Parcelle_Semis(j));  -- deref le semis

            IF s.semis_campagne IS NOT NULL THEN
              c := DEREF(s.semis_campagne);  -- deref la campagne

              IF c.id_campagne = id_camp THEN
                cultures.EXTEND;
                cultures(cultures.COUNT) := s.semis_culture;  -- ajouter la ref culture
              END IF;
            END IF;
          END LOOP;
        END IF;
      END LOOP;
    END IF;

    RETURN cultures;
  END;
END;
/

-------------------------------------------------2.3.Cultures sur Parcelle durant la Campagne--------------

CREATE TYPE tset_ref_Culture AS TABLE OF ref TCulture;
/
ALTER TYPE TParcelle ADD MEMBER FUNCTION Cultures_Presentes_Campagne(id_camp CHAR) RETURN tset_ref_Culture CASCADE;
/
CREATE OR REPLACE TYPE BODY TParcelle AS
  MEMBER FUNCTION Cultures_Presentes_Campagne(id_camp CHAR)
  RETURN tset_ref_Culture IS
    cultures tset_ref_Culture := tset_ref_Culture(); -- initialiser le tableau vide
    s TSemis;
    c TCampagne;
  BEGIN
    -- Vérification si la parcelle a des semis
    IF Parcelle_Semis IS NOT NULL THEN
      FOR i IN 1 .. Parcelle_Semis.COUNT LOOP
        s := DEREF(Parcelle_Semis(i));  -- déréférencement correct
        IF s.semis_campagne IS NOT NULL THEN
          c := DEREF(s.semis_campagne);
          -- Vérifier si le semis appartient à la campagne donnée
          IF c.Id_campagne = id_camp THEN
            cultures.EXTEND;
            cultures(cultures.COUNT) := s.semis_culture; -- Ajouter la culture à la liste
          END IF;
        END IF;
      END LOOP;
    END IF;
    RETURN cultures;
  END;
END;
/


-----------------------------------2.4.Maladies Détectées avec Gravité Forte sur Parcelle---------
CREATE TYPE tset_ref_Maladie AS TABLE OF ref TMaladie;
/
ALTER TYPE TParcelle ADD MEMBER FUNCTION Maladies_Fortes RETURN tset_ref_Maladie CASCADE;
/
CREATE OR REPLACE TYPE BODY TParcelle AS
  MEMBER FUNCTION Maladies_Fortes RETURN tset_ref_Maladie IS
    maladies tset_ref_Maladie := tset_ref_Maladie(); -- initialisation
    d TDetection_Maladie;
  BEGIN
    IF Parcelle_Maladie IS NOT NULL THEN
      FOR i IN 1 .. Parcelle_Maladie.COUNT LOOP
        d := DEREF(Parcelle_Maladie(i)); -- déréférencement direct
        IF LOWER(d.gravite) = 'forte' THEN
          maladies.EXTEND;
          maladies(maladies.COUNT) := d.maladie_maladie;
        END IF;
      END LOOP;
    END IF;
    RETURN maladies;
  END;
END;
/
----------------------------------------------2.5.Missions par Type de Drone
CREATE TYPE tset_ref_Mission_Drone AS TABLE OF ref TMission_Drone;
/
ALTER TYPE TDrone ADD MEMBER FUNCTION Missions_Par_Type(type_mission_in VARCHAR2) RETURN tset_ref_Mission_Drone CASCADE;
/
CREATE OR REPLACE TYPE BODY TDrone AS
  MEMBER FUNCTION Missions_Par_Type(type_mission_in VARCHAR2)
  RETURN tset_ref_Mission_Drone IS
    missions tset_ref_Mission_Drone := tset_ref_Mission_Drone();
    m_ref REF TMission_Drone;
    m TMission_Drone;
  BEGIN
    IF Drone_Mission IS NOT NULL THEN
      FOR i IN 1 .. Drone_Mission.COUNT LOOP
        m_ref := Drone_Mission(i);
        m := DEREF(m_ref); -- déréférencement direct
        IF m.type_mission = type_mission_in THEN
          missions.EXTEND;
          missions(missions.COUNT) := m_ref;
        END IF;
      END LOOP;
    END IF;
    RETURN missions;
  END;
END;
/




------------------------------------------------CREATE TABLES --------------------
CREATE TABLE Exploitation OF TExploitation( CONSTRAINT pk_id_exploitation PRIMARY KEY (id_exploitation))
                                            NESTED TABLE Exploitation_Parcelle STORE AS NESTED_Exploitation_Parcelle
;
CREATE TABLE Parcelle OF TParcelle( CONSTRAINT pk_id_parcelle PRIMARY KEY (id_parcelle),
                                    CONSTRAINT fk_Exploitation FOREIGN KEY(Parcelle_Exploitation) REFERENCES Exploitation,
                                    CONSTRAINT ck_type_sol CHECK (type_sol IN ('argileux', 'sableux', 'limoneux','calcaire','humifère','tourbeux')))
                                    NESTED TABLE Parcelle_Semis   STORE AS NESTED_Parcelle_Semis,
                                    NESTED TABLE Parcelle_Maladie STORE AS NESTED_Parcelle_Maladie,
                                    NESTED TABLE Parcelle_Mission STORE AS NESTED_Parcelle_Mission
;
CREATE TABLE Culture OF TCulture( CONSTRAINT PK_id_culture PRIMARY KEY (id_culture))
;
CREATE TABLE Campagne OF TCampagne( CONSTRAINT pk_id_campagne PRIMARY KEY (id_campagne),
                                    CONSTRAINT ck_date CHECK (date_debut <= date_fin))
                                    NESTED TABLE Campagne_Semis   STORE AS NESTED_Campagne_Semis,
                                    NESTED TABLE Campagne_Maladie STORE AS NESTED_Campagne_Maladie,
                                    NESTED TABLE Campagne_Mission STORE AS NESTED_Campagne_Mission
;
CREATE TABLE Semis OF TSemis( CONSTRAINT pk_id_semis PRIMARY KEY(id_semis),
                              CONSTRAINT fk_parcelle FOREIGN KEY(semis_parcelle) REFERENCES Parcelle,
                              CONSTRAINT fk_culture  FOREIGN KEY(semis_culture) REFERENCES Culture,
                              CONSTRAINT fk_campagne FOREIGN KEY(semis_campagne) REFERENCES Campagne)
;
CREATE TABLE Maladie OF TMaladie(CONSTRAINT pk_id_maladie PRIMARY KEY(id_maladie),
                                 CONSTRAINT ck_type_maladie CHECK(type_maladie IN ('fongique','bactérienne','virale','parasitique','physiologique')))
;
CREATE TABLE DETECTIONMALADIE  OF TDetection_Maladie ( CONSTRAINT pk_id_detection PRIMARY KEY(id_detection),
                                                       CONSTRAINT ck_gravite  CHECK(gravite IN ('faible', 'moyenne', 'forte')),
                                                       CONSTRAINT fk_detection_parcelle FOREIGN KEY(maladie_parcelle) REFERENCES Parcelle,
                                                       CONSTRAINT fk_detection_maladie  FOREIGN KEY(maladie_maladie)  REFERENCES Maladie,
                                                       CONSTRAINT fk_detection_campagne FOREIGN KEY(maladie_campagne) REFERENCES Campagne)
;
CREATE TABLE Drone OF TDrone ( CONSTRAINT pk_id_drone PRIMARY KEY(id_drone),
                               CONSTRAINT ck_type_drone CHECK (type_drone IN ('multirotor','iles fixes','hybride','à voilure tournante','autonome')),
                               CONSTRAINT ck_statut_drone  CHECK(statut_drone IN ('Disponible', 'En Maintenance', 'En Mission')))
                               NESTED TABLE Drone_Mission STORE AS NESTED_Drone_Mission
;                              
CREATE TABLE Mission_Drone OF TMission_Drone ( CONSTRAINT pk_id_mission PRIMARY KEY(id_mission),
                                               CONSTRAINT ck_type_mission CHECK (type_mission IN ('surveillance','traitement','cartographie','analyse thermique')),
                                               CONSTRAINT fk_mission_parcelle FOREIGN KEY(mission_parcelle) REFERENCES Parcelle,
                                               CONSTRAINT fk_mission_maladie  FOREIGN KEY(mission_maladie)    REFERENCES Maladie,
                                               CONSTRAINT fk_mission_campagne FOREIGN KEY(mission_campagne) REFERENCES Campagne,
                                               CONSTRAINT fk_mission_drone    FOREIGN KEY(mission_drone)    REFERENCES Drone)
;

-----------------------------------------------------------------------------------------------------------------

SELECT e.id_exploitation, p.id_parcelle
FROM Exploitation e,
     TABLE(e.Exploitation_Parcelle) ep,
     Parcelle p
WHERE VALUE(ep) = REF(p)
ORDER BY e.id_exploitation, p.id_parcelle;
-----------------------------------------------------------------------------------------------------------------
SELECT
  p.id_parcelle,
  p.nom_parcelle,
  (SELECT COUNT(*) FROM TABLE(p.Parcelle_Semis)) AS nombre_semis,
  (SELECT COUNT(*) FROM TABLE(p.Parcelle_Maladie)) AS nombre_detections,
  (SELECT COUNT(*) FROM TABLE(p.Parcelle_Mission)) AS nombre_missions,
  CASE
    WHEN (SELECT COUNT(*) FROM TABLE(p.Parcelle_Semis)) > 0 THEN
      (SELECT COUNT(*) FROM TABLE(p.Parcelle_Maladie)) * 100 / (SELECT COUNT(*) FROM TABLE(p.Parcelle_Semis))
    ELSE 0
  END AS taux_maladies_par_semis,
  CASE
    WHEN (SELECT COUNT(*) FROM TABLE(p.Parcelle_Mission)) > 0 THEN
      (SELECT COUNT(*) FROM TABLE(p.Parcelle_Maladie)) * 100 / (SELECT COUNT(*) FROM TABLE(p.Parcelle_Mission))
    ELSE 0
  END AS taux_maladies_par_mission
FROM Parcelle p
ORDER BY
  p.id_parcelle;
-----------------------------------------------------------------------------------------------------------------

SELECT
    d.id_drone,
    d.type_drone,
    d.statut_drone,
    (SELECT COUNT(*) FROM TABLE(d.Drone_Mission)) AS nombre_missions
FROM
    Drone d
ORDER BY
    d.id_drone;


SELECT
  d.id_drone,
  d.type_drone,
  d.statut_drone,
  m.id_mission,
  m.type_mission
FROM
  Drone d,
  TABLE(d.Drone_Mission) dm,
  Mission_Drone m
WHERE
  dm = REF(m)
  AND m.type_mission = 'traitement'
ORDER BY
  d.id_drone, m.id_mission;


SELECT
  d.id_drone,
  d.type_drone,
  d.statut_drone,
  COUNT(*) AS nombre_missions_traitement
FROM
  Drone d,
  TABLE(d.Drone_Mission) dm,
  Mission_Drone m
WHERE
  dm = REF(m)
  AND m.type_mission = 'traitement'
GROUP BY
  d.id_drone, d.type_drone, d.statut_drone
ORDER BY
  d.id_drone;

-----------------------------------------------------------------------------------------------------------------
SELECT

        e.ID_EXPLOITATION,

        e.NOM_EXPLOITATION,

        p.REGION,

        p.ID_PARCELLE,

        p.ANNEE_CAMPAGNE,

        c.ID_CULTURE,

        cu.NOM_CULTURE,

        v.VARIETE_CULTURE,

       s.DATE_SEMIS,

       s.QUANTITE_SEMIS

   FROM

       Exploitation e,

       TABLE(e.EXPLOITATION_PARCELLE) p,

       Parcelle pa,

       Culture_v_an c,

       Culture cu,

       Semis s,

       Campagne ca

   WHERE

       (pa.ID_PARCELLE = REF(p))

       AND (s.ID_PARCELLE = REF(p))

       AND (s.ID_CULTURE = REF(c))

       AND (s.ID_CAMPAGNE = REF(ca))

   ORDER BY

       e.ID_EXPLOITATION,

       p.ID_PARCELLE,

       c.ANNEE_CAMPAGNE,

       s.DATE_SEMIS;
	   
SELECT
  e.id_exploitation,
  e.nom_exploitation,
  DEREF(p).region AS region,
  DEREF(p).id_parcelle AS id_parcelle,
  ca.id_campagne,
  cu.id_culture,
  cu.nom_culture,
  s.date_semis,
  s.quantite
FROM
  Exploitation e,
  TABLE(e.exploitation_parcelle) p,
  Parcelle pa,
  TABLE(DEREF(p).parcelle_semis) ps,
  Semis s,
  Culture cu,
  Campagne ca
WHERE
  REF(pa) = p
  AND REF(s) = ps
  AND s.semis_parcelle = REF(pa)
  AND s.semis_culture = REF(cu)
  AND s.semis_campagne = REF(ca)
ORDER BY
  e.id_exploitation,
  DEREF(p).id_parcelle,
  ca.id_campagne,
  s.date_semis;

-------------------------------------------------------------------------------------------------------------------
SELECT

  d.id_drone,

  d.modele,

  d.type_drone,

  d.capacite_batterie,

  d.statut_drone

FROM

  Drone d

WHERE

  d.statut_drone = 'Disponible' AND

  NOT EXISTS (

    SELECT 1

    FROM Mission_Drone md

    WHERE md.mission_drone = REF(d) AND md.type_mission = 'surveillance' AND md.date_mission > SYSDATE

  )

ORDER BY

  d.id_drone;
---------------------------------------------------------------------------------------------------------------------
SELECT
  annee,
  nombre_de_detections
FROM (
  SELECT
    EXTRACT(YEAR FROM d.date_detection) AS annee,
    COUNT(*) AS nombre_de_detections
  FROM
    DETECTIONMALADIE d
  GROUP BY
    EXTRACT(YEAR FROM d.date_detection)
  ORDER BY
    nombre_de_detections DESC
)
WHERE ROWNUM = 1;  