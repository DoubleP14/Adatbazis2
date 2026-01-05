-- 1. feladat
DECLARE
  v_count NUMBER;
BEGIN
  SELECT count(*) INTO v_count FROM dba_users WHERE username = 'EPITESI_VALLAKOZAS';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER EPITESI_VALLAKOZAS CASCADE';
  END IF;
END;
/

CREATE USER EPITESI_VALLAKOZAS IDENTIFIED BY "szuperVallalkozas" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO EPITESI_VALLAKOZAS;
GRANT CREATE TABLE TO EPITESI_VALLAKOZAS;
GRANT CREATE VIEW TO EPITESI_VALLAKOZAS;
GRANT CREATE SEQUENCE TO EPITESI_VALLAKOZAS;
GRANT CREATE TRIGGER TO EPITESI_VALLAKOZAS;
GRANT CREATE PROCEDURE TO EPITESI_VALLAKOZAS;
GRANT CREATE TYPE TO EPITESI_VALLAKOZAS;

--kell elvileg:ALTER SESSION SET current_schema = EPITESI_VALLAKOZAS;
-- FONTOS: Mostantól jelentkezz át az EPITESI_VALLAKOZAS felhasználóval!

-- 2. és 3. Feladat: Táblák létrehozása
CREATE TABLE brigad (
    id NUMBER PRIMARY KEY,
    nev VARCHAR2(100) NOT NULL,
    vezeto_neve VARCHAR2(100) NOT NULL,
    meret NUMBER NOT NULL
);

CREATE TABLE megrendelo (
    id NUMBER PRIMARY KEY,
    nev VARCHAR2(100) NOT NULL,
    szamlazasi_cim VARCHAR2(200) NOT NULL,
    telefonszam VARCHAR2(50) NOT NULL,
    emailcim VARCHAR2(100) NOT NULL
);

CREATE TABLE projekt (
    id NUMBER PRIMARY KEY,
    megrendelo_id NUMBER NOT NULL REFERENCES megrendelo(id),
    munkavegzes_cime VARCHAR2(200) NOT NULL,
    statusz VARCHAR2(50) NOT NULL,
    koltseg NUMBER NOT NULL
);

CREATE TABLE projekt_brigad (
    id NUMBER PRIMARY KEY,
    projekt_id NUMBER NOT NULL REFERENCES projekt(id),
    brigad_id NUMBER NOT NULL REFERENCES brigad(id),
    tervezett_kezdodatum DATE NOT NULL,
    tervezett_vegdatum DATE NOT NULL,
    CONSTRAINT uq_projekt_brigad UNIQUE (projekt_id, brigad_id)
);

-- 4. Feladat: Szekvenciák és Triggerek az automatikus azonosítókhoz

-- Brigád: 13500-tól
CREATE SEQUENCE seq_brigad START WITH 13500;

CREATE OR REPLACE TRIGGER trg_brigad_id
BEFORE INSERT ON brigad
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_brigad.NEXTVAL;
END;
/

-- Megrendelő: 34600-tól
CREATE SEQUENCE seq_megrendelo START WITH 34600;

CREATE OR REPLACE TRIGGER trg_megrendelo_id
BEFORE INSERT ON megrendelo
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_megrendelo.NEXTVAL;
END;
/

-- Projekt: 150000-től
CREATE SEQUENCE seq_projekt START WITH 150000;

CREATE OR REPLACE TRIGGER trg_projekt_id
BEFORE INSERT ON projekt
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_projekt.NEXTVAL;
END;
/

-- Projekt-Brigád: 1-től
CREATE SEQUENCE seq_projekt_brigad START WITH 1;

CREATE OR REPLACE TRIGGER trg_projekt_brigad_id
BEFORE INSERT ON projekt_brigad
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_projekt_brigad.NEXTVAL;
END;
/

-- 5. Feladat: Adatok feltöltése (min. 4 rekord táblánként)

-- Brigádok
INSERT INTO brigad (nev, vezeto_neve, meret) VALUES ('Alpha Brigád', 'Kovács János', 5);
INSERT INTO brigad (nev, vezeto_neve, meret) VALUES ('Beta Építők', 'Szabó Péter', 8);
INSERT INTO brigad (nev, vezeto_neve, meret) VALUES ('Gamma Tetőfedők', 'Nagy István', 4);
INSERT INTO brigad (nev, vezeto_neve, meret) VALUES ('Delta Villanyszerelők', 'Tóth Gábor', 3);

-- Megrendelők
INSERT INTO megrendelo (nev, szamlazasi_cim, telefonszam, emailcim) VALUES ('Kiss Anna', '1111 Budapest, Fő u. 1.', '06201111111', 'kiss.anna@mail.hu');
INSERT INTO megrendelo (nev, szamlazasi_cim, telefonszam, emailcim) VALUES ('Nagy Zrt.', '2222 Pécs, Rákóczi út 10.', '06302222222', 'info@nagyzrt.hu');
INSERT INTO megrendelo (nev, szamlazasi_cim, telefonszam, emailcim) VALUES ('Társasház Kft.', '3333 Szeged, Tisza L. krt. 5.', '06703333333', 'office@tarsashaz.hu');
INSERT INTO megrendelo (nev, szamlazasi_cim, telefonszam, emailcim) VALUES ('Horváth Éva', '4444 Debrecen, Piac u. 20.', '06204444444', 'horvath.eva@mail.hu');

-- Projektek
-- ID-k generálódnak, de a hivatkozásokhoz tudnunk kell őket. 
-- A szekvenciák miatt az ID-k: Megrendelő: 34600, 34601, 34602, 34603
INSERT INTO projekt (megrendelo_id, munkavegzes_cime, statusz, koltseg) VALUES (34600, 'Budapest, Fő u. 1.', 'Kész', 1000000);
INSERT INTO projekt (megrendelo_id, munkavegzes_cime, statusz, koltseg) VALUES (34601, 'Pécs, Rákóczi út 10.', 'Folyamatban', 5000000);
INSERT INTO projekt (megrendelo_id, munkavegzes_cime, statusz, koltseg) VALUES (34601, 'Pécs, Rákóczi út 12.', 'Tervezés', 2000000);
INSERT INTO projekt (megrendelo_id, munkavegzes_cime, statusz, koltseg) VALUES (34602, 'Szeged, Tisza L. krt. 5.', 'Kész', 3500000);
INSERT INTO projekt (megrendelo_id, munkavegzes_cime, statusz, koltseg) VALUES (34603, 'Debrecen, Piac u. 20.', 'Folyamatban', 1500000);

-- Projekt-Brigád kapcsolatok
-- Projekt ID-k: 150000, 150001, 150002, 150003, 150004
-- Brigád ID-k: 13500, 13501, 13502, 13503
INSERT INTO projekt_brigad (projekt_id, brigad_id, tervezett_kezdodatum, tervezett_vegdatum) VALUES (150000, 13500, TO_DATE('2023-01-01','YYYY-MM-DD'), TO_DATE('2023-02-01','YYYY-MM-DD'));
INSERT INTO projekt_brigad (projekt_id, brigad_id, tervezett_kezdodatum, tervezett_vegdatum) VALUES (150001, 13501, TO_DATE('2023-03-01','YYYY-MM-DD'), TO_DATE('2023-06-01','YYYY-MM-DD'));
INSERT INTO projekt_brigad (projekt_id, brigad_id, tervezett_kezdodatum, tervezett_vegdatum) VALUES (150002, 13501, TO_DATE('2023-07-01','YYYY-MM-DD'), TO_DATE('2023-08-01','YYYY-MM-DD'));
INSERT INTO projekt_brigad (projekt_id, brigad_id, tervezett_kezdodatum, tervezett_vegdatum) VALUES (150003, 13502, TO_DATE('2023-02-15','YYYY-MM-DD'), TO_DATE('2023-04-15','YYYY-MM-DD'));
INSERT INTO projekt_brigad (projekt_id, brigad_id, tervezett_kezdodatum, tervezett_vegdatum) VALUES (150004, 13503, TO_DATE('2023-05-01','YYYY-MM-DD'), TO_DATE('2023-05-20','YYYY-MM-DD'));

COMMIT;

--6.feladat
CREATE OR REPLACE VIEW vw_brigad_munka AS
SELECT 
    b.nev AS brigad_nev,
    b.vezeto_neve,
    m.nev AS megrendelo_nev,
    m.telefonszam,
    m.emailcim,
    -- Összes projekt száma az adott brigádnak az adott megrendelőnél:
    COUNT(p.id) OVER (PARTITION BY b.id, m.id) AS osszes_projekt_szama,
    -- Hányadik munka (időrendben kezdődátum szerint):
    ROW_NUMBER() OVER (PARTITION BY b.id, m.id ORDER BY pb.tervezett_kezdodatum) AS munka_sorszama
FROM 
    brigad b
JOIN 
    projekt_brigad pb ON b.id = pb.brigad_id
JOIN 
    projekt p ON pb.projekt_id = p.id
JOIN 
    megrendelo m ON p.megrendelo_id = m.id;

--7.feldadat
CREATE OR REPLACE PROCEDURE pr_legjobb_megrendelo(p_brigad_id IN NUMBER) IS
    v_megrendelo_nev megrendelo.nev%TYPE;
    v_egy_fore_juto NUMBER;
    v_count NUMBER;
    
    -- Saját kivétel definiálása
    crew_not_found_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(crew_not_found_exc, -20001);
BEGIN
    -- Ellenőrizzük, létezik-e a brigád
    SELECT count(*) INTO v_count FROM brigad WHERE id = p_brigad_id;
    IF v_count = 0 THEN
        RAISE crew_not_found_exc;
    END IF;

    -- Lekérdezés
    SELECT m.nev
    INTO v_megrendelo_nev
    FROM megrendelo m
    JOIN projekt p ON m.id = p.megrendelo_id
    JOIN projekt_brigad pb ON p.id = pb.projekt_id
    JOIN brigad b ON pb.brigad_id = b.id
    WHERE b.id = p_brigad_id
    GROUP BY m.id, m.nev, b.meret
    ORDER BY (SUM(p.koltseg) / b.meret) DESC
    FETCH FIRST 1 ROW ONLY;

    DBMS_OUTPUT.PUT_LINE('Legjobb megrendelő: ' || v_megrendelo_nev);

EXCEPTION
    WHEN crew_not_found_exc THEN
        DBMS_OUTPUT.PUT_LINE('Hiba: A megadott brigád azonosító nem létezik.');
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('A brigádnak még nincs projektje.');
END;
/

--8.feladat
CREATE OR REPLACE PROCEDURE pr_megrendelo_stat(p_megrendelo_id IN NUMBER) IS
    v_projekt_db NUMBER;
    v_osszkoltseg NUMBER;
    v_count NUMBER;
    
    client_not_found_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(client_not_found_exc, -20002);
BEGIN
    -- Ellenőrzés
    SELECT count(*) INTO v_count FROM megrendelo WHERE id = p_megrendelo_id;
    IF v_count = 0 THEN
        RAISE client_not_found_exc;
    END IF;

    -- Számítás
    SELECT COUNT(id), NVL(SUM(koltseg), 0)
    INTO v_projekt_db, v_osszkoltseg
    FROM projekt
    WHERE megrendelo_id = p_megrendelo_id;

    DBMS_OUTPUT.PUT_LINE('Projektek száma: ' || v_projekt_db);
    DBMS_OUTPUT.PUT_LINE('Összköltség: ' || v_osszkoltseg);

EXCEPTION
    WHEN client_not_found_exc THEN
        DBMS_OUTPUT.PUT_LINE('Hiba: A megadott megrendelő azonosító nem létezik.');
END;
/

--9.feladat
CREATE OR REPLACE PROCEDURE pr_brigad_hozzarendel(
    p_brigad_id IN NUMBER, 
    p_projekt_id IN NUMBER, 
    p_kezdodatum IN DATE, 
    p_vegdatum IN DATE
) IS
    v_atfedes_szam NUMBER; -- Ékezet javítva
    
    crew_booked_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(crew_booked_exc, -20003);
BEGIN
    -- 1. Átfedés ellenőrzése (Logikád tökéletes volt!)
    SELECT COUNT(*)
    INTO v_atfedes_szam
    FROM projekt_brigad
    WHERE brigad_id = p_brigad_id
    AND tervezett_kezdodatum <= p_vegdatum 
    AND tervezett_vegdatum >= p_kezdodatum;

    -- 2. Döntés
    IF v_atfedes_szam > 0 THEN
        RAISE crew_booked_exc; -- Itt eldobjuk a hibát
    ELSE
        -- 3. Beszúrás
        INSERT INTO projekt_brigad (projekt_id, brigad_id, tervezett_kezdodatum, tervezett_vegdatum)
        VALUES (p_projekt_id, p_brigad_id, p_kezdodatum, p_vegdatum);
        
        -- 4. COMMIT KÖTELEZŐ! (Mert módosítasz adatot)
        COMMIT; 
        
        DBMS_OUTPUT.PUT_LINE('Sikeres hozzárendelés.');
    END IF;

EXCEPTION
    WHEN crew_booked_exc THEN
        ROLLBACK; -- Ha már módosítottál volna valamit, visszavonja
        -- FONTOS: Nem csak kiírjuk, hanem DOBJUK a hibát, hogy az auditáló lássa!
        RAISE_APPLICATION_ERROR(-20003, 'HIBA: A brigád ebben az időszakban már foglalt!');
        
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20004, 'Váratlan hiba: ' || SQLERRM);
END;
/

--10.feladat
CREATE OR REPLACE TYPE ty_brigad_stat IS OBJECT (
    brigad_nev VARCHAR2(100),
    megrendelo_nev VARCHAR2(100),
    elvagzett_munkak_szama NUMBER,
    legkorabbi_munka DATE,
    legutolso_munka DATE
);
/

CREATE OR REPLACE TYPE ty_brigad_stat_list IS TABLE OF ty_brigad_stat;
/

--11.feladat
CREATE OR REPLACE FUNCTION fn_brigad_lista RETURN ty_brigad_stat_list IS
    v_lista ty_brigad_stat_list;
BEGIN
    SELECT ty_brigad_stat(
        b.nev,
        m.nev,
        COUNT(p.id),
        MIN(pb.tervezett_kezdodatum),
        MAX(pb.tervezett_vegdatum)
    )
    BULK COLLECT INTO v_lista
    FROM brigad b
    JOIN projekt_brigad pb ON b.id = pb.brigad_id
    JOIN projekt p ON pb.projekt_id = p.id
    JOIN megrendelo m ON p.megrendelo_id = m.id
    GROUP BY b.nev, m.nev;

    RETURN v_lista;
END;
/

--12.feladat
DECLARE
    v_eredmeny ty_brigad_stat_list;
BEGIN
    v_eredmeny := fn_brigad_lista();
    
    IF v_eredmeny.COUNT > 0 THEN
        FOR i IN 1..v_eredmeny.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('--------------------------------');
            DBMS_OUTPUT.PUT_LINE('Brigád: ' || v_eredmeny(i).brigad_nev);
            DBMS_OUTPUT.PUT_LINE('Megrendelő: ' || v_eredmeny(i).megrendelo_nev);
            DBMS_OUTPUT.PUT_LINE('Munkák száma: ' || v_eredmeny(i).elvagzett_munkak_szama);
            DBMS_OUTPUT.PUT_LINE('Első: ' || TO_CHAR(v_eredmeny(i).legkorabbi_munka, 'YYYY.MM.DD'));
            DBMS_OUTPUT.PUT_LINE('Utolsó: ' || TO_CHAR(v_eredmeny(i).legutolso_munka, 'YYYY.MM.DD'));
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Nincs adat.');
    END IF;
END;
/