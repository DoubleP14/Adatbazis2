--VIEW AMIK ÚJAK LEHETNEK

CREATE OR REPLACE VIEW vw_termek_darabszam AS
SELECT 
    v.nev AS vasarlo_neve,
    -- COUNT: Számolj
    -- DISTINCT: Csak a különbözőket (kiszűri az ismétlődést)
    COUNT(DISTINCT t.id) AS kulonbozo_termekek_szama,
    
    -- Bónusz: Összesen hány darabot vett (pl. 10 tej + 5 kenyér = 15 db)
    SUM(rt.mennyiseg) AS osszes_darabszam
FROM vevo v
JOIN rendeles r ON v.id = r.vevo_id
JOIN rendeles_tetel rt ON r.id = rt.rendeles_id
JOIN termek t ON rt.termek_id = t.id
GROUP BY v.nev;
/


CREATE OR REPLACE VIEW vw_atlagos_koltes AS
SELECT 
    v.nev AS vasarlo_neve,
    
    -- 1. Opció: Ha csak a tételek átlagára (pl. átlagosan 500 Ft-os dolgokat vesz)
    ROUND(AVG(rt.aktualis_ar), 2) AS atlagos_termek_ar,

    -- 2. Opció (Gyakoribb): Átlagos RENDELÉSI érték (Total pénz / Rendelések száma)
    -- ROUND(..., 2) -> Kerekítés 2 tizedesre
    ROUND( SUM(rt.mennyiseg * rt.aktualis_ar) / COUNT(DISTINCT r.id), 2 ) AS atlagos_kosarertek

FROM vevo v
JOIN rendeles r ON v.id = r.vevo_id
JOIN rendeles_tetel rt ON r.id = rt.rendeles_id
GROUP BY v.nev;
/


CREATE OR REPLACE VIEW vw_2023_stat AS
SELECT 
    v.nev AS vasarlo_neve,
    SUM(rt.mennyiseg * rt.aktualis_ar) AS eves_koltes
FROM vevo v
JOIN rendeles r ON v.id = r.vevo_id
JOIN rendeles_tetel rt ON r.id = rt.rendeles_id
-- A szűrés a GROUP BY előtt van!
WHERE TO_CHAR(r.rendeles_datum, 'YYYY') = '2023'
GROUP BY v.nev;
/


CREATE OR REPLACE VIEW vw_nagyvasarlok AS
SELECT 
    v.nev AS vasarlo_neve,
    SUM(rt.mennyiseg * rt.aktualis_ar) AS osszes_koltes
FROM vevo v
JOIN rendeles r ON v.id = r.vevo_id
JOIN rendeles_tetel rt ON r.id = rt.rendeles_id
GROUP BY v.nev
-- A szűrés a GROUP BY után van!
HAVING SUM(rt.mennyiseg * rt.aktualis_ar) > 1000000;
/








---VIEW AZ EDDIGI ZH ALAPJÁN

CREATE OR REPLACE VIEW vw_legolcsobb AS
SELECT 
    t.megnevezes,
    t.kategoria,
    t.ar,
    -- Ez a varázslat:
    -- Kiszámolja a MINIMUM árat a Kategórián belül, de NEM nyomja össze a sorokat!
    MIN(t.ar) OVER (PARTITION BY t.kategoria) AS kategoria_legolcsobb_ara
FROM termek t;


CREATE OR REPLACE VIEW vw_munka_sorszam AS
SELECT 
    b.nev AS brigad_nev,
    p.projekt_nev,
    p.kezdo_datum,
    -- Ez a varázslat:
    -- 1. PARTITION BY b.id -> Minden brigádnál újrakezdi az 1-től.
    -- 2. ORDER BY p.kezdo_datum -> Dátum szerint növekszik.
    ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY p.kezdo_datum) AS hanyadik_munka
FROM brigad b
JOIN projekt p ON b.id = p.brigad_id;


CREATE OR REPLACE VIEW vw_lista AS
SELECT 
    v.nev AS vasarlo_neve,
    r.datum,
    -- Ez a varázslat:
    -- WITHIN GROUP (ORDER BY ...): Milyen sorrendben legyenek a listában?
    LISTAGG(t.megnevezes, ', ') WITHIN GROUP (ORDER BY t.megnevezes) AS termekek_listaja,
    SUM(t.ar) AS vegosszeg
FROM vevo v
JOIN rendeles r ON v.id = r.vevo_id
JOIN tetel t ON r.id = t.rendeles_id
GROUP BY v.nev, r.datum; -- FONTOS: Ami nincs a LISTAGG-ban vagy SUM-ban, azt ide kell írni!


CREATE OR REPLACE VIEW vw_datumok AS
SELECT 
    r.id,
    r.rendeles_datum,
    r.szallitas_datum, -- Ez lehet NULL
    -- Ez a varázslat:
    -- Ha a szallitas_datum NULL, akkor SYSDATE-et ír ki. Ha nem NULL, marad az eredeti.
    NVL(r.szallitas_datum, SYSDATE) AS tenyleges_datum
FROM rendeles r;





--PROCEDURE PÉLDÁK


-- MERGE Logika (Update vagy Insert)
CREATE OR REPLACE PROCEDURE pr_termek_karbantartas IS
    -- 1. Kivétel deklarálása (Ez kötelező a pontért!)
    migration_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(migration_exc, -20001);
    
    v_count NUMBER;
BEGIN
    -- 2. Ciklus: Végigmegyünk a segédtábla minden során
    FOR rec IN (SELECT * FROM beszallito_frissites) LOOP
        
        BEGIN -- Belső blokk, hogy ha egy hibás, ne álljon le minden (opcionális, de profi)
            
            -- 3. Ellenőrzés: Létezik már ez az ID a főtáblában?
            SELECT COUNT(*) INTO v_count 
            FROM termek 
            WHERE id = rec.termek_id; -- A "rec" a segédtábla aktuális sora
            
            IF v_count > 0 THEN
                -- 4. UPDATE ág (Ha már van)
                UPDATE termek
                SET megnevezes = rec.megnevezes,
                    kategoria = rec.kategoria,
                    ar = rec.uj_ar,
                    -- FIGYELJ! A feladat gyakran kéri, hogy NÖVELD a készletet (+ jel)
                    raktarkeszlet = raktarkeszlet + rec.szallitott_mennyiseg
                WHERE id = rec.termek_id;
                
            ELSE
                -- 5. INSERT ág (Ha még nincs)
                INSERT INTO termek (id, megnevezes, kategoria, ar, raktarkeszlet)
                VALUES (rec.termek_id, rec.megnevezes, rec.kategoria, rec.uj_ar, rec.szallitott_mennyiseg);
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Ha bármi hiba van a cikluson belül, dobjuk a kért kivételt
                RAISE migration_exc;
        END;
        
    END LOOP;
    
    -- 6. Véglegesítés
    COMMIT;

EXCEPTION
    -- 7. A feladat által kért hiba elkapása és továbbdobása
    WHEN migration_exc THEN
        ROLLBACK; -- Visszavonjuk a módosításokat hiba esetén
        RAISE_APPLICATION_ERROR(-20001, 'Hiba történt a migráció során!');
        
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Váratlan hiba történt!');
END;
/



-- Security Logika
/* ======================================================
   1. LÉPÉS: CSOMAG (A KULCS ÉS A KIVÉTEL TÁROLÁSA)
   ====================================================== */
CREATE OR REPLACE PACKAGE pkg_termek_security IS
    -- Ez a logikai kapcsoló (alapból ZÁRVA van)
    g_allowed BOOLEAN := FALSE;
    
    -- A feladat által kért egyedi kivétel definíciója
    cannot_insert_product_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(cannot_insert_product_exc, -20003);
END;
/

/* ======================================================
   2. LÉPÉS: TRIGGER (AZ ŐR - TILTJA A KÉZI BESZÚRÁST)
   ====================================================== */
CREATE OR REPLACE TRIGGER trg_block_termek_insert
BEFORE INSERT ON termek
BEGIN
    -- Ha a kapcsoló HAMIS (tehát nem az eljárásból jöttünk), akkor ERROR
    IF NOT pkg_termek_security.g_allowed THEN
        RAISE_APPLICATION_ERROR(-20003, 'HIBA: Terméket csak a hivatalos eljáráson keresztül lehet rögzíteni!');
    END IF;
END;
/

/* ======================================================
   3. LÉPÉS: ELJÁRÁS (A BEJÁRAT - NYIT, BESZÚR, ZÁR)
   ====================================================== */
CREATE OR REPLACE PROCEDURE pr_uj_termek_rogzitese(
    p_megnevezes IN VARCHAR2,
    p_kategoria IN VARCHAR2,
    p_ar IN NUMBER,
    p_keszlet IN NUMBER
) IS
BEGIN
    -- 1. KAPU NYITÁSA
    pkg_termek_security.g_allowed := TRUE;
    
    -- 2. ADAT BESZÚRÁSA (Most a trigger átenged)
    -- Megj: Az ID-t a korábbi trigger (4. feladat) intézi automatikusan
    INSERT INTO termek (megnevezes, kategoria, ar, raktarkeszlet)
    VALUES (p_megnevezes, p_kategoria, p_ar, p_keszlet);
    
    -- 3. KAPU ZÁRÁSA
    pkg_termek_security.g_allowed := FALSE;
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- BIZTONSÁGI RÉSZ: Hiba esetén is vissza kell zárni a kaput!
        pkg_termek_security.g_allowed := FALSE;
        
        -- Hiba továbbdobása, hogy lássa a felhasználó
        RAISE;
END;
/



-- Dátum Ütközés Vizsgálat
CREATE OR REPLACE PROCEDURE pr_projekt_hozzarendeles(
    p_projekt_id IN NUMBER,
    p_brigad_id  IN NUMBER,
    p_kezdo_datum IN DATE,
    p_veg_datum   IN DATE
) IS
    -- 1. Kivétel deklarálása (A feladat kéri a nevét!)
    crew_booked_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(crew_booked_exc, -20005);
    
    v_utkozes_szam NUMBER;
BEGIN
    -- 2. ÜTKÖZÉS VIZSGÁLATA
    -- Megszámoljuk, van-e olyan meglévő munka a brigádnál, ami átfedi az újat.
    SELECT COUNT(*)
    INTO v_utkozes_szam
    FROM projekt_brigad  -- (A kapcsolótábla neve)
    WHERE brigad_id = p_brigad_id -- Csak ezt a brigádot nézzük
      AND (
            -- A varázs-képlet:
            -- Az új munka hamarabb kezdődik, mint ahogy a régi véget érne...
            p_kezdo_datum < tenyleges_veg_datum 
            AND 
            -- ...ÉS az új munka később végződik, mint ahogy a régi elkezdődött.
            p_veg_datum > tenyleges_kezd_datum
          );

    -- 3. HA VAN ÜTKÖZÉS -> HIBA
    IF v_utkozes_szam > 0 THEN
        RAISE crew_booked_exc;
    END IF;

    -- 4. HA NINCS ÜTKÖZÉS -> BESZÚRÁS
    -- (Ha eljutottunk ide, akkor szabad a pálya)
    INSERT INTO projekt_brigad (projekt_id, brigad_id, tenyleges_kezd_datum, tenyleges_veg_datum)
    VALUES (p_projekt_id, p_brigad_id, p_kezdo_datum, p_veg_datum);

    COMMIT;

EXCEPTION
    -- 5. HIBAKEZELÉS
    WHEN crew_booked_exc THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20005, 'HIBA: A brigád ebben az időszakban már dolgozik máshol!');
        
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Váratlan hiba: ' || SQLERRM);
END;
/



-- Keresés Szövegrészletre 
CREATE OR REPLACE PROCEDURE pr_legolcsobb_keresese(
    p_keresett_marka IN VARCHAR2, -- pl: 'toy'
    p_keresett_tipus IN VARCHAR2  -- pl: 'yaris'
) IS
    -- 1. Kivétel deklarálása (A feladat kéri!)
    kereskedes_nem_talalhato_exc EXCEPTION;
    PRAGMA EXCEPTION_INIT(kereskedes_nem_talalhato_exc, -20101);

    v_kereskedes_nev kereskedes.nev%TYPE;
    v_kereskedes_cim kereskedes.cim%TYPE;
    v_ar             NUMBER;
BEGIN
    -- 2. A LEKÉRDEZÉS (A "Szendvics" technika)
    SELECT k.nev, k.cim, kj.ar
    INTO v_kereskedes_nev, v_kereskedes_cim, v_ar
    FROM kereskedes k
    JOIN kereskedes_jarmu kj ON k.id = kj.kereskedes_id
    JOIN jarmu j ON kj.jarmu_id = j.id
    WHERE 
        -- A: Márka keresése (Kis/Nagybetű független + Részlet)
        UPPER(j.marka) LIKE UPPER('%' || p_keresett_marka || '%')
        AND 
        -- B: Típus keresése (Ugyanúgy)
        UPPER(j.tipus) LIKE UPPER('%' || p_keresett_tipus || '%')
        
    -- 3. RENDEZÉS (Hogy a legolcsóbbat kapjuk)
    ORDER BY kj.ar ASC
    -- 4. CSAK AZ ELSŐ TALÁLAT KELL
    FETCH FIRST 1 ROWS ONLY;

    -- Kiírás (hogy lássuk az eredményt)
    DBMS_OUTPUT.PUT_LINE('Találat: ' || v_kereskedes_nev || ' (' || v_kereskedes_cim || ') - Ár: ' || v_ar);

EXCEPTION
    -- 5. HA NINCS TALÁLAT
    WHEN NO_DATA_FOUND THEN
        -- Ez az Oracle beépített hibája, ha a SELECT INTO nem talál semmit.
        -- Ezt alakítjuk át a feladat által kért saját hibára.
        RAISE_APPLICATION_ERROR(-20101, 'HIBA: Nem található ilyen jármű a keresett feltételekkel!');
        
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20102, 'Váratlan hiba: ' || SQLERRM);
END;
/