DROP DATABASE IF EXISTS MUZEJI;
CREATE DATABASE MUZEJI; 
USE MUZEJI;
 
CREATE TABLE LOKACIJA(
  ID  INTEGER  PRIMARY KEY,
  MJESTO VARCHAR(50),   
  POSTANSKI_BROJ INTEGER UNIQUE
);



 CREATE TABLE VRSTA_MUZEJA(
  ID INTEGER  PRIMARY KEY,
  VRSTA VARCHAR(100),
  DETALJNIJE VARCHAR(100),
  KOD INTEGER,
  CHECK (KOD >= 0)
  );
 

 CREATE TABLE MUZEJ(
  ID INTEGER  PRIMARY KEY,
  NAZIV VARCHAR(100) UNIQUE  NOT NULL,
  OSNOVAN VARCHAR(100),
  VELICINA VARCHAR(50),
  ADRESA VARCHAR(100)  NOT NULL,
  ID_LOKACIJA INTEGER  NOT NULL,
  ID_VRSTA_MUZEJA INTEGER  NOT NULL,
  FOREIGN KEY (ID_LOKACIJA) REFERENCES LOKACIJA (ID),
  FOREIGN KEY (ID_VRSTA_MUZEJA) REFERENCES VRSTA_MUZEJA (ID),
  CHECK (VELICINA IN ('small', 'medium', 'large'))
 );

  

CREATE TABLE RADNO_VRIJEME_MUZEJA(
 ID INTEGER  PRIMARY KEY,
 DAN_U_TJEDNU VARCHAR(20), 
 DATUM_U_TJEDNU DATE, 
 POCETAK_RADNOG_VREMENA_RADNI_DANI TIME,
 ZAVRSETAK_RADNOG_VREMENA_RADNI_DANI TIME,
 POCETAK_RADNOG_VREMENA_NERADNI_DANI TIME,
 ZAVRSETAK_RADNOG_VREMENA_NERADNI_DANI TIME,
 ID_MUZEJ INTEGER  NOT NULL,
 FOREIGN KEY (ID_MUZEJ) REFERENCES MUZEJ (ID),
 CHECK (ZAVRSETAK_RADNOG_VREMENA_RADNI_DANI > POCETAK_RADNOG_VREMENA_RADNI_DANI ),
 CHECK (ZAVRSETAK_RADNOG_VREMENA_NERADNI_DANI > POCETAK_RADNOG_VREMENA_NERADNI_DANI )

 );

 CREATE TABLE POSJETITELJ(
  ID INTEGER  PRIMARY KEY,
  IME VARCHAR(100)  NOT NULL,
  PREZIME VARCHAR(100)  NOT NULL,
  BROJ_TELEFONA VARCHAR(100) UNIQUE,
  JEZIK VARCHAR(100)
  );
 


 CREATE TABLE ULAZNICA(
 ID INTEGER  PRIMARY KEY,
 CIJENA_ULAZNICE INTEGER,
 VRSTA_ULAZNICE VARCHAR(20),
 ID_MUZEJ INTEGER  NOT NULL,
 FOREIGN KEY (ID_MUZEJ) REFERENCES MUZEJ (ID),
 CHECK (VRSTA_ULAZNICE IN ('VIP', 'Grupna', 'Osnovna')),
 CHECK (CIJENA_ULAZNICE BETWEEN 20.00 AND 50.00)
 );
 
   CREATE TABLE ODJEL(
   ID INTEGER  PRIMARY KEY,
   NAZIV VARCHAR(100) UNIQUE,
   OPIS VARCHAR(100), 
   SPECIJALNOST VARCHAR(100), 
   ID_MUZEJ INTEGER  NOT NULL,
   FOREIGN KEY (ID_MUZEJ) REFERENCES MUZEJ (ID)
   );
 
CREATE TABLE ZAPOSLENIK (
    ID INTEGER PRIMARY KEY, 
    IME VARCHAR(100),
    PREZIME VARCHAR(100),
    JEZICI VARCHAR(100),
    RADNO_MJESTO VARCHAR(100)  NOT NULL,
    DATUM_ZAPOSLENJA DATE  NOT NULL,
    PLACA DECIMAL(10, 2),
    ID_ODJEL INTEGER  NOT NULL,
    FOREIGN KEY (ID_ODJEL) REFERENCES ODJEL(ID),
    CHECK (RADNO_MJESTO IN ('Cistacica', 'Zastitar', 'Znanstvenik', 'Vodić', 'Prodavac karata')), 
    CHECK (DATUM_ZAPOSLENJA >=  SYSDATE()  - INTERVAL 50 YEAR), 
    CHECK (PLACA BETWEEN 25000 AND 80000)
);

CREATE TABLE RACUN(
ID INTEGER  PRIMARY KEY,
ID_ZAPOSLENIK INTEGER  NOT NULL,
DATUM DATE,
ID_POSJETITELJ INTEGER  NOT NULL,
IZNOS INTEGER,
STATUS_RACUNA VARCHAR(1), 
FOREIGN KEY (ID_ZAPOSLENIK) REFERENCES ZAPOSLENIK (ID),
FOREIGN KEY (ID_POSJETITELJ) REFERENCES POSJETITELJ (ID),
CHECK (DATUM >= SYSDATE()),
CHECK (STATUS_RACUNA IN ('T','F'))
);


CREATE TABLE STAVKA_RACUN(
 ID INTEGER  PRIMARY KEY,
 ID_RACUN INTEGER   NOT NULL,
 ID_ULAZNICA INTEGER   NOT NULL,
 KOLICINA INTEGER,
UNIQUE (ID_RACUN, ID_ULAZNICA), 
FOREIGN KEY (ID_RACUN) REFERENCES RACUN (ID),
FOREIGN KEY (ID_ULAZNICA) REFERENCES ULAZNICA (ID),
CHECK (KOLICINA > 0 AND KOLICINA <= 100)
);

 

 CREATE TABLE DOGADAJ(
  ID INTEGER  PRIMARY KEY,
  NAZIV VARCHAR(100)  NOT NULL,
  DOGADAJ_IZLOZBA VARCHAR(10),
  DATUM_POCETKA DATE, 
  DATUM_ZAVRSETKA DATE,
  OPIS TEXT,
  ID_MUZEJ INTEGER  NOT NULL,
  FOREIGN KEY (ID_MUZEJ) REFERENCES MUZEJ (ID),
  CONSTRAINT chk_datum_pocetak_zavrsetka CHECK (DATUM_ZAVRSETKA >= DATUM_POCETKA));
 
 

CREATE TABLE PROSTORIJA(
ID INTEGER  PRIMARY KEY,
BROJ_SOBE VARCHAR(100) UNIQUE,
NAZIV_SOBE VARCHAR(100) UNIQUE,
ID_ODJEL INTEGER  NOT NULL,
FOREIGN KEY (ID_ODJEL) REFERENCES ODJEL (ID)
);


    

CREATE TABLE RECENZIJA_DOGADAJ(
  ID INTEGER  PRIMARY KEY,
  KOMENTAR TEXT,
  OCJENA INTEGER, 
  ID_POSJETITELJ INTEGER  NOT NULL,
  ID_DOGADAJ INTEGER  NOT NULL,
  FOREIGN KEY (ID_POSJETITELJ) REFERENCES POSJETITELJ (ID),
  FOREIGN KEY (ID_DOGADAJ) REFERENCES DOGADAJ (ID),
  CHECK (OCJENA BETWEEN 1 AND 5));
  
  
 CREATE TABLE PERIOD_EKSPONATA(
  ID INTEGER  PRIMARY KEY,
  DINASTIJA VARCHAR(100),
  PERIOD VARCHAR(100),
  KULTURA VARCHAR(100),
  VLADAVINA VARCHAR(100)
  );
  
  
  CREATE TABLE UMJETNIK(
  ID INTEGER  PRIMARY KEY,
  ULOGA TEXT,
  IME TEXT,
  NAZIVI TEXT,
  NACIONALNOST TEXT,
  POCETAK_DATUM TEXT,
  KRAJ_DATUM TEXT,
  CHECK (POCETAK_DATUM <= KRAJ_DATUM),
  CHECK (ULOGA IN ('Artist', 'Factory','Factory director','Modeler', 'Maker', '0','Manufacturer', 'Designer', 'Retailer', 'Printer', 'Publisher', 'Manufacturer' ))

  );
  
  
 CREATE TABLE EKSPONAT_MATERIJAL(
  ID INTEGER PRIMARY KEY,
  DIMENZIJA TEXT,
  VRSTA TEXT,
  KLASIFIKACIJA TEXT,
  CHECK (VRSTA IN ('Gold', 'Silver', 'Bronze', 'Wood', 'Stone', 'Glass'))
  );
 
 
  CREATE TABLE EKSPONAT(
   ID INTEGER  PRIMARY KEY,
   NAZIV VARCHAR(100),
   OPIS TEXT, 
   GODINA INT,
   ID_UMJETNIK INTEGER  NOT NULL,
   ID_PERIOD INTEGER  NOT NULL,
   ID_MUZEJ INTEGER  NOT NULL,
   FOREIGN KEY (ID_UMJETNIK) REFERENCES UMJETNIK (ID),
   FOREIGN KEY (ID_PERIOD) REFERENCES PERIOD_EKSPONATA (ID),
   FOREIGN KEY (ID_MUZEJ) REFERENCES MUZEJ (ID),
   CHECK (GODINA >= 1000 AND GODINA <= YEAR(SYSDATE()))
   );

 CREATE TABLE SASTAV_EKSPONAT(
  ID INTEGER  PRIMARY KEY,
  NAZIV VARCHAR(100),
  KOLICINA INTEGER,
  OPIS VARCHAR(400),
  TEZINA INTEGER, 
  ID_EKSPONAT_MATERIJAL INTEGER NOT NULL ,
  ID_EKSPONAT INTEGER NOT NULL, 
  FOREIGN KEY (ID_EKSPONAT_MATERIJAL) REFERENCES EKSPONAT_MATERIJAL (ID),
  FOREIGN KEY (ID_EKSPONAT) REFERENCES EKSPONAT (ID),
  CHECK (KOLICINA BETWEEN 1 AND 10),
  CHECK (TEZINA BETWEEN 0.1 AND 10.0));

   
CREATE TABLE  EKSPONAT_NA_DOGADAJ(
ID INTEGER  PRIMARY KEY,
ID_DOGADAJ INTEGER  NOT NULL,
ID_EKSPONAT INTEGER  NOT NULL,
FOREIGN KEY (ID_EKSPONAT) REFERENCES EKSPONAT (ID),
FOREIGN KEY (ID_DOGADAJ) REFERENCES DOGADAJ (ID)

);




