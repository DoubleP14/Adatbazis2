# Adatbazis2



segitseg:
CREATE OR REPLACE VIEW vw_lekerdezes_egyszeru AS
SELECT 
    r.feladas_datum AS rendeles_idopont,
    NVL(r.szallitasi_datum, SYSDATE) AS feladas_idopont,
    -- Itt történik a varázslat: Sima szorzás és összeadás, NULL kezeléssel
    NVL(SUM(er.mennyiseg * e.ar), 0) AS rendeles_osszertek
FROM 
    rendeles r
-- Fontos: LEFT JOIN kell!
-- Hogy azok a rendelések is megmaradjanak, ahol MÉG NINCS tétel (pl. most hozták létre)
LEFT JOIN 
    etel_rendeles er ON r.id = er.rendeles_id
LEFT JOIN 
    etel e ON er.etel_id = e.id
-- A szabályod: Ami nincs SUM-ban, az megy a GROUP BY-ba:
GROUP BY 
    r.id, r.feladas_datum, r.szallitasi_datum;
/
