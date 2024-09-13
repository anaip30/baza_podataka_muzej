             -- PROCEDURA --

#1 PROCEDURA KOJA IZRACUNAVA IZNOS RACUNA 

DELIMITER //

CREATE PROCEDURE IZRACUN_IZNOS_RACUNA(
    IN P_ID_RACUN INTEGER
)
BEGIN
    DECLARE V_CIJENA DECIMAL(10, 2);
    DECLARE V_VRSTA VARCHAR(20);
    DECLARE V_KOLICINA INTEGER;
    DECLARE V_ID_POSJETITELJ INTEGER;
    DECLARE V_IZNOS DECIMAL(10, 2);
    DECLARE V_TOTAL_IZNOS DECIMAL(10, 2) DEFAULT 0;
    DECLARE V_TOTAL_TIKET INTEGER DEFAULT 0;
    DECLARE V_TOTAL_TIKET_POSJETITELJ INTEGER DEFAULT 0;
    DECLARE V_DATUM DATE;
    DECLARE V_IS_EVENT_DAY BOOLEAN DEFAULT FALSE;
    DECLARE DONE INT DEFAULT FALSE;

   
    DECLARE CUR CURSOR FOR
        SELECT U.CIJENA_ULAZNICE, U.VRSTA_ULAZNICE, S.KOLICINA
        FROM STAVKA_RACUN S
        JOIN ULAZNICA U ON S.ID_ULAZNICA = U.ID
        WHERE S.ID_RACUN = P_ID_RACUN;

  
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET DONE = TRUE;

    
    SELECT ID_POSJETITELJ, DATUM INTO V_ID_POSJETITELJ, V_DATUM FROM RACUN WHERE ID = P_ID_RACUN;


    SELECT COUNT(*) INTO V_TOTAL_TIKET_POSJETITELJ
    FROM STAVKA_RACUN S
    JOIN RACUN R ON S.ID_RACUN = R.ID
    WHERE R.ID_POSJETITELJ = V_ID_POSJETITELJ;

    SELECT COUNT(*) INTO V_TOTAL_TIKET
    FROM STAVKA_RACUN
    WHERE ID_RACUN = P_ID_RACUN;


    SELECT COUNT(*) > 0 INTO V_IS_EVENT_DAY
    FROM DOGADAJ
    WHERE V_DATUM BETWEEN DATUM_POCETKA AND DATUM_ZAVRSETKA;

  
    OPEN CUR;
    LOOPIC: LOOP
        FETCH CUR INTO V_CIJENA, V_VRSTA, V_KOLICINA;
        IF DONE THEN
            LEAVE LOOPIC;
        END IF;

      
        IF V_IS_EVENT_DAY THEN
            SET V_CIJENA = V_CIJENA * 1.5;
        END IF;

        
        IF V_VRSTA = 'Grupna' AND V_TOTAL_TIKET >= 30 THEN
            SET V_IZNOS = V_KOLICINA * V_CIJENA * 0.85;
        ELSE
            SET V_IZNOS = V_KOLICINA * V_CIJENA;
        END IF;

        
        SET V_TOTAL_IZNOS = V_TOTAL_IZNOS + V_IZNOS;
    END LOOP;
    CLOSE CUR;

  
    IF V_TOTAL_TIKET_POSJETITELJ > 15 THEN
        SET V_TOTAL_IZNOS = V_TOTAL_IZNOS * 0.90;
    END IF;

   
    UPDATE RACUN
    SET IZNOS = V_TOTAL_IZNOS
    WHERE ID = P_ID_RACUN;
END //

DELIMITER ;

CALL IZRACUN_IZNOS_RACUNA(1);


-- drop procedure BRISANJE_RACUNA;

#2 PROCEDURA ZA BRISANJE RAČUNA 

DELIMITER //

CREATE PROCEDURE STORNO_RACUNA(IN P_ID_RACUN INTEGER)
BEGIN
    DECLARE P_STATUS_RACUNA VARCHAR(1);
    DECLARE P_ID_ZAPOSLENIK INTEGER;
    DECLARE P_PREKINI_BROJANJE INTEGER;
    
    SELECT STATUS_RACUNA, ID_ZAPOSLENIK INTO P_STATUS_RACUNA, P_ID_ZAPOSLENIK FROM RACUN WHERE ID = P_ID_RACUN;

    IF P_STATUS_RACUNA = 'F' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Račun je izbrisan.';
    END IF;

    SELECT COUNT(*) INTO P_PREKINI_BROJANJE
    FROM RACUN
    WHERE ID_ZAPOSLENIK = P_ID_ZAPOSLENIK
    AND STATUS_RACUNA = 'F'
    AND DATE(DATUM) = CURDATE();

    IF P_PREKINI_BROJANJE >= 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Zaposlenik ne može stornirati više od 10 računa dnevno.';
    END IF;

    UPDATE RACUN
    SET STATUS_RACUNA = 'F'
    WHERE ID = P_ID_RACUN;
    DELETE FROM RACUN WHERE ID = P_ID_RACUN;
END //

DELIMITER ;

#3 PROCEDURA ZA PROVJERU EKSPONATA NA DOGADAJU 

DELIMITER //

CREATE PROCEDURE PROVJERI_EKSPONAT_NA_DOGADAJU(IN P_ID_EKSPONAT INTEGER, IN P_DATUM_POCETKA DATE, IN P_DATUM_ZAVRSETKA DATE)
BEGIN
    DECLARE P_COUNT INTEGER;

    SELECT COUNT(*)
    INTO P_COUNT
    FROM DOGADAJ D
    JOIN EKSPONAT_NA_DOGADAJ E ON D.ID = E.ID_DOGADAJ
    WHERE E.ID_EKSPONAT = P_ID_EKSPONAT
    AND (P_DATUM_POCETKA BETWEEN D.DATUM_POCETKA AND D.DATUM_ZAVRSETKA
         OR P_DATUM_ZAVRSETKA BETWEEN D.DATUM_POCETKA AND D.DATUM_ZAVRSETKA
         OR D.DATUM_POCETKA BETWEEN P_DATUM_POCETKA AND P_DATUM_ZAVRSETKA
         OR D.DATUM_ZAVRSETKA BETWEEN P_DATUM_POCETKA AND P_DATUM_ZAVRSETKA);

    IF P_COUNT > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Eksponat ne može biti na dva događaja u isto vrijeme.';
    END IF;
END //

DELIMITER ;

#4 PROCERDURA ZA OBRACUN PLACE 

DELIMITER //

CREATE PROCEDURE OBRACUN_PLACE()
BEGIN
    DECLARE DONE INT DEFAULT 0;
    DECLARE P_ID INTEGER;
    DECLARE P_GODINA_STAZA INTEGER;
    DECLARE P_NOVA_PLACA DECIMAL(10, 2);

    DECLARE CUR CURSOR FOR
        SELECT ID, YEAR(CURDATE()) - YEAR(DATUM_ZAPOSLENJA) AS GODINESTAZA, PLACA
        FROM ZAPOSLENIK;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET DONE = 1;

    OPEN CUR;

    LOOPIC: LOOP
        FETCH CUR INTO P_ID, P_GODINA_STAZA, P_NOVA_PLACA;
        IF DONE THEN
            LEAVE LOOPIC;
        END IF;

        IF P_GODINA_STAZA >= 5 THEN
            SET P_NOVA_PLACA = P_NOVA_PLACA * 1.10;
        END IF;

        UPDATE ZAPOSLENIK
        SET PLACA = P_NOVA_PLACA
        WHERE ID = P_ID;
    END LOOP;

    CLOSE CUR;
END //

DELIMITER ;

-- FUNKACIJA 

#1 FUNKCIJA KOJA PRIKAZUJE POPULARAN DOGADAJ 
DELIMITER //

CREATE FUNCTION POPULARAN_DOGADAJ() RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    DECLARE POP_DOG VARCHAR(100);
    
    SELECT DOGADAJ.NAZIV INTO POP_DOG
    FROM DOGADAJ
    JOIN MUZEJ ON MUZEJ.ID = DOGADAJ.ID_MUZEJ
    JOIN RECENZIJA_DOGADAJ ON DOGADAJ.ID = RECENZIJA_DOGADAJ.ID_DOGADAJ
    GROUP BY DOGADAJ.ID
    ORDER BY COUNT(RECENZIJA_DOGADAJ.ID) DESC
    LIMIT 1;
    
    RETURN POP_DOG;
END //

DELIMITER ;

SELECT POPULARAN_DOGADAJ();

drop function DAL_MOZE_PRODAT_KARTU;
#2 FUNKCIJA KOJA PRIKAZUJE  DA LI MOZE PRODAT KARTU ZAPOSLENIK
DELIMITER //

CREATE FUNCTION DAL_MOZE_PRODAT_KARTU(P_ID_ZAPOSLENIK INTEGER, P_ID_MUZEJ INTEGER) RETURNS TINYINT(1)
BEGIN
    DECLARE COUNT INTEGER;

    SELECT COUNT(*)
    INTO COUNT
    FROM ZAPOSLENIK z
    JOIN ODJEL o ON z.ID_ODJEL = o.ID
    WHERE z.ID = P_ID_ZAPOSLENIK AND o.ID_MUZEJ = P_ID_MUZEJ AND z.RADNO_MJESTO = 'Prodavac karata';

    RETURN COUNT > 0;
END //

DELIMITER ;


-- VIEW 

#1 PRIKAZ POPULARNOG MUZEJA

CREATE OR REPLACE VIEW POPULAR_MUZEJ AS
SELECT M.NAZIV AS IME,COUNT(U.ID) AS KOLICINA_ULAZNICA
FROM MUZEJ AS M
INNER JOIN ULAZNICA AS U ON M.ID = U.ID_MUZEJ
GROUP BY M.ID
ORDER BY KOLICINA_ULAZNICA DESC;

SELECT * FROM POPULAR_MUZEJ;

#2 PRIKAZ PROSJECNE OCJENE ZA ODREDENI DOGADAJ  

CREATE OR REPLACE VIEW PROSJECNA_OCJENA_DOGADAJA AS
SELECT ID_DOGADAJ,AVG(ocjena) AS avg_rating
FROM RECENZIJA_DOGADAJ
GROUP BY ID_DOGADAJ;
    
SELECT * FROM PROSJECNA_OCJENA_DOGADAJA;


#3 PRIKAZ SVIH POSJETITELJA KOJI SU KUPILI ULAZNICU 'VIP'

CREATE VIEW POGLED_POSJETITELJ AS 
SELECT POSJETITELJ.ID AS ID, POSJETITELJ.IME AS POSJETITELJ_IME, POSJETITELJ.PREZIME AS POSJETITELJ_PREZIME, POSJETITELJ.BROJ_TELEFONA AS POSJETITELJ_BROJ_TELEFONA, POSJETITELJ.JEZIK AS POSJETITELJ_JEZIK
FROM POSJETITELJ 
INNER JOIN RACUN  ON RACUN.ID_POSJETITELJ = POSJETITELJ.ID
INNER JOIN STAVKA_RACUN  ON STAVKA_RACUN.ID_RACUN = RACUN.ID
INNER JOIN ULAZNICA  ON STAVKA_RACUN.ID_ULAZNICA = ULAZNICA.ID
WHERE ULAZNICA.VRSTA_ULAZNICE = 'VIP'
ORDER BY POSJETITELJ.IME;



SELECT * FROM POGLED_POSJETITELJ;

#4 PRIKAZ RADNIH VREMENA MUZEJA

CREATE VIEW POGLED_RADNOG_VREMENA AS 
SELECT R.DAN_U_TJEDNU AS DAN_U_TJEDNU, R.DATUM_U_TJEDNU AS DATUM_U_TJEDNU, R.POCETAK_RADNOG_VREMENA_RADNI_DANI AS POCETAK_RADNOG_VREMENA_RADNI_DANI, R.ZAVRSETAK_RADNOG_VREMENA_RADNI_DANI AS ZAVRSETAK_RADNOG_VREMENA_RADNI_DANI ,R.POCETAK_RADNOG_VREMENA_NERADNI_DANI AS POCETAK_RADNOG_VREMENA_NERADNI_DANI, R.ZAVRSETAK_RADNOG_VREMENA_NERADNI_DANI 
AS ZAVRSETAK_RADNOG_VREMENA_NERADNI_DANI,M.NAZIV AS NAZIV 
FROM (RADNO_VRIJEME_MUZEJA R JOIN MUZEJ M ON ((M.ID = R.ID_MUZEJ))) 
ORDER  BY M.ID DESC ;

SELECT * FROM POGLED_RADNOG_VREMENA;


#5 PRIKAZ  POGLEDA ULAZNICA I POSJETITELJA 

CREATE VIEW PREGLED_ULAZNICA_I_POSJETITELJA AS 
SELECT  P.IME AS IME,  P.PREZIME AS PREZIME,  P.BROJ_TELEFONA AS BROJ_TELEFONA,  U.VRSTA_ULAZNICE AS VRSTA_ULAZNICE,  R.DATUM AS DATUM_KUPNJE,  M.NAZIV AS NAZIV_MUZEJA
FROM POSJETITELJ P
JOIN RACUN R ON P.ID = R.ID_POSJETITELJ
JOIN STAVKA_RACUN SR ON R.ID = SR.ID_RACUN
JOIN ULAZNICA U ON SR.ID_ULAZNICA = U.ID
JOIN  MUZEJ M ON U.ID_MUZEJ = M.ID;


-- DROP VIEW PREGLED_ULAZNICA_I_POSJETITELJA;
SELECT * FROM PREGLED_ULAZNICA_I_POSJETITELJA;


#6 PRIKAZ   POGLEDA ZAPOSLENIKA KOJE NAZIV RADNOG MJESTA POCINJE SA ZA%

CREATE VIEW POGLED_ZAPOSLENIK AS 
SELECT  ID , IME, PREZIME, JEZICI, RADNO_MJESTO, DATUM_ZAPOSLENJA, PLACA, ID_ODJEL 
FROM ZAPOSLENIK 
WHERE ZAPOSLENIK.ID_ODJEL IN (SELECT ODJEL.ID FROM ODJEL WHERE (ZAPOSLENIK.RADNO_MJESTO LIKE 'Za%')) ;

SELECT * FROM POGLED_ZAPOSLENIK;

#7 PRIKAZ POGLEDA SVIH EKSPONATA I UMJENTIKA 

CREATE VIEW POGLED_SVIH_EKSPONENATA_UMJETNIKA AS 
SELECT EKSPONAT.NAZIV AS NAZIV_EKSPONAT, EKSPONAT.OPIS AS OPIS_EKSPONAT , UMJETNIK.IME AS IME_UMJETNIKA, UMJETNIK.NAZIVI AS PUNI_NAZIV_UMJETNIKA
FROM EKSPONAT 
INNER JOIN UMJETNIK ON UMJETNIK.ID = EKSPONAT.ID_UMJETNIK; 

SELECT * FROM POGLED_SVIH_EKSPONENATA_UMJETNIKA;

#8 PRIKAZ OCJENA ZA ODREĐENU IZLOŽBU I KOMENTAR

CREATE VIEW PRIKAZ_OCJENA_ZA_IZLOZBU AS
SELECT DOGADAJ.NAZIV AS NAZIV_IZLOZBE, RECENZIJA_DOGADAJ.OCJENA AS OCJENA, RECENZIJA_DOGADAJ.KOMENTAR AS KOMENTAR, POSJETITELJ.IME AS IME_POSJETITELJA, POSJETITELJ.PREZIME AS PREZIME_POSJETITELJ
FROM DOGADAJ 
JOIN RECENZIJA_DOGADAJ  ON DOGADAJ.ID = RECENZIJA_DOGADAJ.ID_DOGADAJ
JOIN POSJETITELJ  ON RECENZIJA_DOGADAJ.ID_POSJETITELJ = POSJETITELJ.ID;
 
 SELECT * FROM PRIKAZ_OCJENA_ZA_IZLOZBU WHERE NAZIV_IZLOZBE = 'Izložba A';

#9 PRIKAZ ZA UKUPNU PRODAJU PO GODINAMA
CREATE VIEW UKUPNA_PRODAJA_PO_GODINAMA AS
SELECT  YEAR(DATUM) AS Godina, SUM(IZNOS) AS UKUPNA_PRODAJA
FROM  RACUN
GROUP BY YEAR(DATUM);

SELECT * FROM UKUPNA_PRODAJA_PO_GODINAMA;


#10 PRIKAZ ZA UKUPNE TROSKOVE PLACA PO GODINAMA NA TEMELJU DATUMA ZAPOSLENJA 
CREATE VIEW UKUPNI_TROSKOVI_PLACA_PO_GODINAMA  AS
SELECT YEAR(DATUM_ZAPOSLENJA) AS Godina, SUM(PLACA * 12) AS UKUPNI_TROSKOVI_PLACA  
FROM ZAPOSLENIK
GROUP BY YEAR(DATUM_ZAPOSLENJA);

SELECT * FROM UKUPNI_TROSKOVI_PLACA_PO_GODINAMA;

#11 PRIKAZ ZA PROFIT PO GODINAMA  
CREATE VIEW PROFIT_PO_GODINAMA AS
SELECT UKUPNA_PRODAJA_PO_GODINAMA.GODINA, UKUPNA_PRODAJA_PO_GODINAMA.UKUPNA_PRODAJA,
COALESCE(UKUPNI_TROSKOVI_PLACA_PO_GODINAMA.UKUPNI_TROSKOVI_PLACA, 0) AS UKUPNI_TROSKOVI_PLACA, 
(UKUPNA_PRODAJA_PO_GODINAMA.UKUPNA_PRODAJA - COALESCE(UKUPNI_TROSKOVI_PLACA_PO_GODINAMA.UKUPNI_TROSKOVI_PLACA, 0)) AS PROFIT
FROM UKUPNA_PRODAJA_PO_GODINAMA 
LEFT JOIN UKUPNI_TROSKOVI_PLACA_PO_GODINAMA  ON UKUPNA_PRODAJA_PO_GODINAMA.GODINA = UKUPNI_TROSKOVI_PLACA_PO_GODINAMA.GODINA;

SELECT * FROM PROFIT_PO_GODINAMA;

-- TRIGGER

#1 TRIGGER ZA  SPRIJECAVANJE UMETANJE PODATAKA U FINALIZIRANI RACUN

drop trigger SPRIJECAVANJE_UMETANJE_PODATAKA_U_FINALIZIRANI_RACUN;
DELIMITER //

CREATE TRIGGER SPRIJECAVANJE_UMETANJE_PODATAKA_U_FINALIZIRANI_RACUN
BEFORE INSERT ON RACUN
FOR EACH ROW
BEGIN
    IF NEW.IZNOS IS NOT NULL AND NEW.STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ne može se umetnuti u finalizirani RACUN.';
    END IF;
END //

DELIMITER ;

#2 TRIGGER ZA SPRIJECAVANJE AZURIRANJA NA FINALIZIRANI RACUN
drop trigger SPRIJECAVANJE_AZURIRANJA_NA_FINALIZIRANI_RACUN;
DELIMITER //


CREATE TRIGGER SPRIJECAVANJE_AZURIRANJA_NA_FINALIZIRANI_RACUN
BEFORE UPDATE ON RACUN
FOR EACH ROW
BEGIN
    IF OLD.IZNOS IS NOT NULL AND OLD.STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nije moguće ažurirati finalizirani RACUN.';
    END IF;
END //

DELIMITER ;

#3 TRIGGER ZA SPRIJECAVANJE BRISANJA U FINALIZIRANI RACUN
drop trigger SPRIJECAVANJE_BRISANJA_U_FINALIZIRANI_RACUN;
DELIMITER //

CREATE TRIGGER SPRIJECAVANJE_BRISANJA_U_FINALIZIRANI_RACUN
BEFORE DELETE ON RACUN
FOR EACH ROW
BEGIN
    IF OLD.IZNOS IS NOT NULL AND OLD.STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nije moguće izbrisati finalizirani RACUN.';
    END IF;
END //

DELIMITER ;

#4 TRIGGER ZA PROVJERA PROMJENA STATUSA
drop trigger PROVJERA_PROMJENA_STATUSA;

DELIMITER //

CREATE TRIGGER PROVJERA_PROMJENA_STATUSA
BEFORE UPDATE ON RACUN
FOR EACH ROW
BEGIN
    IF OLD.STATUS_RACUNA = 'F' AND NEW.STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Promjena statusa iz "F" u "T" nije dopuštena.';
    END IF;
END //

DELIMITER ;


drop trigger PROVJERA_KOLIKO_JE_ZAPOSLENIK_STORNIRAO_RACUNA;

#5 TRIGGER PROVJERA_KOLIKO_JE_ZAPOSLENIK_STORNIRAO_RACUNA
 DELIMITER //

CREATE TRIGGER PROVJERA_KOLIKO_JE_ZAPOSLENIK_STORNIRAO_RACUNA 
BEFORE UPDATE ON RACUN
FOR EACH ROW
BEGIN
    DECLARE PREKID INT;


    IF NEW.STATUS_RACUNA = 'F' THEN
        
        SELECT COUNT(*) INTO PREKID
        FROM RACUN
        WHERE ID_ZAPOSLENIK = NEW.ID_ZAPOSLENIK
        AND STATUS_RACUNA = 'F'
        AND DATE(DATUM) = CURDATE();

   
        IF PREKID >= 10 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Zaposlenik ne može stornirati više od 10 računa dnevno.';
        END IF;
    END IF;
END //

DELIMITER ;

#6 TRIGGER ZA UMETANJE EKSPONATA NA DOGADAJ U INSERTU 

DELIMITER //

CREATE TRIGGER PROVJERA_EKSPONATA_NA_DOGADAJU_U_INSERT
BEFORE INSERT ON EKSPONAT_NA_DOGADAJ
FOR EACH ROW
BEGIN
    DECLARE T_DATUM_POCETKA DATE;
    DECLARE T_DATUM_ZAVRSETKA DATE;


    SELECT DATUM_POCETKA, DATUM_ZAVRSETKA INTO T_DATUM_POCETKA, T_DATUM_ZAVRSETKA
    FROM DOGADAJ
    WHERE ID = NEW.ID_DOGADAJ;


    CALL PROVJERI_EKSPONAT_NA_DOGADAJU(NEW.ID_EKSPONAT, T_DATUM_POCETKA, T_DATUM_ZAVRSETKA);
END //

DELIMITER ;

#7 TRIGGER ZA PROVJERU EKSPONENATA NA DOGADAJU UPDATE

DELIMITER //

CREATE TRIGGER PROVJERU_EKSPONENATA_NA_DOGADAJU_UPDATE
BEFORE UPDATE ON EKSPONAT_NA_DOGADAJ
FOR EACH ROW
BEGIN
    DECLARE T_DATUM_POCETKA DATE;
    DECLARE T_DATUM_ZAVRSETKA DATE;

    
    SELECT DATUM_POCETKA, DATUM_ZAVRSETKA INTO T_DATUM_POCETKA, T_DATUM_ZAVRSETKA
    FROM DOGADAJ
    WHERE ID = NEW.ID_DOGADAJ;


    CALL PROVJERI_EKSPONAT_NA_DOGADAJU(NEW.ID_EKSPONAT, T_DATUM_POCETKA, T_DATUM_ZAVRSETKA);
END //

DELIMITER ;

#8 TRIGGER  ZA PROVJERA ZAPOSLENIKA PRIJE INSERTA 

DELIMITER //

CREATE TRIGGER PROVJERA_ZAPOSLENIKA_PRIJE_INSERTA 
BEFORE INSERT ON RACUN
FOR EACH ROW
BEGIN
    DECLARE T_RADNO_MJESTO VARCHAR(100);

    SELECT RADNO_MJESTO INTO T_RADNO_MJESTO
    FROM ZAPOSLENIK
    WHERE ID = NEW.ID_ZAPOSLENIK;

    IF V_RADNO_MJESTO <> 'Pomocni poslovi' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Zaposlenik mora raditi na mjestu "Pomocni poslovi".';
    END IF;
END //

DELIMITER ;

#9 TRIGGER ZA PROVJERU ZAPOSLENIKA PRIJE UPDEJTANJA

DELIMITER //

CREATE TRIGGER PROVJERU_ZAPOSLENIKA_PRIJE_UPDEJTANJA
BEFORE UPDATE ON RACUN
FOR EACH ROW
BEGIN
    DECLARE T_RADNO_MJESTO VARCHAR(100);

    SELECT RADNO_MJESTO INTO T_RADNO_MJESTO
    FROM ZAPOSLENIK
    WHERE ID = NEW.ID_ZAPOSLENIK;

    IF T_RADNO_MJESTO <> 'Pomocni poslovi' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Zaposlenik mora raditi na mjestu "Pomocni poslovi".';
    END IF;
END //

DELIMITER ;

#10 TRIGGER ZA PROVJERU PRIJE INSERTA STAVKE RACUNA 

DELIMITER //

CREATE TRIGGER PROVJERA_PRIJE_INSERT_STAVKA_RACUN
BEFORE INSERT ON STAVKA_RACUN
FOR EACH ROW
BEGIN
    DECLARE T_STATUS_RACUNA CHAR(1);

    SELECT STATUS_RACUNA INTO T_STATUS_RACUNA
    FROM RACUN
    WHERE ID = NEW.ID_RACUN;

    IF T_STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nije dopušteno dodavati stavke jer je račun zaključen.';
    END IF;
END //

DELIMITER ;

#11 TRIGGER ZA PRIJE UPDEJTANJA STAVKE RACUNA

DELIMITER //

CREATE TRIGGER PROVJERA_PRIJE_UPDATE_STAVKA_RACUN
BEFORE UPDATE ON STAVKA_RACUN
FOR EACH ROW
BEGIN
    DECLARE T_STATUS_RACUNA CHAR(1);

    SELECT STATUS_RACUNA INTO T_STATUS_RACUNA
    FROM RACUN
    WHERE ID = OLD.ID_RACUN;

    IF T_STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nije dopušteno ažurirati stavke jer je račun zaključen.';
    END IF;
END //

DELIMITER ;

#12 TRIGGER ZA PRIJE "DELETE" TABLICE STAVKE_RACUNA

DELIMITER //

CREATE TRIGGER PROVJERA_PRIJE_DELETE_STAVKA_RACUN
BEFORE DELETE ON STAVKA_RACUN
FOR EACH ROW
BEGIN
    DECLARE T_STATUS_RACUNA CHAR(1);

    SELECT STATUS_RACUNA INTO T_STATUS_RACUNA
    FROM RACUN
    WHERE ID = OLD.ID_RACUN;

    IF V_STATUS_RACUNA = 'T' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nije dopušteno brisati stavke jer je račun zaključen.';
    END IF;
END //

DELIMITER ;

-- UPIT

#1 PRIKAZUJE NAZIVE I PROSJECNE OCJENE TOP 5 PO DOGADAJA 
SELECT DOGADAJ.NAZIV NAZIV_IZLOZBE, SUM(RECENZIJA_DOGADAJ.OCJENA) AS PROSJECNA_OCJENA
FROM DOGADAJ
INNER JOIN RECENZIJA_DOGADAJ ON DOGADAJ.ID = RECENZIJA_DOGADAJ.ID_DOGADAJ
GROUP BY DOGADAJ.NAZIV
LIMIT 5;

#2 PRIKAZUJE NAZIVE MUZEJA I BROJ POSJETITELJA ZA SVAKI MUZEJ 
SELECT MUZEJ.NAZIV AS NAZIV_MUZEJA,COUNT(DISTINCT RACUN.ID_POSJETITELJ) AS BROJ_POSJETITELJA
FROM MUZEJ 
JOIN ULAZNICA  ON MUZEJ.ID = ULAZNICA.ID_MUZEJ
JOIN STAVKA_RACUN  ON ULAZNICA.ID = STAVKA_RACUN.ID_ULAZNICA
JOIN RACUN  ON STAVKA_RACUN.ID_RACUN = RACUN.ID
GROUP BY MUZEJ.NAZIV;


#3 PRIKAZUJE SVE ZAPOSLENIKE KOJI SU ZAPOSLENI DULJE OD 2 GODINE OD NAJSTARIJEG PREMA NAJMLAĐEM 

SELECT IME, PREZIME, DATUM_ZAPOSLENJA 
FROM ZAPOSLENIK
WHERE DATUM_ZAPOSLENJA < NOW() - INTERVAL 2 YEAR
ORDER BY DATUM_ZAPOSLENJA ASC;

#4 PRIKAZUJE SVE MUZEJE, VRSTE TIH MUZEJA I MJESTO 

SELECT m.NAZIV , m.VELICINA , m.ADRESA, v.VRSTA , v.DETALJNIJE, v.KOD, mm.MJESTO , mm.POSTANSKI_BROJ
 FROM MUZEJ AS m
    INNER JOIN VRSTA_MUZEJA AS v ON v.id = m.ID_VRSTA_MUZEJA
    INNER JOIN LOKACIJA AS mm ON mm.id = m.ID_LOKACIJA
    ORDER BY m.ID asc;
    
#5 PRIKAZUJE SVE EKSPONATE, SASTAV I MATERIJAL EKSPONATA
 
 SELECT se.kolicina AS KOLICINA_EKSPONAT, SE.OPIS AS OPIS_EKSPONAT, SE.TEZINA AS TEZINA_EKSPONAT, e.naziv AS NAZIV_EKSPONAT, 
        E.OPIS AS OPIS_EKSPONAT_PERIOD, E.GODINA AS PERIOD_NASTANKA_EKSPONAT , EM.DIMENZIJA AS    DIMENZIJA_EKSPONATT, 
        EM.VRSTA AS VRSTA_EKSPONAT, EM.KLASIFIKACIJA AS KLASIFIKACIJA_EKSPONAT
 FROM SASTAV_EKSPONAT se
 INNER JOIN EKSPONAT e ON e.id= se.ID_EKSPONAT
 INNER JOIN EKSPONAT_MATERIJAL em ON em.ID = se.ID_EKSPONAT_MATERIJAL
 WHERE em.VRSTA = 'Gold'
 ORDER BY SE.KOLICINA DESC;
 
 
#6 PRIKAZUJE SVE DOGADJE I JEDNOG POSJETITELJA KOJI JE OBJAVIO KOMENTAR NA POJEDINOM DOGADAJU 
 
SELECT D.*, P.*
 FROM DOGADAJ AS D, POSJETITELJ AS P
 WHERE P.ID = ( SELECT ID_POSJETITELJ
				 FROM RECENZIJA_DOGADAJ
                 WHERE ID_DOGADAJ = D.ID
                 GROUP BY ID_DOGADAJ, ID_POSJETITELJ
                 ORDER BY COUNT(*) desc
                 LIMIT 1);
    



SELECT D.*, P.*
FROM DOGADAJ D
JOIN ( SELECT ID_DOGADAJ, ID_POSJETITELJ
        FROM RECENZIJA_DOGADAJ RD1
        WHERE ID_POSJETITELJ = ( SELECT ID_POSJETITELJ
                                 FROM RECENZIJA_DOGADAJ RD2
                                 WHERE RD2.ID_DOGADAJ = RD1.ID_DOGADAJ
								 GROUP BY ID_POSJETITELJ
                                 ORDER BY COUNT(*) DESC
                                 LIMIT 1)
    ) AS TOP_RECENZIJA
    ON D.ID = TOP_RECENZIJA.ID_DOGADAJ
JOIN 
    POSJETITELJ P 
    ON TOP_RECENZIJA.ID_POSJETITELJ = P.ID;

#7 PRIKAZUJE PROSJEK CIJENA ULAZNICA PO VRSTI ULAZNICE  
SELECT u.VRSTA_ULAZNICE, AVG(u.CIJENA_ULAZNICE) AS PROSJECNA_CIJENA
FROM ULAZNICA u
GROUP BY u.VRSTA_ULAZNICE;

#8 PRIKAZUJE BROJ EKSPONATA PO MUZJEU I VRSTI EKSPONATA 
SELECT m.NAZIV AS MUZEJ, vm.VRSTA AS VRSTA_MUZEJA, COUNT(e.ID) AS BROJ_EKSPONATA
FROM MUZEJ m
INNER JOIN VRSTA_MUZEJA vm ON m.ID_VRSTA_MUZEJA = vm.ID
LEFT JOIN EKSPONAT e ON m.ID = e.ID_MUZEJ
GROUP BY m.NAZIV, vm.VRSTA;    

#9 PRIKAZUJE BROJ POSJETITELJA PO JEZIKU I ODJELU 
SELECT  POSJETITELJ.JEZIK AS JEZIK_POSJETITELJA, ODJEL.NAZIV AS NAZIV_ODJELA, COUNT(DISTINCT RACUN.ID_POSJETITELJ) AS BROJ_POSJETITELJA
FROM POSJETITELJ 
JOIN  RACUN  ON POSJETITELJ.ID = RACUN.ID_POSJETITELJ
JOIN ZAPOSLENIK  ON RACUN.ID_ZAPOSLENIK = ZAPOSLENIK.ID
JOIN  ODJEL  ON ZAPOSLENIK.ID_ODJEL = ODJEL.ID
GROUP BY  POSJETITELJ.JEZIK,  ODJEL.NAZIV;


#10 PRIKAZUJE TOP 3 UMJETNIKA S NAJVISE EKSPONATA 
SELECT u.IME AS Umjetnik, COUNT(e.ID) AS BROJ_EKSPONATA
FROM UMJETNIK u
LEFT JOIN EKSPONAT e ON u.ID = e.ID_UMJETNIK
GROUP BY u.IME
ORDER BY BROJ_EKSPONATA DESC
LIMIT 3;

#11 PRIKAZUJE ZA POSJETITELJA KOJI IMA NAJVISE KARATA ORDER  DESC 
SELECT p.ID AS Posjetitelj_ID, p.IME AS Ime, p.PREZIME AS Prezime, COUNT(u.ID) AS BrojKupovina
FROM POSJETITELJ p
JOIN RACUN r ON p.ID = r.ID_POSJETITELJ
JOIN STAVKA_RACUN sr ON r.ID = sr.ID_RACUN
JOIN ULAZNICA u ON sr.ID_ULAZNICA = u.ID
GROUP BY p.ID, p.IME, p.PREZIME
ORDER BY BrojKupovina DESC;

