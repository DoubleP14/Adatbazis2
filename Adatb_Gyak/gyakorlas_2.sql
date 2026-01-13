--1
-- itt is jobb lenne a t nelkulit használni
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_count
    FROM dba_users t
   WHERE t.username = 'jarmu_nyilvantarto';

  IF v_count = 1
  THEN
    EXECUTE IMMEDIATE 'drop user jarmu_nyilvantarto cascade';
  END IF;
END;
/ 
CREATE USER jarmu_nyilvantarto identified BY 12345678 DEFAULT tablespace users quota unlimited ON users;

grant CREATE session TO jarmu_nyilvantarto;
grant CREATE TABLE TO jarmu_nyilvantarto;
grant CREATE view TO jarmu_nyilvantarto;
grant CREATE TRIGGER TO jarmu_nyilvantarto;
grant CREATE sequence TO jarmu_nyilvantarto;
grant CREATE TYPE TO jarmu_nyilvantarto;
grant CREATE PROCEDURE TO jarmu_nyilvantarto;

ALTER session SET current_schema = jarmu_nyilvantarto;
/
--2
create sequence kereskedes_seq start with 15400 increment by 1;
create sequence jarmu_seq start with 5000 increment by 1;
create sequence kereskedes_jarmu_seq start with 100000 increment by 1;
/
--3
create table kereskedes(
id number constraint kereskedes_pk primary key,
nev varchar2(250) not null,
cim varchar2(500) not null
);

create table jarmu(
id number constraint jarmu_pk primary key,
marka varchar2(250) not null,
tipus varchar2(250) not null,
leiras varchar2(4000)
);

create table kereskedes_jarmu(
id number constraint kereskedes_jarmu_pk primary key,
kereskedes_id number constraint kereskedes_id_fk references kereskedes(id),
jarmu_id number constraint jarmu_id_fk references jarmu(id),
ar number not null,
darabszam number not null,

constraint uq_kereskedes_jarmu unique (kereskedes_id, jarmu_id) 
);
/

--szebbikre példa: 
CREATE TABLE kereskedes_jarmu (
    -- Elsődleges kulcs
    id             NUMBER CONSTRAINT kereskedes_jarmu_pk PRIMARY KEY,

    -- Idegen kulcsok (A sorrend fontos a szépséghez: NOT NULL -> CONSTRAINT -> REFERENCES)
    kereskedes_id  NUMBER NOT NULL CONSTRAINT kj_kereskedes_fk REFERENCES kereskedes(id),
    jarmu_id       NUMBER NOT NULL CONSTRAINT kj_jarmu_fk      REFERENCES jarmu(id),

    -- Adatok
    ar             NUMBER NOT NULL,
    darabszam      NUMBER NOT NULL,

    -- Összetett egyedi kulcs (Tábla szinten, a végén)
    CONSTRAINT uq_kereskedes_jarmu UNIQUE (kereskedes_id, jarmu_id)
);
/
--4
CREATE OR REPLACE TRIGGER trg_kereskedes
  BEFORE INSERT ON kereskedes
  FOR EACH ROW
  WHEN (new.id IS NULL)
BEGIN
  
  :new.id := kereskedes_seq.nextval;

END trg_kereskedes;
/
CREATE OR REPLACE TRIGGER trg_jarmu
  BEFORE INSERT ON jarmu
  FOR EACH ROW
  WHEN (new.id IS NULL)
BEGIN
  
  :new.id := jarmu_seq.nextval;

END trg_jarmu;
/
CREATE OR REPLACE TRIGGER trg_kereskedes_jarmu
  BEFORE INSERT ON kereskedes_jarmu
  FOR EACH ROW
  WHEN (new.id IS NULL)
BEGIN
  
  :new.id := kereskedes_jarmu_seq.nextval;

END trg_kereskedes_jarmu;
/
--5
create or replace view vw_lekerdezes as
SELECT j.marka AS jarmu_marka
      ,j.tipus AS jarmu_tipus
      ,k.nev AS kereskedes_nev
      ,kj.ar AS ar
      ,(SELECT MIN(kj_inner.ar)
         FROM kereskedes_jarmu kj_inner
        WHERE kj_inner.jarmu_id = j.id) as legkisebb_ar
  FROM jarmu j
  JOIN kereskedes_jarmu kj
    ON j.id = kj.jarmu_id
  JOIN kereskedes k
    ON kj.kereskedes_id = k.id;
/
--masik megoldas: 
CREATE OR REPLACE VIEW vw_lekerdezes AS
SELECT j.marka AS jarmu_marka
      ,j.tipus AS jarmu_tipus
      ,k.nev AS kereskedes_nev
      ,kj.ar AS ar
      -- Itt a csere: Egy sorban elintézed, alkérdés nélkül!
      ,MIN(kj.ar) OVER (PARTITION BY j.id) as legkisebb_ar
  FROM jarmu j
  JOIN kereskedes_jarmu kj
    ON j.id = kj.jarmu_id
  JOIN kereskedes k
    ON kj.kereskedes_id = k.id;
/
--6
CREATE OR REPLACE PACKAGE pkg_jarmu IS

  -- 1. Függvény
  FUNCTION get_darabszam(p_jarmu_id      IN NUMBER
                        ,p_kereskedes_id IN NUMBER) RETURN NUMBER;

  -- 2. Eljárás (Legolcsóbb keresés)
  PROCEDURE legolcsobb_kereskedes(p_jarmu_marka    IN VARCHAR2
                                 ,p_jarmu_tipus    IN VARCHAR2
                                 ,p_kereskedes_nev OUT VARCHAR2
                                 ,p_kereskedes_cim OUT VARCHAR2);

  -- 3. Eljárás (Készlet feltöltés)
  PROCEDURE keszlet_feltoltes(p_kereskedes_id IN NUMBER
                             ,p_jarmu_id      IN NUMBER
                             ,p_keszlet       IN NUMBER);

  -- Kivételek definíciója a leírás szerint
  jarmu_nem_forgalmazott_exc EXCEPTION;
  PRAGMA EXCEPTION_INIT(jarmu_nem_forgalmazott_exc, -20100);

  kereskedes_nem_talalhato_exc EXCEPTION;
  PRAGMA EXCEPTION_INIT(kereskedes_nem_talalhato_exc, -20101);

  hibas_adat_exc EXCEPTION;
  PRAGMA EXCEPTION_INIT(hibas_adat_exc, -20102);

END pkg_jarmu;
/
CREATE OR REPLACE PACKAGE BODY pkg_jarmu IS

  -- 1. GET_DARABSZAM
  FUNCTION get_darabszam(p_jarmu_id      IN NUMBER
                        ,p_kereskedes_id IN NUMBER) RETURN NUMBER IS
    v_darabszam_count NUMBER;
  BEGIN
    SELECT kj.darabszam
      INTO v_darabszam_count
      FROM kereskedes_jarmu kj
     WHERE kj.jarmu_id = p_jarmu_id
       AND kj.kereskedes_id = p_kereskedes_id;
  
    RETURN v_darabszam_count;
  
  EXCEPTION
    -- Ha nincs találat, dobjuk a kért kivételt (-20100)
    WHEN no_data_found THEN
      RAISE jarmu_nem_forgalmazott_exc;
  END get_darabszam;


  -- 2. LEGOLCSOBB_KERESKEDES
  PROCEDURE legolcsobb_kereskedes(p_jarmu_marka    IN VARCHAR2
                                 ,p_jarmu_tipus    IN VARCHAR2
                                 ,p_kereskedes_nev OUT VARCHAR2
                                 ,p_kereskedes_cim OUT VARCHAR2) IS
  BEGIN
    SELECT nev
          ,cim
      INTO p_kereskedes_nev
          ,p_kereskedes_cim
      FROM (SELECT k.nev
                  ,k.cim
                  ,kj.ar
              FROM kereskedes k
              JOIN kereskedes_jarmu kj ON k.id = kj.kereskedes_id
              JOIN jarmu j ON j.id = kj.jarmu_id
             -- Szövegrészlet keresés (LIKE) és kis/nagybetű függetlenség (UPPER)
             WHERE upper(j.marka) LIKE upper('%' || p_jarmu_marka || '%')
               AND upper(j.tipus) LIKE upper('%' || p_jarmu_tipus || '%')
             ORDER BY kj.ar ASC) -- Ár szerint rendezve, a legolcsóbb elöl
     WHERE rownum = 1; -- Csak az elsőt vesszük
  
  EXCEPTION
    -- Ha a lista üres, dobjuk a kért kivételt (-20101)
    WHEN no_data_found THEN
      RAISE kereskedes_nem_talalhato_exc;
  END legolcsobb_kereskedes;


  -- 3. KESZLET_FELTOLTES (Javított!)
  PROCEDURE keszlet_feltoltes(p_kereskedes_id IN NUMBER
                             ,p_jarmu_id      IN NUMBER
                             ,p_keszlet       IN NUMBER) IS
    v_count NUMBER;
  BEGIN
    -- Validáció: Ha 0 vagy negatív, hiba (-20102)
    IF p_keszlet <= 0 THEN
      RAISE hibas_adat_exc;
    END IF;

    -- Ellenőrzés: Létezik már? (COUNT-ot használunk, hogy ne szálljon el hibával, ha 0)
    SELECT COUNT(*)
      INTO v_count
      FROM kereskedes_jarmu kj
     WHERE kj.kereskedes_id = p_kereskedes_id 
       AND kj.jarmu_id = p_jarmu_id;
    
    IF v_count > 0 THEN
      -- HA MÁR VAN: Csak növeljük a készletet
      UPDATE kereskedes_jarmu
         SET darabszam = darabszam + p_keszlet 
       WHERE kereskedes_id = p_kereskedes_id 
         AND jarmu_id = p_jarmu_id;
    ELSE
      -- HA MÉG NINCS: Új sor beszúrása
      -- FONTOS: Az 'ar' mező NOT NULL a táblában, ezért kötelező értéket adni neki!
      -- Mivel a bemeneten nincs ár, beírunk 0-t technikai értékként.
      INSERT INTO kereskedes_jarmu(
        kereskedes_id,
        jarmu_id,
        darabszam,
        ar) 
      VALUES(
        p_kereskedes_id,
        p_jarmu_id,
        p_keszlet,
        0); 
    END IF;
    
  END keszlet_feltoltes;

END pkg_jarmu;
/
--7
CREATE OR REPLACE TYPE ty_kereskedes_statisztika IS OBJECT
(
  kereskedes_nev          VARCHAR2(250),
  forgalmazott_jarmu_szam NUMBER,
  jarmu_marka             VARCHAR2(250),
  jarmu_tipus             VARCHAR2(250),
  darabszam_ertek         NUMBER
)
;
CREATE OR REPLACE TYPE ty_kereskedes_statisztika_l IS TABLE OF ty_kereskedes_statisztika;
--8
CREATE OR REPLACE FUNCTION get_ty_kereskedes_statisztika
  RETURN ty_kereskedes_statisztika_l IS

  v_jarmu ty_kereskedes_statisztika_l;

BEGIN

  SELECT ty_kereskedes_statisztika(k.nev
        ,COUNT(DISTINCT kj.jarmu_id)
        ,j.marka
        ,j.tipus
        ,SUM(kj.darabszam * kj.ar)
        )
    BULK COLLECT
    INTO v_jarmu
    FROM kereskedes_jarmu kj
    JOIN kereskedes k
      ON kj.kereskedes_id = k.id
    JOIN jarmu j
      ON kj.jarmu_id = j.id
   GROUP BY k.nev, j.marka, j.tipus;
   
   return v_jarmu;

END get_ty_kereskedes_statisztika;
/
--9
DECLARE
  lv_jarmu_ty ty_kereskedes_statisztika_l;
BEGIN
  lv_jarmu_ty := get_ty_kereskedes_statisztika;

  FOR i IN 1 .. lv_jarmu_ty.count
  LOOP
    dbms_output.put_line('Kereskedes neve: ' || lv_jarmu_ty(i)
                         .kereskedes_nev || ', Forgalmazott jarmu szam: ' || lv_jarmu_ty(i)
                         .forgalmazott_jarmu_szam || ', Jarmu marka: ' || lv_jarmu_ty(i)
                         .jarmu_marka || ', Jarmu tipus: ' || lv_jarmu_ty(i)
                         .jarmu_tipus || ', Darabszam ertek: ' || lv_jarmu_ty(i)
                         .darabszam_ertek);
  END LOOP;
END;
