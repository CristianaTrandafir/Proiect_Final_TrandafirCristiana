-- 5. Etapa 3 – Interogări SQL

-- A. Crearea bazei de date

/* 1. Creează baza de date technova_hr și tabelele departamente, angajati, evaluari,
cu tipurile de date potrivite (ex: INT, VARCHAR, DECIMAL, DATE), cheie primară pe fiecare
tabel și chei străine: angajati.id_departament → departamente, evaluari.id_angajat →
angajati. (În SQLite nu există CREATE DATABASE: baza de date este chiar fișierul
technova_hr.db.) */

-- Crearea bazei de date
IF DB_ID('technova_hr') IS NULL
    CREATE DATABASE technova_hr;
GO

USE technova_hr;
GO

-- Crearea tabelelelor cu chei primare si straine
DROP TABLE IF EXISTS evaluari;
DROP TABLE IF EXISTS angajati;
DROP TABLE IF EXISTS departamente;
GO

CREATE TABLE departamente (
    id_departament   INT           NOT NULL PRIMARY KEY,
    nume_departament NVARCHAR(50)  NOT NULL,
    oras_sediu       NVARCHAR(50)  NULL,
    buget_anual_lei  DECIMAL(12,2) NULL
);

CREATE TABLE angajati (
    id_angajat         INT           NOT NULL PRIMARY KEY,
    nume               NVARCHAR(50)  NOT NULL,
    prenume            NVARCHAR(50)  NOT NULL,
    gen                CHAR(1)       NULL,
    data_nasterii      DATE          NULL,
    data_angajarii     DATE          NULL,
    id_departament     INT           NOT NULL,
    functie            NVARCHAR(100) NULL,
    nivel              NVARCHAR(30)  NULL,
    oras               NVARCHAR(50)  NULL,
    tip_contract       NVARCHAR(30)  NULL,
    salariu_brut_lunar DECIMAL(10,2) NULL,
    status             NVARCHAR(20)  NULL,
    data_plecarii      DATE          NULL,
    motiv_plecare      NVARCHAR(100) NULL,
    email              NVARCHAR(100) NULL,
    nume_departament   NVARCHAR(50)  NULL,
    varsta             INT           NULL,
    vechime_ani        DECIMAL(5,1)  NULL,
    grupa_vechime      NVARCHAR(20)  NULL,
    plecat             BIT           NULL,
    CONSTRAINT FK_angajati_departamente
        FOREIGN KEY (id_departament) REFERENCES departamente(id_departament)
);

CREATE TABLE evaluari (
    id_evaluare             INT          NOT NULL PRIMARY KEY,
    id_angajat              INT          NOT NULL,
    an_evaluare             INT          NULL,
    scor_performanta        DECIMAL(3,1) NULL,
    satisfactie_angajat     DECIMAL(3,1) NULL,
    ore_suplimentare_lunare DECIMAL(5,1) NULL,
    ore_training_anual      INT          NULL,
    zile_concediu_medical   INT          NULL,
    procent_bonus           DECIMAL(5,2) NULL,
    CONSTRAINT FK_evaluari_angajati
        FOREIGN KEY (id_angajat) REFERENCES angajati(id_angajat)
);
GO

/* 2. Importă datele din departamente.csv, angajati_curat.csv și
evaluari_curat.csv, în această ordine (din cauza cheilor străine). Metode: MySQL
Workbench → click dreapta pe tabel → Table Data Import Wizard; pgAdmin → Import/Export
Data; SQL Server → Import Flat File; DB Browser for SQLite → File → Import. Celulele
goale (ex: data_plecarii la angajații activi) trebuie să devină NULL. */

-- Import CSV; FIRSTROW = 2 sare peste antet si KEEPNULLS transforma celulele goale (ex: data_plecarii la angajatii activi) in NULL
BULK INSERT departamente
FROM 'C:\temp\departamente.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', KEEPNULLS);

BULK INSERT angajati
FROM 'C:\temp\angajati_curat.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', KEEPNULLS);

BULK INSERT evaluari
FROM 'C:\temp\evaluari_curat.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', KEEPNULLS);
GO

-- Verificare: angajatii activi trebuie sa aiba data_plecarii NULL.
SELECT COUNT(*) AS activi_cu_data_plecarii_null
FROM angajati
WHERE status = 'Activ' AND data_plecarii IS NULL;
GO

/* 3. Verifică importul: trebuie să ai 8 departamente, 480 de angajați și numărul de evaluări din
evaluari_curat.csv. */

-- Verificare: numarul de randuri (asteptat: 8, 480, 1138).
SELECT 'departamente' AS tabel, COUNT(*) AS randuri FROM departamente
UNION ALL SELECT 'angajati', COUNT(*) FROM angajati
UNION ALL SELECT 'evaluari', COUNT(*) FROM evaluari;

-- B. Interogari obligatorii

/* 1. Numărul total de angajați, câți sunt activi și câți au plecat.*/

SELECT COUNT(*) AS total_angajati,
       SUM(CASE WHEN status = 'Activ'  THEN 1 ELSE 0 END) AS activi,
       SUM(CASE WHEN status = 'Plecat' THEN 1 ELSE 0 END) AS plecati
FROM angajati;
GO

/* 2. Numărul de angajați pe departament (cu numele departamentului), ordonat descrescător. (JOIN) */

SELECT d.nume_departament, COUNT(a.id_angajat) AS nr_angajati
FROM departamente d
JOIN angajati a ON a.id_departament = d.id_departament
GROUP BY d.nume_departament
ORDER BY nr_angajati DESC;
GO

/* 3. Salariul mediu, minim și maxim pe fiecare nivel. */

SELECT nivel,
       AVG(salariu_brut_lunar) AS salariu_mediu,
       MIN(salariu_brut_lunar) AS salariu_minim,
       MAX(salariu_brut_lunar) AS salariu_maxim
FROM angajati
GROUP BY nivel
ORDER BY salariu_mediu DESC;
GO

/* 4. Rata de plecare (%) pe fiecare departament = 100 × nr. plecați / nr. angajați. (CASE WHEN
+ GROUP BY; folosește 100.0 * ca rezultatul să nu fie rotunjit la 0) */

SELECT d.nume_departament,
       COUNT(*) AS nr_angajati,
       SUM(CASE WHEN a.status = 'Plecat' THEN 1 ELSE 0 END) AS nr_plecati,
       CONCAT(
           CAST(100.0 * SUM(CASE WHEN a.status = 'Plecat' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)),
           '%'
       ) AS rata_plecare_pct
FROM angajati a
JOIN departamente d ON d.id_departament = a.id_departament
GROUP BY d.nume_departament
ORDER BY 100.0 * SUM(CASE WHEN a.status = 'Plecat' THEN 1 ELSE 0 END) / COUNT(*) DESC;
GO

/* 5. Departamentele cu o rată de plecare mai mare de 20%. (HAVING) */

SELECT d.nume_departament,
       CONCAT(
           CAST(100.0 * SUM(CASE WHEN a.status = 'Plecat' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)),
           '%'
       ) AS rata_plecare_pct
FROM angajati a
JOIN departamente d ON d.id_departament = a.id_departament
GROUP BY d.nume_departament
HAVING 100.0 * SUM(CASE WHEN a.status = 'Plecat' THEN 1 ELSE 0 END) / COUNT(*) > 20
ORDER BY 100.0 * SUM(CASE WHEN a.status = 'Plecat' THEN 1 ELSE 0 END) / COUNT(*) DESC;
GO

/* 6. Salariul mediu pe gen în fiecare departament. */

SELECT d.nume_departament, a.gen,
       CAST(AVG(a.salariu_brut_lunar) AS DECIMAL(12,2)) AS salariu_mediu
FROM angajati a
JOIN departamente d ON d.id_departament = a.id_departament
GROUP BY d.nume_departament, a.gen
ORDER BY d.nume_departament, a.gen;
GO

/* 7. Top 10 cei mai bine plătiți angajați activi: nume, prenume, departament, nivel, salariu. */

SELECT TOP 10 a.nume, a.prenume, d.nume_departament, a.nivel, a.salariu_brut_lunar
FROM angajati a
JOIN departamente d ON d.id_departament = a.id_departament
WHERE a.status = 'Activ'
ORDER BY a.salariu_brut_lunar DESC;
GO

/* 8. Motivele de plecare, cu numărul de angajați plecați pentru fiecare motiv și procentul din
totalul angajaților plecați. */

SELECT motiv_plecare,
       COUNT(*) AS nr_plecati,
       CONCAT(
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)),
           '%'
       ) AS procent_din_plecati
FROM angajati
WHERE status = 'Plecat'
GROUP BY motiv_plecare
ORDER BY nr_plecati DESC;
GO

/* 9. Angajații al căror salariu este mai mare decât media departamentului lor; media se
calculează pe toți angajații departamentului. (subinterogare) */

SELECT a.id_angajat, a.nume, a.prenume, d.nume_departament, a.salariu_brut_lunar
FROM angajati a
JOIN departamente d ON d.id_departament = a.id_departament
WHERE a.salariu_brut_lunar > (SELECT AVG(a2.salariu_brut_lunar)
                              FROM angajati a2
                              WHERE a2.id_departament = a.id_departament)
ORDER BY d.nume_departament, a.salariu_brut_lunar DESC;
GO

/* 10. Angajații care nu au nicio evaluare: câți sunt și ce status au? (LEFT JOIN + IS NULL) */

-- Cati angajati nu au nicio evaluare?
SELECT COUNT(*) AS angajati_fara_evaluari
FROM angajati a
LEFT JOIN evaluari e ON e.id_angajat = a.id_angajat
WHERE e.id_evaluare IS NULL;
GO

-- Ce status au angajatii fara nicio evaluare?
SELECT a.status, COUNT(*) AS nr_angajati
FROM angajati a
LEFT JOIN evaluari e ON e.id_angajat = a.id_angajat
WHERE e.id_evaluare IS NULL
GROUP BY a.status;
GO

/* 11. Numărul de evaluări din 2025 pe categorii de satisfacție: Scăzută (1–4), Medie (5–7),
Ridicată (8–10). (CASE WHEN) */

SELECT CASE WHEN satisfactie_angajat <= 4 THEN N'Scăzută'
            WHEN satisfactie_angajat <= 7 THEN N'Medie'
            ELSE N'Ridicată' END AS categorie_satisfactie,
       COUNT(*) AS nr_evaluari
FROM evaluari
WHERE an_evaluare = 2025
GROUP BY CASE WHEN satisfactie_angajat <= 4 THEN N'Scăzută'
              WHEN satisfactie_angajat <= 7 THEN N'Medie'
              ELSE N'Ridicată' END
ORDER BY MIN(satisfactie_angajat);
GO

/* 12. Scorul mediu de performanță, bonusul mediu și orele suplimentare medii pe departament,
pentru evaluările din 2025. (JOIN pe toate cele 3 tabele) */

SELECT d.nume_departament,
       CAST(AVG(e.scor_performanta) AS DECIMAL(10,2))        AS scor_mediu_performanta,
       CAST(AVG(e.procent_bonus) AS DECIMAL(10,2))           AS bonus_mediu_pct,
       CAST(AVG(e.ore_suplimentare_lunare) AS DECIMAL(10,2)) AS ore_suplimentare_medii
FROM evaluari e
JOIN angajati a     ON a.id_angajat = e.id_angajat
JOIN departamente d ON d.id_departament = a.id_departament
WHERE e.an_evaluare = 2025
GROUP BY d.nume_departament
ORDER BY d.nume_departament;
GO
