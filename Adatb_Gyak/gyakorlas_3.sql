--1
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_count
    FROM dba_users t
   WHERE t.username = 'ETEL_RENDELES';

  IF v_count = 1
  THEN
    EXECUTE IMMEDIATE 'drop user etel_rendeles cascade';
  END IF;
END;
/

create user etel_rendeles identified by "komolyJelszo" default tablespace users quota unlimited on users;

grant create session to etel_rendeles;
grant create table to etel_rendeles;
grant create view to etel_rendeles;
grant create trigger to etel_rendeles;
grant create sequence to etel_rendeles;
grant create type to etel_rendeles;
grant create procedure to etel_rendeles;


alter session set current_schema = etel_rendeles;
/





create table etel(
id number constraint etel_pk primary key,
megnevezes varchar2(250) not null,
leiras varchar2(4000) not null,
ar number not null
);

create table rendeles(
id number constraint rendeles_pk primary key,
cim varchar2(250) not null,
feladas_datum date not null,
megjegyzes varchar2(400),
szallitasi_datum date
);

create table etel_rendeles(
id number constraint etel_rendeles_pk primary key,
etel_id number constraint etel_id_fk references etel(id),
rendeles_id number constraint rendeles_id_fk references rendeles(id),
mennyiseg number not null,

constraint uq_etel_rendeles unique (etel_id, rendeles_id)
);
/




create sequence etel_seq start with 143000;
create sequence rendeles_seq start with 89001;
create sequence etel_rendeles_seq start with 110000;
/






create or replace trigger trg_etel
before insert on etel
for each row
  when(new.id is null)
  begin
    :new.id := etel_seq.nextval;
  end;
/

create or replace trigger trg_rendeles
before insert on rendeles
for each row
  when(new.id is null)
  begin
    :new.id := rendeles_seq.nextval;
  end;
/

create or replace trigger trg_etel_rendeles
before insert on etel_rendeles
for each row
  when(new.id is null)
  begin
    :new.id := etel_rendeles_seq.nextval;
  end;
/







INSERT INTO Etel (Megnevezes, Leiras, Ar)
VALUES ('Margherita Pizza', 'Klasszikus olasz pizza paradicsomsz�sszal �s mozzarell�val.', 2200);

INSERT INTO Etel (Megnevezes, Leiras, Ar)
VALUES ('Csirke Wrap', 'Friss z�lds�gekkel t�lt�tt grillcsirk�s wrap.', 1800);

INSERT INTO Etel (Megnevezes, Leiras, Ar)
VALUES ('Bacon Burger', 'Marhah�spog�csa ropog�s baconnel �s cheddar sajttal.', 3200);




INSERT INTO Rendeles (Cim, feladas_datum, Megjegyzes, szallitasi_datum)
VALUES ('P�cs, F� utca 12.', to_date('01-03-2025', 'dd-mm-yyyy'),NULL, to_date('01-03-2025', 'dd-mm-yyyy'));

INSERT INTO Rendeles (Cim, feladas_datum, Megjegyzes, szallitasi_datum)
VALUES ('P�cs, Kertv�ros 8.', to_date('02-03-2025', 'dd-mm-yyyy'), 'K�rlek csengess!', to_date('02-03-2025', 'dd-mm-yyyy'));

INSERT INTO Rendeles (Cim, feladas_datum, Megjegyzes, szallitasi_datum)
VALUES ('P�cs, Kir�ly utca 5.', to_date('03-03-2025', 'dd-mm-yyyy'), NULL, NULL);



INSERT INTO etel_rendeles (rendeles_id, etel_id, Mennyiseg)
VALUES (89001, 143000, 2);

INSERT INTO etel_rendeles (rendeles_id, etel_id, Mennyiseg)
VALUES (89001, 143002, 1);

INSERT INTO etel_rendeles (rendeles_id, etel_id, Mennyiseg)
VALUES (89003, 143001, 3);
/





CREATE OR REPLACE VIEW vw_lekerdezes AS
SELECT r.feladas_datum AS rendeles_idopont
      ,CASE 
         WHEN r.szallitasi_datum IS NULL THEN SYSDATE 
         ELSE r.szallitasi_datum 
       END AS feladas_idopont
      ,(SELECT SUM(er.mennyiseg * e.ar)
          FROM etel_rendeles er
          JOIN etel e ON er.etel_id = e.id
         WHERE er.rendeles_id = r.id) AS rendeles_osszertek
  FROM rendeles r;
/

--Szebben:
CREATE OR REPLACE VIEW vw_lekerdezes AS
SELECT r.feladas_datum AS rendeles_idopont
      
      -- 1. Szépítés: A hosszú CASE helyett a rövid NVL
      ,NVL(r.szallitasi_datum, SYSDATE) AS feladas_idopont
      
      -- 2. Szépítés: NVL a subquery köré, hogy ne legyen NULL az összeg
      ,NVL((SELECT SUM(er.mennyiseg * e.ar)
              FROM etel_rendeles er
              JOIN etel e ON er.etel_id = e.id
             WHERE er.rendeles_id = r.id), 0) AS rendeles_osszertek
             
  FROM rendeles r;
/


--Még szebben:
CREATE OR REPLACE VIEW vw_lekerdezes AS
SELECT r.feladas_datum AS rendeles_idopont
      ,NVL(r.szallitasi_datum, SYSDATE) AS feladas_idopont
      -- Itt nem kell második SELECT, mert a fő lekérdezésben összegezzük
      ,NVL(SUM(er.mennyiseg * e.ar), 0) AS rendeles_osszertek
  FROM rendeles r
  -- Hozzákapcsoljuk a táblákat (LEFT JOIN, hogy a 0 is megmaradjon!)
  LEFT JOIN etel_rendeles er ON r.id = er.rendeles_id
  LEFT JOIN etel e ON er.etel_id = e.id
 -- Itt viszont kötelező a GROUP BY mindenre, ami nem SUM
 GROUP BY r.feladas_datum, r.szallitasi_datum, r.id;


  


CREATE OR REPLACE PROCEDURE uj_rendeles(
       p_rendeles_cim            IN VARCHAR2
      ,p_megjegyzes              IN VARCHAR2
      ,p_kert_szallitasi_idopont IN DATE
      ,p_rendeles_azonosito      OUT NUMBER) IS
BEGIN
  INSERT INTO rendeles
    (cim, feladas_datum, megjegyzes, szallitasi_datum)
  VALUES
    (p_rendeles_cim
    ,SYSDATE
    ,p_megjegyzes
    ,p_kert_szallitasi_idopont) -- Itt nem kell to_date!
  RETURNING id INTO p_rendeles_azonosito; -- Így kell ID-t visszaadni
END uj_rendeles;
/






CREATE OR REPLACE PACKAGE pkg_exceptions IS

 parent_not_found_exc exception;
 pragma exception_init(parent_not_found_exc, -20102);

END pkg_exceptions;
/






CREATE OR REPLACE PROCEDURE rendeles_hozzaadas(
       p_etel_id     IN NUMBER
      ,p_rendeles_id IN NUMBER) IS
  
  v_check_etel NUMBER;
  v_check_rendeles NUMBER;
  v_count NUMBER;

BEGIN
  -- 1. LÉPÉS: Ellenőrzés (Létezik-e az étel és a rendelés?)
  SELECT COUNT(*) INTO v_check_etel FROM etel WHERE id = p_etel_id;
  SELECT COUNT(*) INTO v_check_rendeles FROM rendeles WHERE id = p_rendeles_id;

  -- Ha valamelyik nem létezik, dobjuk a saját hibát
  IF v_check_etel = 0 OR v_check_rendeles = 0 THEN
     RAISE pkg_exceptions.parent_not_found_exc;
  END IF;

  -- 2. LÉPÉS: A te eredeti Upsert logikád (ez jó volt)
  SELECT COUNT(*)
    INTO v_count
    FROM etel_rendeles er
   WHERE er.etel_id = p_etel_id
     AND er.rendeles_id = p_rendeles_id;

  IF v_count > 0 THEN
    UPDATE etel_rendeles
       SET mennyiseg = mennyiseg + 1
     WHERE etel_id = p_etel_id
       AND rendeles_id = p_rendeles_id;
  ELSE
    INSERT INTO etel_rendeles
      (etel_id, rendeles_id, mennyiseg)
    VALUES
      (p_etel_id, p_rendeles_id, 1);
  END IF;

EXCEPTION
  WHEN pkg_exceptions.parent_not_found_exc THEN
    raise_application_error(-20102, 'Nem talalhato ilyen adat (szulo)!');
END rendeles_hozzaadas;
/





create or replace type ty_etel is object
(
etel_nev varchar2(250),
eladott_adag number,
ertek number
);

create or replace type ty_etel_l is table of ty_etel;
/





CREATE OR REPLACE FUNCTION get_etel RETURN ty_etel_l IS
  lv_etel ty_etel_l;
BEGIN
  SELECT ty_etel(e.megnevezes
                ,SUM(et.mennyiseg) -- Összesítjük a darabszámot
                ,SUM(et.mennyiseg * e.ar)) -- Összesítjük az értéket
    BULK COLLECT
    INTO lv_etel
    FROM etel e
    JOIN etel_rendeles et ON e.id = et.etel_id
   GROUP BY e.megnevezes; -- Csak név szerint csoportosítunk!

  RETURN lv_etel;
END get_etel;
/




DECLARE
  lv_etel ty_etel_l;
BEGIN
  lv_etel := get_etel;
  
  FOR i IN 1..lv_etel.count LOOP
    -- Itt volt az elírás javítva: .eladott_adag
    dbms_output.put_line('Etel nev: ' || lv_etel(i).etel_nev || 
                         ', Eladott adag: ' || lv_etel(i).eladott_adag || 
                         ', Osszertek: ' || lv_etel(i).ertek);
  END LOOP;
END;
/