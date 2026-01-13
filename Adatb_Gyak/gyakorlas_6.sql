-- 1. FELADAT: SÉMA LÉTREHOZÁSA ÉS JOGOSULTSÁGOK
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_count
    FROM dba_users
   WHERE username = 'MAGAN_KLINIKA';
  IF v_count > 0
  THEN
    EXECUTE IMMEDIATE 'DROP USER MAGAN_KLINIKA CASCADE';
  END IF;
END;
/ 

CREATE USER magan_klinika identified BY "titkosKlinika123" DEFAULT tablespace users quota unlimited ON users;

grant CREATE session TO magan_klinika;
grant CREATE TABLE TO magan_klinika;
grant CREATE view TO magan_klinika;
grant CREATE sequence TO magan_klinika;
grant CREATE TRIGGER TO magan_klinika;
grant CREATE PROCEDURE TO magan_klinika;
grant CREATE TYPE TO magan_klinika;
grant CONNECT TO magan_klinika;
grant RESOURCE TO magan_klinika;
grant CREATE job TO magan_klinika;
grant manage scheduler TO magan_klinika;
/

---------------------------------------------------------
-- 2. és 3. FELADAT: TÁBLÁK, SZEKVENCIÁK, AUDIT
---------------------------------------------------------

--DROP (HA KELL): 
-- Táblák törlése
--DROP TABLE vizsgalat CASCADE CONSTRAINTS PURGE;
--DROP TABLE orvos CASCADE CONSTRAINTS PURGE;
--DROP TABLE paciens CASCADE CONSTRAINTS PURGE;

-- Szekvenciák törlése
--DROP SEQUENCE seq_vizsgalat;
--DROP SEQUENCE seq_orvos;
--DROP SEQUENCE seq_paciens;

-- Ha már volt history tábla is (5. feladat):
--DROP TABLE vizsgalat_ar_hist CASCADE CONSTRAINTS PURGE;


-- Szekvenciák (Előírt kezdőértékekkel)
CREATE SEQUENCE seq_orvos START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_paciens START WITH 1500 INCREMENT BY 1;
CREATE SEQUENCE seq_vizsgalat START WITH 1 INCREMENT BY 1;

-- 1. ORVOS TÁBLA
CREATE TABLE orvos (
    orvos_id NUMBER PRIMARY KEY,
    nev VARCHAR2(100) NOT NULL,
    pecsetszam VARCHAR2(20) UNIQUE NOT NULL,
    szakterulet VARCHAR2(50) NOT NULL,
    vizsgalati_dij NUMBER NOT NULL,
    -- Audit mezők
    letrehozva DATE,
    modositva DATE,
    modosito_felhasznalo VARCHAR2(100)
);

-- 2. PACIENS TÁBLA
CREATE TABLE paciens (
    paciens_id NUMBER PRIMARY KEY,
    nev VARCHAR2(100) NOT NULL,
    taj_szam VARCHAR2(9) UNIQUE NOT NULL,
    szuletesi_datum DATE NOT NULL,
    lakcim VARCHAR2(200) NOT NULL,
    letrehozva DATE,
    modositva DATE,
    modosito_felhasznalo VARCHAR2(100),
    CONSTRAINT chk_taj_hossz CHECK (LENGTH(taj_szam) = 9)
);

-- 3. VIZSGALAT TÁBLA
CREATE TABLE vizsgalat (
    id NUMBER PRIMARY KEY,
    orvos_id NUMBER NOT NULL,
    paciens_id NUMBER NOT NULL,
    vizsgalat_datum DATE NOT NULL,
    diagnozis VARCHAR2(500),
    fizetett_osszeg NUMBER,
    letrehozva DATE,
    modositva DATE,
    modosito_felhasznalo VARCHAR2(100),
    CONSTRAINT fk_vizsg_orvos FOREIGN KEY (orvos_id) REFERENCES orvos(orvos_id),
    CONSTRAINT fk_vizsg_paciens FOREIGN KEY (paciens_id) REFERENCES paciens(paciens_id),
    -- Egyedi kényszer: Orvos-Páciens-Dátum
    CONSTRAINT uq_orvos_paciens_datum UNIQUE (orvos_id, paciens_id, vizsgalat_datum)
);

-- AUDIT TRIGGEREK (ID generálás + Auditálás egyben)

-- Orvos Trigger
CREATE OR REPLACE TRIGGER trg_orvos_biu
BEFORE INSERT OR UPDATE ON orvos
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        -- Itt a változás: :NEW.id helyett :NEW.orvos_id
        IF :NEW.orvos_id IS NULL THEN
            :NEW.orvos_id := seq_orvos.NEXTVAL;
        END IF;
        :NEW.letrehozva := SYSDATE;
    END IF;
    :NEW.modositva := SYSDATE;
    :NEW.modosito_felhasznalo := USER;
END;
/

-- Paciens Trigger
CREATE OR REPLACE TRIGGER trg_paciens_biu
BEFORE INSERT OR UPDATE ON paciens
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        -- Itt a változás: :NEW.id helyett :NEW.paciens_id
        IF :NEW.paciens_id IS NULL THEN
            :NEW.paciens_id := seq_paciens.NEXTVAL;
        END IF;
        :NEW.letrehozva := SYSDATE;
    END IF;
    :NEW.modositva := SYSDATE;
    :NEW.modosito_felhasznalo := USER;
END;
/

-- Vizsgalat Trigger
CREATE OR REPLACE TRIGGER trg_vizsgalat_biu
BEFORE INSERT OR UPDATE ON vizsgalat
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        -- Ha a vizsgalat táblában maradt az "id", akkor ez így jó:
        IF :NEW.id IS NULL THEN
            :NEW.id := seq_vizsgalat.NEXTVAL;
        END IF;
        :NEW.letrehozva := SYSDATE;
    END IF;
    :NEW.modositva := SYSDATE;
    :NEW.modosito_felhasznalo := USER;
END;
/

---------------------------------------------------------
-- 4. FELADAT: RECEPCIÓS NÉZET (Adatvédelem)
---------------------------------------------------------
CREATE OR REPLACE VIEW vw_recepcio AS
SELECT
    p.nev AS paciens_nev,
    o.nev AS orvos_nev,
    v.vizsgalat_datum,
    -- TAJ maszkolás: csak az utolsó 3 látszik
    '******' || SUBSTR(p.taj_szam, -3) as taj_szam_rejtett,
    CASE 
        WHEN v.fizetett_osszeg IS NULL OR v.fizetett_osszeg = 0 THEN 'Térítésmentes'
        WHEN v.fizetett_osszeg BETWEEN 1 AND 50000 THEN 'Normál díjas'
        WHEN v.fizetett_osszeg > 50000 THEN 'Kiemelt díjas'
    END AS ar_kategoria
FROM vizsgalat v
JOIN orvos o ON v.orvos_id = o.orvos_id
JOIN paciens p ON v.paciens_id = p.paciens_id;
/

---------------------------------------------------------
-- 5. FELADAT: VIZSGÁLAT ÁR HISTORY ÉS TRIGGER
---------------------------------------------------------
CREATE TABLE vizsgalat_ar_hist (
    vizsgalat_id NUMBER,
    regi_ar NUMBER,
    uj_ar NUMBER,
    modositas_datum DATE
);

CREATE OR REPLACE TRIGGER trg_vizsgalat_ar_kovetes
BEFORE UPDATE OF fizetett_osszeg ON vizsgalat
FOR EACH ROW
BEGIN
    -- Csak akkor írunk, ha változott az érték
    IF (:OLD.fizetett_osszeg != :NEW.fizetett_osszeg) OR 
       (:OLD.fizetett_osszeg IS NULL AND :NEW.fizetett_osszeg IS NOT NULL) OR
       (:OLD.fizetett_osszeg IS NOT NULL AND :NEW.fizetett_osszeg IS NULL) 
    THEN
        INSERT INTO vizsgalat_ar_hist (vizsgalat_id, regi_ar, uj_ar, modositas_datum)
        VALUES (:OLD.id, :OLD.fizetett_osszeg, :NEW.fizetett_osszeg, SYSDATE);
    END IF;
END;
/

---------------------------------------------------------
-- 6. FELADAT: TRANZAKCIÓ, LOCK, SLEEP
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_orvos_alapdij_modosit(
    p_orvos_id IN NUMBER, 
    p_uj_dij IN NUMBER
) IS
    doctor_not_found_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(doctor_not_found_exc, -20001);
    v_dummy NUMBER;
BEGIN
    -- 1. Zárolás (Ha nincs ilyen ID, a NO_DATA_FOUND elkapja)
    BEGIN
        SELECT 1 INTO v_dummy FROM orvos WHERE id = p_orvos_id FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE doctor_not_found_exc;
    END;

    -- 2. Várakozás (5 mp)
    DBMS_LOCK.SLEEP(5); 
    ----ez a jó: DBMS_SESSION.SLEEP(5);

    -- 3. Módosítás
    UPDATE orvos SET alapdij = p_uj_dij WHERE id = p_orvos_id;

    -- Véglegesítés
    COMMIT;

EXCEPTION
    WHEN doctor_not_found_exc THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Az orvos nem található!');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Váratlan hiba: ' || SQLERRM);
END;
/

---------------------------------------------------------
-- 7. FELADAT: DINAMIKUS SQL (EXECUTE IMMEDIATE)
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_dinamikus_vizsgalat_szam(
    p_datum IN DATE,
    p_osszeghatar IN NUMBER,
    p_darab OUT NUMBER
) IS
    v_sql VARCHAR2(1000);
BEGIN
    v_sql := 'SELECT COUNT(*) FROM vizsgalat WHERE datum > :1 AND fizetett_osszeg > :2';
    EXECUTE IMMEDIATE v_sql INTO p_darab USING p_datum, p_osszeghatar;
END;
/

---------------------------------------------------------
-- 8. és 9. FELADAT: TÍPUSOK, LISTA ÉS UNIÓ
---------------------------------------------------------

-- Objektum típus
CREATE OR REPLACE TYPE ty_orvos_stat IS OBJECT (
    orvos_nev VARCHAR2(100),
    szakterulet VARCHAR2(50),
    osszes_bevetel NUMBER
);
/
-- Lista típus (Collection)
CREATE OR REPLACE TYPE ty_orvos_stat_list IS TABLE OF ty_orvos_stat;
/

-- Függvény
CREATE OR REPLACE FUNCTION fn_szakterulet_stat RETURN ty_orvos_stat_list IS
    v_belgyogyasz_lista ty_orvos_stat_list;
    v_sebesz_lista ty_orvos_stat_list;
    v_egyesitett_lista ty_orvos_stat_list;
BEGIN
    -- 1. Belgyógyászok
    SELECT ty_orvos_stat(o.nev, o.szakterulet, NVL(SUM(v.fizetett_osszeg), 0))
    BULK COLLECT INTO v_belgyogyasz_lista
    FROM orvos o
    LEFT JOIN vizsgalat v ON o.id = v.orvos_id
    WHERE o.szakterulet = 'Belgyógyász'
    GROUP BY o.nev, o.szakterulet;

    -- 2. Sebészek
    SELECT ty_orvos_stat(o.nev, o.szakterulet, NVL(SUM(v.fizetett_osszeg), 0))
    BULK COLLECT INTO v_sebesz_lista
    FROM orvos o
    LEFT JOIN vizsgalat v ON o.id = v.orvos_id
    WHERE o.szakterulet = 'Sebész'
    GROUP BY o.nev, o.szakterulet;

    -- 3. Egyesítés (Multiset Union)
    v_egyesitett_lista := v_belgyogyasz_lista MULTISET UNION ALL v_sebesz_lista;

    RETURN v_egyesitett_lista;
END;
/

---------------------------------------------------------
-- 10. FELADAT: NAPLÓZÁS ÉS JOB
---------------------------------------------------------

-- 1. Szekvencia létrehozása a loghoz
CREATE SEQUENCE seq_rendszer_log START WITH 1 INCREMENT BY 1;

-- 2. Tábla létrehozása (Sima NUMBER ID-vel)
CREATE TABLE rendszer_log (
    id NUMBER PRIMARY KEY,
    datum DATE DEFAULT SYSDATE,
    informacio VARCHAR2(2000)
);

-- 3. Trigger az ID generáláshoz
CREATE OR REPLACE TRIGGER trg_rendszer_log_bi
BEFORE INSERT ON rendszer_log
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := seq_rendszer_log.NEXTVAL;
    END IF;
END;
/

-- Naplózó eljárás
CREATE OR REPLACE PROCEDURE pr_rendszer_naplozas IS
    v_orvos_db NUMBER;
    v_paciens_db NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_orvos_db FROM orvos;
    SELECT COUNT(*) INTO v_paciens_db FROM paciens;
    
    INSERT INTO rendszer_log (informacio) 
    VALUES ('Rendszer állapot: ' || v_orvos_db || ' orvos, ' || v_paciens_db || ' páciens.');
    COMMIT;
END;
/

-- Job létrehozása
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_RENDSZER_NAPLO',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN pr_rendszer_naplozas; END;',
        start_date      => SYSDATE,
        repeat_interval => 'FREQ=HOURLY; INTERVAL=1',
        enabled         => TRUE
    );
END;
/

-- Job kézi futtatása (Teszt)
BEGIN
    DBMS_SCHEDULER.RUN_JOB('JOB_RENDSZER_NAPLO');
END;
/


--Törléshez:
--BEGIN
    --DBMS_SCHEDULER.DROP_JOB('JOB_RENDSZER_NAPLO');
--END;
--/

--Testhez:
--SELECT * FROM rendszer_log ORDER BY datum DESC;