--1
declare
v_count number;
begin
  select count(*)
  into v_count
  from dba_users t
  where t.username = 'TERMEK_NYILVANTARTO';
  
  if v_count = 1
    then
      execute immediate 'drop user termek_nyilvantarto cascade';
    end if;
end;
/

-- Nincs 't', nincs felesleges karakter. Tiszta és érthető.
DECLARE
  v_count NUMBER;
BEGIN
  SELECT count(*) 
    INTO v_count 
    FROM dba_users 
   WHERE username = 'TERMEK_NYILVANTARTO';
   
  IF v_count = 1 THEN
    EXECUTE IMMEDIATE 'drop user termek_nyilvantarto cascade';
  END IF;
END;
/

create user TERMEK_NYILVANTARTO identified by 12345678 default tablespace users quota unlimited on users;

grant create session to termek_nyilvantarto;
grant create view to termek_nyilvantarto;
grant create procedure to termek_nyilvantarto;
grant create table to termek_nyilvantarto;
grant create type to termek_nyilvantarto;
grant create sequence to termek_nyilvantarto;
grant create trigger to termek_nyilvantarto;

alter session set current_schema = termek_nyilvantarto;
/
--2
create sequence bolt_seq start with 12300;
create sequence termek_seq start with 9000;
create sequence bolt_termek_seq start with 10000;
/
--3
create table bolt(
id number constraint bolt_pk primary key,
nev varchar2(250) not null,
cim varchar2(250) not null
);

create table termek(
id number constraint termek_pk primary key,
megnevezes varchar2(250) not null,
reszletek varchar2(2000)
);

create table bolt_termek(
id number constraint bolt_termek_pk primary key,
bolt_id number constraint bolt_id_fk references bolt(id) not null,
termek_id number constraint termek_id_fk references termek(id) not null,
egysegar number not null,
keszlet number not null,

constraint uq_bolt_termek unique(bolt_id, termek_id)
);
/
--4
CREATE OR REPLACE TRIGGER trg_bolt
  BEFORE INSERT ON bolt
  FOR EACH ROW
  WHEN (new.id IS NULL)
BEGIN
  :new.id := bolt_seq.nextval;
END;
/
CREATE OR REPLACE TRIGGER trg_termek
  BEFORE INSERT ON termek
  FOR EACH ROW
  WHEN (new.id IS NULL)
BEGIN
  :new.id := termek_seq.nextval;
END;
/
CREATE OR REPLACE TRIGGER trg_bolt_termek
  BEFORE INSERT ON bolt_termek
  FOR EACH ROW
  WHEN (new.id IS NULL)
BEGIN
  :new.id := bolt_termek_seq.nextval;
END;
/
--5
create or replace view vw_adatok as
SELECT t.megnevezes AS termek_nev
      ,b.nev AS bolt_nev
      ,bt.egysegar AS egysegar
      ,(SELECT MIN(bt_inner.egysegar)
         FROM bolt_termek bt_inner
        WHERE bt_inner.termek_id = t.id) as legkisebb_ar
  FROM termek t
  JOIN bolt_termek bt
    ON t.id = bt.termek_id
  JOIN bolt b
    ON bt.bolt_id = b.id;
/
--jobbik módszer:
CREATE OR REPLACE VIEW vw_adatok_profi AS 
SELECT t.megnevezes AS termek_nev
      ,b.nev AS bolt_nev
      ,bt.egysegar AS egysegar
      -- Így sokkal elegánsabb és rövidebb:
      ,MIN(bt.egysegar) OVER (PARTITION BY t.id) as legkisebb_ar
  FROM termek t
  JOIN bolt_termek bt ON t.id = bt.termek_id
  JOIN bolt b ON bt.bolt_id = b.id;
/
--6
CREATE OR REPLACE PACKAGE pkg_keszlet IS

  FUNCTION get_keszlet(p_termek_id IN NUMBER
                      ,p_bolt_id   IN NUMBER
                      ,p_keszlet   OUT NUMBER) RETURN NUMBER;

  PROCEDURE keszlet_feltoltes(p_bolt_id   IN NUMBER
                             ,p_termek_id IN NUMBER
                             ,p_keszlet   IN NUMBER);

  termek_nem_forgalmazott_exc EXCEPTION;
  PRAGMA EXCEPTION_INIT(termek_nem_forgalmazott_exc, -20100);

  hibas_adat_exc EXCEPTION;
  PRAGMA EXCEPTION_INIT(hibas_adat_exc, -20101);

END pkg_keszlet;
/
CREATE OR REPLACE PACKAGE BODY pkg_keszlet IS

  FUNCTION get_keszlet(p_termek_id IN NUMBER
                      ,p_bolt_id   IN NUMBER
                      ,p_keszlet   OUT NUMBER) RETURN NUMBER IS
  BEGIN
  
    SELECT bt.keszlet
      INTO p_keszlet
      FROM bolt_termek bt
      JOIN termek t
        ON bt.termek_id = t.id
      JOIN bolt b
        ON bt.bolt_id = b.id
     WHERE bt.termek_id = p_termek_id
       AND bt.bolt_id = p_bolt_id;
  
    RETURN p_keszlet;
  
  EXCEPTION
    WHEN no_data_found THEN
      raise_application_error(-20100, 'Nincs ilyen adat!');
    
  END get_keszlet;

  PROCEDURE keszlet_feltoltes(p_bolt_id   IN NUMBER
                             ,p_termek_id IN NUMBER
                             ,p_keszlet   IN NUMBER) IS
    v_count NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM bolt_termek bt
     WHERE bt.bolt_id = p_bolt_id
       AND bt.termek_id = p_termek_id;
  
    IF v_count > 0
    THEN
      UPDATE bolt_termek
         SET keszlet = keszlet + p_keszlet
       WHERE bolt_id = p_bolt_id
         AND termek_id = p_termek_id;
    ELSE
      INSERT INTO bolt_termek
        (bolt_id
        ,termek_id
        ,egysegar
        ,keszlet)
      VALUES
        (p_bolt_id
        ,p_termek_id
        ,(SELECT bt.egysegar
           FROM bolt_termek bt
          WHERE bt.termek_id = p_termek_id)
        ,p_keszlet);
    END IF;
  
  EXCEPTION
    WHEN no_data_found THEN
      raise_application_error(-20101, 'Nincs ilyen termek vagy bolt');
    
  END keszlet_feltoltes;

END pkg_keszlet;
/
--Másik megoldás (jobb)
CREATE OR REPLACE PACKAGE pkg_keszlet IS

  -- 1. JAVÍTÁS: Nincs OUT paraméter, csak RETURN
  FUNCTION get_keszlet(p_termek_id IN NUMBER
                      ,p_bolt_id   IN NUMBER) RETURN NUMBER;

  PROCEDURE keszlet_feltoltes(p_bolt_id   IN NUMBER
                             ,p_termek_id IN NUMBER
                             ,p_keszlet   IN NUMBER);
                             
  termek_nem_forgalmazott_exc EXCEPTION;
  PRAGMA EXCEPTION_INIT(termek_nem_forgalmazott_exc, -20100);

END pkg_keszlet;
/

CREATE OR REPLACE PACKAGE BODY pkg_keszlet IS

  -- FÜGGVÉNY: Lekérdezi a készletet
  FUNCTION get_keszlet(p_termek_id IN NUMBER
                      ,p_bolt_id   IN NUMBER) RETURN NUMBER IS
    v_keszlet NUMBER;
  BEGIN
    SELECT bt.keszlet
      INTO v_keszlet
      FROM bolt_termek bt
     WHERE bt.termek_id = p_termek_id
       AND bt.bolt_id = p_bolt_id;
  
    RETURN v_keszlet;
  
  EXCEPTION
    WHEN no_data_found THEN
      RAISE termek_nem_forgalmazott_exc; 
  END get_keszlet;

  -- ELJÁRÁS: Feltölti a készletet
  PROCEDURE keszlet_feltoltes(p_bolt_id   IN NUMBER
                             ,p_termek_id IN NUMBER
                             ,p_keszlet   IN NUMBER) IS
    v_count NUMBER;
  BEGIN
    -- Megnézzük, létezik-e már a kapcsolat
    SELECT COUNT(*)
      INTO v_count
      FROM bolt_termek bt
     WHERE bt.bolt_id = p_bolt_id
       AND bt.termek_id = p_termek_id;
  
    IF v_count > 0 THEN
      -- Ha van, növeljük a készletet
      UPDATE bolt_termek
         SET keszlet = keszlet + p_keszlet
       WHERE bolt_id = p_bolt_id
         AND termek_id = p_termek_id;
    ELSE
      -- Ha nincs, beszúrjuk újként
      -- 2. JAVÍTÁS: Az árat nem a boltból, hanem a TERMEK táblából vesszük!
      INSERT INTO bolt_termek (bolt_id, termek_id, egysegar, keszlet)
      VALUES (p_bolt_id, 
              p_termek_id, 
              (SELECT egysegar FROM termek WHERE id = p_termek_id), -- Feltételezett alapár
              p_keszlet);
    END IF;
  
    -- 3. JAVÍTÁS: Innen töröltük a NO_DATA_FOUND blokkot
    -- Mert itt soha nem futna le.
    
  EXCEPTION
     WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20101, 'Hiba történt: ' || SQLERRM);
  END keszlet_feltoltes;

END pkg_keszlet;
/

--7
CREATE OR REPLACE TYPE ty_bolt_statisztika IS OBJECT
(
  bolt_nev                 VARCHAR2(250),
  forgalmazott_termek_szam NUMBER,
  raktarkeszlet_ertek      NUMBER
)
;

CREATE OR REPLACE TYPE ty_bolt_statisztika_l IS TABLE OF ty_bolt_statisztika;
/

--8
CREATE OR REPLACE FUNCTION get_bolt_statisztika
  RETURN ty_bolt_statisztika_l IS

  lv_bolt ty_bolt_statisztika_l;

BEGIN
  SELECT ty_bolt_statisztika(
        b.nev,
        -- JAVÍTÁS: A feladat "terméket" kérdez, ezért termek_id-t számolunk!
        -- Mivel "különböző" a kérés, a DISTINCT a legbiztosabb válasz (bár PK miatt lehet felesleges, de a szövegnek így felel meg legjobban).
        COUNT(DISTINCT bt.termek_id), 
        
        SUM(bt.egysegar * bt.keszlet)
        )
    BULK COLLECT
    INTO lv_bolt
    FROM bolt_termek bt
    JOIN bolt b
      ON bt.bolt_id = b.id
    -- Itt csoportosítunk a bolt neve és ID-ja szerint
    GROUP BY b.nev, b.id; 

  RETURN lv_bolt;
END;
/

--9
DECLARE
  lv_bolt_statisztika ty_bolt_statisztika_l;
BEGIN
  lv_bolt_statisztika := get_bolt_statisztika;

  FOR i IN 1 .. lv_bolt_statisztika.count
  LOOP
    dbms_output.put_line('Bolt nev: ' || lv_bolt_statisztika(i).bolt_nev ||
                         ', Termekszam: ' || lv_bolt_statisztika(i)
                         .forgalmazott_termek_szam ||
                         ', Raktarkeszlet osszertek: ' || lv_bolt_statisztika(i)
                         .raktarkeszlet_ertek);
  END LOOP;
END;
