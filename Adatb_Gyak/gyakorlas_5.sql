/* ======================================================
   1. FELADAT: FELHASZNÁLÓ LÉTREHOZÁSA
   (Ezt SYSTEM / Rendszergazda módban futtasd!)
   ====================================================== */
DECLARE
  v_count NUMBER;
BEGIN
  SELECT count(*) INTO v_count FROM dba_users WHERE username = 'SAJAT_WEBSHOP';
  IF v_count > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER SAJAT_WEBSHOP CASCADE';
  END IF;
END;
/

CREATE USER SAJAT_WEBSHOP IDENTIFIED BY "webshop_jelszo" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO SAJAT_WEBSHOP;
GRANT CREATE TABLE TO SAJAT_WEBSHOP;
GRANT CREATE VIEW TO SAJAT_WEBSHOP;
GRANT CREATE SEQUENCE TO SAJAT_WEBSHOP;
GRANT CREATE TRIGGER TO SAJAT_WEBSHOP;
GRANT CREATE PROCEDURE TO SAJAT_WEBSHOP;
GRANT CREATE TYPE TO SAJAT_WEBSHOP;

-- !!! MOST JELENTKEZZ ÁT A SAJAT_WEBSHOP FELHASZNÁLÓVAL !!! --

/* ======================================================
   2. FELADAT: TÁBLÁK LÉTREHOZÁSA
   (Innentől mindent SAJAT_WEBSHOP-ként futtass!)
   ====================================================== */

CREATE TABLE vevo (
    id NUMBER,
    nev VARCHAR2(100) NOT NULL,
    lakcim VARCHAR2(200) NOT NULL,
    email VARCHAR2(100) NOT NULL,
    telefonszam VARCHAR2(50) NOT NULL
);

CREATE TABLE termek (
    id NUMBER,
    megnevezes VARCHAR2(100) NOT NULL,
    kategoria VARCHAR2(100) NOT NULL, -- Fontos az inzertek és a 10-es feladat miatt!
    ar NUMBER(10, 2) NOT NULL,
    raktarkeszlet NUMBER NOT NULL
);

CREATE TABLE rendeles (
    id NUMBER,
    vevo_id NUMBER NOT NULL,
    rendeles_datum DATE NOT NULL,
    statusz VARCHAR2(50) NOT NULL
);

CREATE TABLE rendeles_tetel (
    id NUMBER,
    rendeles_id NUMBER NOT NULL,
    termek_id NUMBER NOT NULL,
    mennyiseg NUMBER NOT NULL,
    aktualis_ar NUMBER(10, 2) NOT NULL
);

/* ======================================================
   3. FELADAT: MEGSZORÍTÁSOK
   ====================================================== */

-- Primary Keys
ALTER TABLE vevo ADD CONSTRAINT pk_vevo PRIMARY KEY (id);
ALTER TABLE termek ADD CONSTRAINT pk_termek PRIMARY KEY (id);
ALTER TABLE rendeles ADD CONSTRAINT pk_rendeles PRIMARY KEY (id);
ALTER TABLE rendeles_tetel ADD CONSTRAINT pk_rendeles_tetel PRIMARY KEY (id);

-- Foreign Keys
ALTER TABLE rendeles ADD CONSTRAINT fk_rendeles_vevo 
FOREIGN KEY (vevo_id) REFERENCES vevo(id);

ALTER TABLE rendeles_tetel ADD CONSTRAINT fk_tetel_rendeles 
FOREIGN KEY (rendeles_id) REFERENCES rendeles(id);

ALTER TABLE rendeles_tetel ADD CONSTRAINT fk_tetel_termek 
FOREIGN KEY (termek_id) REFERENCES termek(id);

-- Unique Constraint (Egy rendelésben egy termék csak egyszer)
ALTER TABLE rendeles_tetel ADD CONSTRAINT uq_rendeles_termek 
UNIQUE (rendeles_id, termek_id);

/* ======================================================
   4. FELADAT: SZEKVENCIÁK ÉS TRIGGEREK
   (Fontos: WHEN (new.id is null), hogy az insert.sql lefusson!)
   ====================================================== */

-- VEVO (8000-től)
CREATE SEQUENCE seq_vevo START WITH 8000 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER trg_vevo_id
BEFORE INSERT ON vevo
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_vevo.NEXTVAL;
END;
/

-- TERMEK (12500-tól)
CREATE SEQUENCE seq_termek START WITH 12500 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER trg_termek_id
BEFORE INSERT ON termek
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_termek.NEXTVAL;
END;
/

-- RENDELES (35000-től)
CREATE SEQUENCE seq_rendeles START WITH 35000 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER trg_rendeles_id
BEFORE INSERT ON rendeles
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_rendeles.NEXTVAL;
END;
/

-- RENDELES_TETEL (10-től)
CREATE SEQUENCE seq_rendeles_tetel START WITH 10 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER trg_rendeles_tetel_id
BEFORE INSERT ON rendeles_tetel
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
    :NEW.id := seq_rendeles_tetel.NEXTVAL;
END;
/

/* ======================================================
   ADATBETÖLTÉS (INSERT.SQL)
   ====================================================== */

INSERT INTO vevo (id, nev, lakcim, email, telefonszam) VALUES (1, 'Kovács János', '1052 Budapest, Deák tér 1.', 'kovacs.j@email.com', '+362012345678');
INSERT INTO vevo (id, nev, lakcim, email, telefonszam) VALUES (2, 'Nagy Anna', '6720 Szeged, Dóm tér 5.', 'anna.nagy@email.hu', '+362012345679');
INSERT INTO vevo (id, nev, lakcim, email, telefonszam) VALUES (3, 'Szabó Péter', '4025 Debrecen, Piac u. 10.', 'szabo.peti@email.hu', '+362012345610');
INSERT INTO vevo (id, nev, lakcim, email, telefonszam) VALUES (4, 'Tóth Éva', '9021 Győr, Baross út 22.', 'eva.toth@email.com', '+362012345611');

INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet) VALUES (101, 'Gamer Laptop X200', 'Elektronika', 450000.00, 5);
INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet) VALUES (102, 'Vezeték nélküli Egér', 'Elektronika', 12000.00, 50);
INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet) VALUES (103, 'SQL Mesterkurzus Könyv', 'Könyv', 8500.00, 100);
INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet) VALUES (104, 'Harry Potter Díszkiadás', 'Könyv', 15000.00, 20);
INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet) VALUES (105, 'Eszpresszó Kávéfőző', 'Konyha', 35000.00, 10);
INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet) VALUES (106, 'Okos Hűtőszekrény', 'Konyha', 250000.00, 2);

INSERT INTO rendeles (id, vevo_id, rendeles_datum, statusz) VALUES (1001, 1, TO_DATE('2023-01-15', 'YYYY-MM-DD'), 'Kiszállítva');
INSERT INTO rendeles (id, vevo_id, rendeles_datum, statusz) VALUES (1002, 2, TO_DATE('2023-02-10', 'YYYY-MM-DD'), 'Kiszállítva');
INSERT INTO rendeles (id, vevo_id, rendeles_datum, statusz) VALUES (1003, 1, TO_DATE('2023-03-05', 'YYYY-MM-DD'), 'Kiszállítva');
INSERT INTO rendeles (id, vevo_id, rendeles_datum, statusz) VALUES (1004, 3, TO_DATE('2023-05-20', 'YYYY-MM-DD'), 'Törölve');
INSERT INTO rendeles (id, vevo_id, rendeles_datum, statusz) VALUES (1005, 1, TO_DATE('2023-06-12', 'YYYY-MM-DD'), 'Feldolgozás alatt');
INSERT INTO rendeles (id, vevo_id, rendeles_datum, statusz) VALUES (1006, 4, TO_DATE('2023-06-12', 'YYYY-MM-DD'), 'Feldolgozás alatt');

INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (1, 1001, 101, 1, 450000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (2, 1001, 102, 1, 12000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (3, 1001, 103, 2, 8500.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (4, 1002, 105, 1, 35000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (5, 1003, 102, 2, 11000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (6, 1003, 106, 1, 250000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (7, 1004, 101, 1, 460000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (8, 1005, 104, 1, 15000.00);
INSERT INTO rendeles_tetel (id, rendeles_id, termek_id, mennyiseg, aktualis_ar) VALUES (9, 1006, 103, 1, 8500.00);

COMMIT;

/* ======================================================
   5. FELADAT: NÉZET (VIEW)
   ====================================================== */

CREATE OR REPLACE VIEW vw_vasarloi_szokasok AS
SELECT 
    v.nev AS vasarlo_neve,
    r.rendeles_datum,
    LISTAGG(t.megnevezes, ', ') WITHIN GROUP (ORDER BY t.megnevezes) AS termekek,
    SUM(rt.mennyiseg * rt.aktualis_ar) AS vegosszeg
FROM vevo v
JOIN rendeles r ON v.id = r.vevo_id
JOIN rendeles_tetel rt ON r.id = rt.rendeles_id
JOIN termek t ON rt.termek_id = t.id
GROUP BY v.nev, r.rendeles_datum;
/

/* ======================================================
   6. FELADAT ELŐKÉSZÍTÉSE (SEGED.SQL)
   ====================================================== */

CREATE TABLE beszallito_frissites (
    termek_id NUMBER,
    megnevezes VARCHAR2(100),
    kategoria VARCHAR2(50),
    uj_ar NUMBER(10, 2),
    szallitott_mennyiseg NUMBER
);

INSERT INTO beszallito_frissites (termek_id, megnevezes, kategoria, uj_ar, szallitott_mennyiseg) VALUES (102, 'Vezeték nélküli Egér (2023)', 'Elektronika', 11500, 20);
INSERT INTO beszallito_frissites (termek_id, megnevezes, kategoria, uj_ar, szallitott_mennyiseg) VALUES (106, 'Okos Hűtőszekrény', 'Konyha', 240000, 5);
INSERT INTO beszallito_frissites (termek_id, megnevezes, kategoria, uj_ar, szallitott_mennyiseg) VALUES (107, 'Tablet Pro 10"', 'Elektronika', 120000, 15);
COMMIT;

/* ======================================================
   6. FELADAT: KARBANTARTÁS ELJÁRÁS
   ====================================================== */

CREATE OR REPLACE PROCEDURE pr_termek_karbantartas IS
    migration_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(migration_exc, -20001);
    v_count NUMBER;
BEGIN
    FOR rec IN (SELECT * FROM beszallito_frissites) LOOP
        BEGIN
            SELECT COUNT(*) INTO v_count FROM termek WHERE id = rec.termek_id;
            
            IF v_count > 0 THEN
                UPDATE termek
                SET megnevezes = rec.megnevezes,
                    kategoria = rec.kategoria,
                    ar = rec.uj_ar,
                    raktarkeszlet = raktarkeszlet + rec.szallitott_mennyiseg
                WHERE id = rec.termek_id;
            ELSE
                INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet)
                VALUES (rec.termek_id, rec.megnevezes, rec.kategoria, rec.uj_ar, rec.szallitott_mennyiseg);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE migration_exc;
        END;
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN migration_exc THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Hiba történt a migráció során!');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Váratlan hiba: ' || SQLERRM);
END;
/

/* ======================================================
   7. FELADAT: BIZTONSÁGOS BESZÚRÁS (PACKAGE + TRIGGER)
   ====================================================== */

-- 1. Csomag
CREATE OR REPLACE PACKAGE pkg_termek_security IS
    g_allowed BOOLEAN := FALSE;
    cannot_insert_product_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(cannot_insert_product_exc, -20003);
END;
/

-- 2. Trigger
CREATE OR REPLACE TRIGGER trg_block_termek_insert
BEFORE INSERT ON termek
BEGIN
    IF NOT pkg_termek_security.g_allowed THEN
        RAISE_APPLICATION_ERROR(-20003, 'Terméket csak a hivatalos eljáráson keresztül lehet rögzíteni!');
    END IF;
END;
/

-- 3. Eljárás
CREATE OR REPLACE PROCEDURE pr_uj_termek_rogzitese(
    p_megnevezes IN VARCHAR2,
    p_kategoria IN VARCHAR2,
    p_ar IN NUMBER,
    p_keszlet IN NUMBER
) IS
BEGIN
    pkg_termek_security.g_allowed := TRUE; -- Kapu nyitás
    
    INSERT INTO termek (megnevezes, kategoria, ar, raktarkeszlet)
    VALUES (p_megnevezes, p_kategoria, p_ar, p_keszlet);
    
    pkg_termek_security.g_allowed := FALSE; -- Kapu zárás
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        pkg_termek_security.g_allowed := FALSE;
        RAISE;
END;
/

/* ======================================================
   8. FELADAT: LEGJOBB VEVŐ ELJÁRÁS
   ====================================================== */

CREATE OR REPLACE PROCEDURE pr_legjobb_vevo(p_termek_id IN NUMBER, p_vevo_nev OUT VARCHAR2) IS
    product_not_found_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(product_not_found_exc, -20004);
    v_check NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_check FROM termek WHERE id = p_termek_id;
    IF v_check = 0 THEN
        RAISE product_not_found_exc;
    END IF;

    SELECT v.nev
    INTO p_vevo_nev
    FROM vevo v
    JOIN rendeles r ON v.id = r.vevo_id
    JOIN rendeles_tetel rt ON r.id = rt.rendeles_id
    WHERE rt.termek_id = p_termek_id
    GROUP BY v.nev
    ORDER BY SUM(rt.mennyiseg) DESC
    FETCH FIRST 1 ROWS ONLY;

EXCEPTION
    WHEN product_not_found_exc THEN
        RAISE_APPLICATION_ERROR(-20004, 'A megadott termék azonosító nem létezik!');
    WHEN NO_DATA_FOUND THEN
        p_vevo_nev := 'Még senki nem vásárolt ebből a termékből.';
END;
/

/* ======================================================
   9. FELADAT: TÍPUSOK (OBJECT és TABLE)
   ====================================================== */

CREATE OR REPLACE TYPE ty_termek_stat IS OBJECT (
    termek_nev VARCHAR2(100),
    eladott_db NUMBER,
    bevetel NUMBER
);
/

CREATE OR REPLACE TYPE ty_termek_stat_list IS TABLE OF ty_termek_stat;
/

/* ======================================================
   10. FELADAT: STATISZTIKA FÜGGVÉNY
   ====================================================== */

CREATE OR REPLACE FUNCTION fn_kategoria_stat(p_kategoria IN VARCHAR2) 
RETURN ty_termek_stat_list IS
    v_result ty_termek_stat_list;
BEGIN
    SELECT ty_termek_stat(
        t.megnevezes,
        NVL(SUM(rt.mennyiseg), 0),
        NVL(SUM(rt.mennyiseg * rt.aktualis_ar), 0)
    )
    BULK COLLECT INTO v_result
    FROM termek t
    LEFT JOIN rendeles_tetel rt ON t.id = rt.termek_id
    WHERE t.kategoria = p_kategoria
    GROUP BY t.megnevezes;

    RETURN v_result;
END;
/

/* ======================================================
   11. FELADAT: TESZT FUTTATÁS (ANONYMOUS BLOCK)
   ====================================================== */
DECLARE
    v_lista ty_termek_stat_list;
BEGIN
    -- Teszteljük az 'Elektronika' kategóriával
    v_lista := fn_kategoria_stat('Elektronika');
    
    DBMS_OUTPUT.PUT_LINE('--- Elektronika Statisztika ---');
    
    IF v_lista.COUNT > 0 THEN
        FOR i IN 1..v_lista.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Termék: ' || v_lista(i).termek_nev || 
                                 ' | Eladott db: ' || v_lista(i).eladott_db || 
                                 ' | Bevétel: ' || v_lista(i).bevetel);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Nincs adat ebben a kategóriában.');
    END IF;
END;
/