--1. PACKAGE (Csomag) Szerkezet
--Elválasztjuk a definíciót (SPEC) és a megvalósítást (BODY). A BODY-ban lévő, de a SPEC-ben nem szereplő dolgok a PRIVÁT elemek.
-- 1. SPECIFIKÁCIÓ (Fejléc)
CREATE OR REPLACE PACKAGE pkg_kutyak IS
    -- Saját kivétel definiálása
    e_rossz_adat EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_rossz_adat, -20001);

    -- Publikus eljárás
    PROCEDURE kutya_atadas(p_kutya_id NUMBER, p_uj_gazda_id NUMBER);
END pkg_kutyak;
/

-- 2. BODY (Törzs)
CREATE OR REPLACE PACKAGE BODY pkg_kutyak IS

    -- PRIVÁT segédfüggvény (kívülről nem látszik)
    FUNCTION ellenorzes(p_id NUMBER) RETURN BOOLEAN IS
    BEGIN
        RETURN p_id IS NOT NULL;
    END;

    -- A publikus eljárás megvalósítása
    PROCEDURE kutya_atadas(p_kutya_id NUMBER, p_uj_gazda_id NUMBER) IS
    BEGIN
        IF NOT ellenorzes(p_kutya_id) THEN
            -- Hiba dobása
            RAISE_APPLICATION_ERROR(-20001, 'Érvénytelen ID!'); 
        END IF;

        UPDATE dog SET owner_id = p_uj_gazda_id WHERE dog_id = p_kutya_id;
    END;
END pkg_kutyak;
/


--2. KOLLEKCIÓK & BULK COLLECT (A legfontosabb!) ⭐️
--Így kell tömböt csinálni, feltölteni, törölni belőle és bejárni.
DECLARE
    -- Típus definíció (Nested Table)
    TYPE t_kutya_lista IS TABLE OF dog%ROWTYPE; 
    v_kutyak t_kutya_lista;
    v_idx    NUMBER; -- Index a bejáráshoz
BEGIN
    -- 1. BULK COLLECT (Mindent a memóriába rántunk)
    SELECT * BULK COLLECT INTO v_kutyak FROM dog;

    -- 2. TÖRLÉS FELTÉTEL ALAPJÁN (pl. 10 kg alatt)
    -- Figyelem: A .delete() "lyukakat" hagy a tömbben!
    v_idx := v_kutyak.first;
    WHILE v_idx IS NOT NULL LOOP
        IF v_kutyak(v_idx).weight < 10 THEN
            v_kutyak.delete(v_idx); -- Törlés
        END IF;
        v_idx := v_kutyak.next(v_idx); -- Ugrás a köv. létezőre
    END LOOP;

    -- 3. MARADÉK KIÍRATÁSA
    -- Itt is a .first / .next ciklus kell a lyukak miatt!
    v_idx := v_kutyak.first;
    WHILE v_idx IS NOT NULL LOOP
        dbms_output.put_line('Maradt: ' || v_kutyak(v_idx).dog_name);
        v_idx := v_kutyak.next(v_idx);
    END LOOP;
END;
/

--3. MULTISET UNION (Listák összefűzése)
--Ha két listát kell összeadni. Ehhez általában Object Type kell, nem Record!
-- Először kell egy típus az adatbázisban
CREATE OR REPLACE TYPE ty_kutya_obj AS OBJECT (neve VARCHAR2(50));
/
CREATE OR REPLACE TYPE ty_kutya_tab IS TABLE OF ty_kutya_obj;
/

DECLARE
    v_lista1 ty_kutya_tab := ty_kutya_tab(); -- Üres inicializálás
    v_lista2 ty_kutya_tab := ty_kutya_tab();
    v_ossz  ty_kutya_tab;
BEGIN
    -- Feltöltés példa
    v_lista1.extend; v_lista1(1) := ty_kutya_obj('Bodri');
    v_lista2.extend; v_lista2(1) := ty_kutya_obj('Buksi');

    -- AZ ÖSSZEFŰZÉS (UNION ALL: mindenki, UNION: duplikáltak nélkül)
    v_ossz := v_lista1 MULTISET UNION ALL v_lista2;

    FOR i IN 1..v_ossz.count LOOP
        dbms_output.put_line(v_ossz(i).neve);
    END LOOP;
END;
/


--4. DINAMIKUS SQL (Execute Immediate)
--Amikor stringként rakod össze a parancsot.
DECLARE
    v_sql    VARCHAR2(1000);
    v_darab  NUMBER;
    v_datum  DATE := DATE '2023-01-01';
BEGIN
    -- "USING" kulcsszó kötelező a biztonság miatt (:1 paraméter)
    v_sql := 'SELECT COUNT(*) FROM dog WHERE birth_date > :1';
    
    EXECUTE IMMEDIATE v_sql 
        INTO v_darab     -- Eredmény ide jön
        USING v_datum;   -- Bemenő adat ide
        
    dbms_output.put_line('Találat: ' || v_darab);
END;
/


--5. CURSOR vs. SYS_REFCURSOR
--Mi a különbség vizsgán?
--A) Sima Cursor (Explicit) - Ismert, fix lekérdezés.
DECLARE
    CURSOR cur_dog IS SELECT * FROM dog;
    v_sor cur_dog%ROWTYPE;
BEGIN
    OPEN cur_dog;
    LOOP
        FETCH cur_dog INTO v_sor;
        EXIT WHEN cur_dog%NOTFOUND; -- NE FELEJTSD EL!
        dbms_output.put_line(v_sor.dog_name);
    END LOOP;
    CLOSE cur_dog; -- NE FELEJTSD EL!
END;


--B) SYS_REFCURSOR (Dinamikus) - Ha a SELECT szövege változhat.
DECLARE
    v_cur SYS_REFCURSOR; -- Beépített típus
    v_nev VARCHAR2(100);
BEGIN
    -- OPEN ... FOR 'string'
    OPEN v_cur FOR 'SELECT dog_name FROM dog WHERE dog_id = 1';
    FETCH v_cur INTO v_nev;
    CLOSE v_cur;
END;


--6. TRIGGER PUSKA (History tábla töltés)
--Ez a vacc_type_h_trg feladat egyszerűsített váza.
CREATE OR REPLACE TRIGGER trg_dog_history
AFTER INSERT OR UPDATE OR DELETE ON dog
FOR EACH ROW
DECLARE
    v_muvelet CHAR(1);
BEGIN
    IF DELETING THEN v_muvelet := 'D';
    ELSIF UPDATING THEN v_muvelet := 'U';
    ELSE v_muvelet := 'I'; END IF;

    -- History táblába írás
    INSERT INTO dog_history (
        dog_id, nev, modositotta, mikor, muvelet
    ) VALUES (
        -- Ha törlünk, a régit mentjük (:OLD), ha új, akkor az újat (:NEW)
        CASE WHEN DELETING THEN :OLD.dog_id ELSE :NEW.dog_id END,
        CASE WHEN DELETING THEN :OLD.dog_name ELSE :NEW.dog_name END,
        sys_context('USERENV', 'OS_USER'), -- Ki csinálta?
        SYSDATE,
        v_muvelet
    );
END;
/


--A Hiányzó Láncszem: FORALL (Tömeges módosítás) 
--A "Dog Manager" kódokban volt BULK COLLECT (tömeges olvasás), de nem láttam a párját, a FORALL-t (tömeges írás). Ha teljesítményoptimalizálás a téma, ez a kettő kéz a kézben jár.
--Mikor kell? Ha van egy memóriatömböd (pl. 1000 kutya ID), és mindegyiket törölni/módosítani akarod az adatbázisban. Sima FOR LOOP helyett FORALL-t használsz, mert 10x gyorsabb.
DECLARE
    TYPE t_id_lista IS TABLE OF NUMBER;
    v_ids t_id_lista;
BEGIN
    -- 1. Begyűjtjük az adatokat (ezt már tudod: BULK COLLECT)
    SELECT dog_id BULK COLLECT INTO v_ids FROM dog WHERE weight < 5;

    -- 2. Tömeges törlés (FORALL) - Ez a gyors módszer!
    -- Nincs "LOOP" és "END LOOP", ez egyetlen parancs!
    FORALL i IN 1..v_ids.count
        DELETE FROM dog WHERE dog_id = v_ids(i);
        
    -- Commit csak a végén egyben
    COMMIT;
END;


--A "Csővezeték": PIPELINED Table Functions 🚰
--Ez a legdurvább téma, ami előfordulhat. Olyan függvény, ami úgy viselkedik, mint egy tábla: SELECT * FROM TABLE(függvény()).
--Mikor kell? Ha a feladat azt kéri: "Írjon függvényt, ami visszaad egy listát, és SELECT-ben használható."
-- Kell egy típus (objektum és lista) - ez már volt a kutyásban
CREATE OR REPLACE TYPE t_szam_lista IS TABLE OF NUMBER;
/

-- A függvény
CREATE OR REPLACE FUNCTION get_szamok(p_max NUMBER) 
RETURN t_szam_lista PIPELINED IS
BEGIN
    FOR i IN 1..p_max LOOP
        -- Ez a kulcsszó: PIPE ROW (egyesével köpi ki az adatot)
        PIPE ROW(i); 
    END LOOP;
    RETURN; -- Üres return a végére
END;
/

-- Így hívod meg:
SELECT * FROM TABLE(get_szamok(10));