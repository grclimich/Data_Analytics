
   ################################################################################################################################################################################################################################################################################################# 
    #NIVEL 1
    
    #Exercici 1
    
    # 1.1 creamos la base de datos transactions
    CREATE DATABASE IF NOT EXISTS transactions;
    USE transactions;

    -- Creamos la tabla company
    CREATE TABLE IF NOT EXISTS company (
        id VARCHAR(15) PRIMARY KEY,
        company_name VARCHAR(255),
        phone VARCHAR(15),
        email VARCHAR(100),
        country VARCHAR(100),
        website VARCHAR(255)
    );
    
    -- Creamos la tabla transaction
    CREATE TABLE IF NOT EXISTS transaction (
        id VARCHAR(255) PRIMARY KEY,
        credit_card_id VARCHAR(15) REFERENCES credit_card(id),
        company_id VARCHAR(20), 
        user_id INT REFERENCES user(id),
        lat FLOAT,
        longitude FLOAT,
        timestamp TIMESTAMP,
        amount DECIMAL(10, 2),
        declined BOOLEAN,
        FOREIGN KEY (company_id) REFERENCES company(id) 
    );
    
#Exercici 2
#Utilitzant JOIN realitzaràs les següents consultes:

# 2.1 Llistat dels països que estan generant vendes.
SELECT DISTINCT(co.country) AS paises_ventas
FROM company AS co
JOIN transaction AS tr ON tr.company_id=co.id
WHERE tr.declined = 0 AND tr.amount > 0;


# 2.2 Des de quants països es generen les vendes.
SELECT COUNT(DISTINCT co.country) AS nro_paises_ventas
FROM company AS co
INNER JOIN transaction AS tr ON tr.company_id=co.id
WHERE tr.declined = 0 AND tr.amount>0;


# 2.3 Identifica la companyia amb la mitjana més gran de vendes.
SELECT co.company_name AS empresa, ROUND(AVG(tr.amount),2) as media_ventas
FROM company AS co
JOIN transaction as tr ON tr.company_id=co.id
WHERE tr.declined = 0
GROUP BY co.id
ORDER BY media_ventas DESC
LIMIT 1;



#Exercici 3
#Utilitzant només subconsultes (sense utilitzar JOIN):


# 3.1 Mostra totes les transaccions realitzades per empreses d'Alemanya.
SELECT *
FROM transaction AS tr
WHERE EXISTS (
	SELECT id
	FROM company 
	WHERE country='Germany'
    AND id=tr.company_id # y relacionamos los id de company
    );


# 3.2 Llista les empreses que han realitzat transaccions per un amount superior a la mitjana de totes les transaccions.
SELECT co.company_name, AVG(amount) AS media_ventas
FROM transaction AS tr
JOIN company AS co ON co.id=tr.company_id
WHERE tr.declined = 0 
AND tr.amount > (
					SELECT AVG(amount) AS media_ventas
					FROM transaction
                    WHERE declined = 0
                    )
GROUP BY tr.company_id
ORDER BY media_ventas DESC;

#confirmamos la media de ventas = 258.91
SELECT AVG(amount) AS media_ventas
FROM transaction WHERE declined = 0;


# 3.3 Eliminaran del sistema les empreses que no tenen transaccions registrades, entrega el llistat d'aquestes empreses.
SELECT company_name AS empresas
FROM company AS co
WHERE NOT EXISTS (
    SELECT tr.company_id
    FROM transaction AS tr
    WHERE tr.company_id IS NOT NULL #busca todos los id que no esten vacios
);


#Exercici 4
#  La teva tasca és dissenyar i crear una taula anomenada "credit_card" que emmagatzemi detalls crucials sobre les targetes de crèdit.
#La nova taula ha de ser capaç d'identificar de manera única cada targeta i establir una relació adequada amb les altres dues taules
#("transaction" i "company"). Després de crear la taula serà necessari que ingressis la informació del document denominat "dades_introduir_credit". 
#Recorda mostrar el diagrama i realitzar una breu descripció d'aquest.

	CREATE TABLE IF NOT EXISTS credit_card (
    id VARCHAR(15) PRIMARY KEY,
    iban VARCHAR(255),
    pan VARCHAR(255),
    pin VARCHAR(10),
    cvv VARCHAR(10),
    expiring_date VARCHAR(50)
);

#convertir de texto varchar a formato fecha
UPDATE credit_card 
SET expiring_date = STR_TO_DATE(expiring_date, '%m/%d/%y')
LIMIT 999999;
#convertir a date
ALTER TABLE credit_card MODIFY COLUMN expiring_date DATE;
     

#Exercici 5
#El departament de Recursos Humans ha identificat un error en el número de compte associat a la targeta de crèdit 
#amb ID CcU-2938. La informació que ha de mostrar-se per a aquest registre és: TR323456312213576817699999. 

SELECT *
FROM transaction AS tr
JOIN credit_card AS cr ON cr.id=tr.credit_card_id
WHERE credit_card_id='CcU-2938';

#Actualizamos el iban
UPDATE credit_card
SET iban='TR323456312213576817699999'
WHERE id='CcU-2938' AND iban = 'TR301950312213576817638661';

#Exercici 6
#  En la taula "transaction" ingressa una nova transacció amb la següent informació:
#Id 108B1D1D-5B23-A76C-55EF-C568E49A99DD, credit_card_id CcU-9999, company_id b-9999, 
#user_id 9999, lat 829.999, longitude -117.999, amount 111.11, declined 0 

#hacemos insert en company
INSERT INTO company(id)VALUES('b-9999');
#hacemos insert en credit card
INSERT INTO credit_card(id,iban)VALUES('CcU-9999','108B1D1D-5B23-A76C-55EF-C568E49A99DD');
# ahora que lo tenemos en ambas tablas insertamos en transactions
INSERT INTO transaction(
id,credit_card_id,company_id,user_id,lat,longitude,amount,timestamp,declined)
VALUES('108B1D1D-5B23-A76C-55EF-C568E49A99DD','CcU-9999','b-9999','9999','829.999','-117.999','111.11',CURRENT_TIMESTAMP,'0' );
#comprobamos
SELECT *
FROM transaction
WHERE credit_card_id='CcU-9999';


#Exercici 7
#Des de recursos humans et sol·liciten eliminar la columna "pan" de la taula credit_card.
#Recorda mostrar el canvi realitzat.

ALTER TABLE credit_card
DROP COLUMN pan;
#comprobamos
SELECT *
FROM credit_card;


# 8)Estudia y diseña una base de datos con un esquema de estrella que contenga, 
#al menos 4 tablas de las que puedas realizar las siguientes consultas:

#Antes que nada, hacemos exploración de los datos, de cada csv, columnas, tablas etc.
#Vamos a crear 2 bases de datos, una para la fase staging que funcionara como backup 'data' 
#y la segunda donde iran las dimensiones y tabla de hechos 'bank_transactions'

#CREAMOS EL SCHEMA data donde estaran almacenadas nuestras tablas de carga y backup
CREATE SCHEMA IF NOT EXISTS data;

USE data;

# Empezaremos con las tablas de la fase staging 
#creamos la tabla users
CREATE TABLE IF NOT EXISTS data.staging_users (
    id INT,
    name VARCHAR(255),
    surname VARCHAR(255),
    phone VARCHAR(255),
    email VARCHAR(255),
    birth_date VARCHAR(50),
    country VARCHAR(255),
    city VARCHAR(255),
    postal_code VARCHAR(255),
    address VARCHAR(255),
    signup_date VARCHAR(50),
    user_segment VARCHAR(255),
    income_band VARCHAR(255)
);

#creamos la tabla companies
CREATE TABLE IF NOT EXISTS data.staging_companies (
    company_id VARCHAR(20),
    company_name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    country VARCHAR(255),
    website VARCHAR(255),
    merchant_category VARCHAR(255),
    merchant_price_position VARCHAR(255)
);

#creamos la tabla credit cards
CREATE TABLE IF NOT EXISTS data.staging_credit_cards (
    id VARCHAR(15),
    user_id INT,
    iban VARCHAR(255),
    pan VARCHAR(255),
    pin VARCHAR(10),
    cvv VARCHAR(10),
    track1 VARCHAR(255),
    track2 VARCHAR(255),
    expiring_date VARCHAR(50),
    card_type VARCHAR(50),
    card_renewal_flag BOOLEAN
);

CREATE TABLE IF NOT EXISTS data.staging_products
(
id VARCHAR(20) PRIMARY KEY,
product_name VARCHAR(255),
price VARCHAR(20),
colour VARCHAR(20),
weight DECIMAL(10,2),
warehouse_id VARCHAR(100),
category VARCHAR(100),
brand VARCHAR(100),
cost VARCHAR(20),
launch_date DATE
);


#creamos la tabla transactions
CREATE TABLE IF NOT EXISTS data.staging_transactions (
    id VARCHAR(50),
    card_id VARCHAR(15),
    business_id VARCHAR(20),
    timestamp DATETIME,
    amount DECIMAL(10,2),
    declined BOOLEAN,
    product_ids VARCHAR(100),
    user_id INT,
    lat DECIMAL(15,10),
    longitude DECIMAL(15,10),
    discount_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    shipping_amount DECIMAL(10,2),
    channel VARCHAR(100),
    campaign_id VARCHAR(100),
    device_type VARCHAR(100),
    is_international BOOLEAN,
    decline_reason VARCHAR(100),
    distance_km DECIMAL(10,2)
);


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__american_users.csv'
INTO TABLE DATA.staging_users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__european_users.csv'
INTO TABLE DATA.staging_users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__companies.csv'
INTO TABLE DATA.staging_companies
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__credit_cards.csv'
INTO TABLE DATA.staging_credit_cards
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__transactions.csv'
INTO TABLE DATA.staging_transactions
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__products.csv'
INTO TABLE data.staging_products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


#ahora crearemos nuesta tabla base bank_transactions y vamos a crear nuestras tablas de dimensiones y hechos

CREATE DATABASE IF NOT EXISTS bank_transactions;
USE bank_transactions;


#Creamos la tabla de dim_users 
CREATE TABLE IF NOT EXISTS dim_users (
id INT PRIMARY KEY,
name VARCHAR(255),
surname VARCHAR(255),
phone VARCHAR(255),
email VARCHAR(255),
birth_date DATE,
country VARCHAR(255),
city VARCHAR(255),
postal_code VARCHAR(255),
address VARCHAR(255),
signup_date DATE,
user_segment VARCHAR(255),
income_band VARCHAR(255) );


# hacemos un insert y vamos a extraerlos de la BD data.staging_users
INSERT INTO dim_users(
id,name,surname,phone,email,birth_date,country,city,postal_code,address,signup_date,user_segment,income_band
)
SELECT id,name,surname,phone,email,STR_TO_DATE(birth_date, '%b %d, %Y'),country,city,postal_code,address,STR_TO_DATE(signup_date, '%Y-%m-%d'),user_segment,income_band
FROM data.staging_users;


#creamos dim_companies con su primary key
CREATE TABLE IF NOT EXISTS dim_companies
(
id VARCHAR(20) PRIMARY KEY,
company_name VARCHAR(255),
phone VARCHAR(20),
email VARCHAR(255),
country VARCHAR(255),
website VARCHAR(255),
merchant_category VARCHAR(255),
merchant_price_position VARCHAR(255)
);

#hacemos el insert de los datos consultados en dim companies
INSERT INTO dim_companies
SELECT 
company_id,company_name,phone,email,country,website,merchant_category,merchant_price_position
FROM data.staging_companies;


#creamos dim_credit_card con su primary key
CREATE TABLE IF NOT EXISTS dim_credit_card (
    id VARCHAR(15) PRIMARY KEY,
    user_id INT,
    iban VARCHAR(255),
    pan VARCHAR(255),
    pin VARCHAR(10),
    cvv VARCHAR(10),
    track1 VARCHAR(255),
    track2 VARCHAR(255),
    expiring_date DATE,
    card_type VARCHAR(50),
    card_renewal_flag BOOLEAN
);

#hacemos el insert en dim credit card
INSERT INTO dim_credit_card
SELECT id,user_id,iban,pan,pin,cvv,track1,track2,STR_TO_DATE(expiring_date, '%m/%d/%y'),card_type,card_renewal_flag
FROM data.staging_credit_cards;



#creamos fact_transactions con su primary key
CREATE TABLE IF NOT EXISTS fact_transactions (
    id VARCHAR(50) PRIMARY KEY,
    company_id VARCHAR(20),
    card_id VARCHAR(15),
    user_id INT,
    product_ids VARCHAR(100),
    campaign_id VARCHAR(100),
    timestamp DATETIME, #Fecha original datetime
    tr_date DATE, #Campo adicional fecha
    tr_time TIME, #Campo adicional hora
    amount DECIMAL(10,2),
    declined BOOLEAN,
    lat DECIMAL(10,6),
    longitude DECIMAL(10,6),
    discount_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    shipping_amount DECIMAL(10,2),
    channel VARCHAR (100),
    device_type VARCHAR (100),
    is_international BOOLEAN,
    decline_reason VARCHAR(100),
    distance_km DECIMAL(10,2),
    
    #creamos las relaciones con las tablas y sus referencias 
    FOREIGN KEY (company_id) REFERENCES dim_companies(id),
    FOREIGN KEY (card_id) REFERENCES dim_credit_card(id),
    FOREIGN KEY (user_id) REFERENCES dim_users(id)
);


#hacemos el insert en dim transactions
INSERT INTO fact_transactions (
id,company_id,card_id,user_id,product_ids,campaign_id,
timestamp,tr_date,tr_time, amount,declined, lat,longitude, 
discount_amount,tax_amount,shipping_amount,channel,device_type,is_international,decline_reason,distance_km
)
SELECT id,business_id,card_id,user_id,product_ids,campaign_id,
timestamp ,DATE(timestamp) AS tr_date,TIME(timestamp) AS tr_time, amount,declined, lat,longitude, 
discount_amount,tax_amount,shipping_amount,channel,device_type,is_international,decline_reason,distance_km
FROM data.staging_transactions;

#verificamos que esten los 100.000 registros
SELECT * FROM bank_transactions.fact_transactions;



#Exercici 9
#Realitza una subconsulta que mostri tots els usuaris amb més de 80 transaccions utilitzant almenys 2 taules.

SELECT CONCAT(u.name,' ',u.surname) AS usuario, COUNT(*) AS n_transacciones
FROM fact_transactions AS tr
JOIN dim_users AS u ON u.id=tr.user_id
WHERE EXISTS (SELECT user_id
				FROM fact_transactions
                WHERE user_id=tr.user_id #relacionamos los id de usuario
				GROUP BY user_id 
				HAVING COUNT(*) > 80
                    )
GROUP BY tr.user_id,u.name,u.surname
ORDER BY n_transacciones DESC;



#Exercici 10
#Mostra la mitjana d'amount per IBAN de les targetes de crèdit a la companyia Donec Ltd, utilitza almenys 2 taules.

SELECT c.company_name as empresa,cr.iban, AVG(amount) AS media_gasto
FROM fact_transactions AS tr
JOIN dim_credit_card AS cr ON cr.id=tr.card_id
JOIN dim_companies AS c ON c.id=tr.company_id
WHERE c.company_name ="Donec Ltd" AND tr.declined = 0
GROUP BY c.company_name,cr.iban
ORDER BY media_gasto DESC;


#################################################################################################################################################################################################################################################################################################

#NIVEL 2

#Exercici 1
#Identifica els cinc dies que es va generar la quantitat més gran d'ingressos a l'empresa per vendes.
#Mostra la data de cada transacció juntament amb el total de les vendes.

SELECT c.company_name AS empresa, tr_date AS fecha, SUM(amount) as total_ingresos_dia 
FROM fact_transactions AS tr
JOIN dim_companies AS c ON c.id=tr.company_id
WHERE declined = 0
GROUP BY company_id,tr_date
ORDER BY total_ingresos_dia DESC
LIMIT 5;



#Exercici 2
#Presenta el nom, telèfon, país, data i amount, d'aquelles empreses que van realitzar transaccions amb un valor 
#comprès entre 350 i 400 euros i en alguna d'aquestes dates: 
#29 d'abril del 2015, 20 de juliol del 2018 i 13 de març del 2024. Ordena els resultats de major a menor quantitat.

SELECT c.company_name AS empresa,c.phone,c.country AS pais,tr.tr_date as fecha, tr.amount AS monto_transaccion
FROM fact_transactions AS tr
JOIN dim_companies as c ON c.id=tr.company_id
WHERE tr.amount BETWEEN 350 AND 400 AND tr.tr_date IN('2015-04-29', '2018-07-20','2024-03-13')
ORDER BY monto_transaccion DESC;


#Exercici 3
#Necessitem optimitzar l'assignació dels recursos i dependrà de la capacitat operativa que es requereixi,
#per la qual cosa et demanen la informació sobre la quantitat de transaccions que realitzen les empreses,
#però el departament de recursos humans és exigent i vol un llistat de les empreses on especifiquis 
#si tenen igual o més de 400 transaccions o menys.

SELECT c.company_name, COUNT(*) AS cantidad_transacciones,
CASE WHEN COUNT(*)>400 THEN '>= 400' ELSE '< 400' END AS transacciones
FROM fact_transactions AS tr
JOIN dim_companies AS c ON c.id=tr.company_id
GROUP BY tr.company_id
ORDER BY transacciones;


#Exercici 4
#Elimina de la taula transaction el registre amb ID 000447FE-B650-4DCF-85DE-C7ED0EE1CAAD de la base de dades.

DELETE FROM fact_transactions
WHERE id='000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

#comprobamos que se haya eliminado
SELECT * FROM fact_transactions WHERE id='000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

#Al eliminar un registro de fact_transactions, unicamente se elimina la transacción correspondiente.
#Los registros de las tablas de dimensiones no se ven afectados, ya que una misma empresa,
#usuario o tarjeta de crédito puede estar relacionada con múltiples transacciones.




#Exercici 5
#La secció de màrqueting desitja tenir accés a informació específica per a realitzar anàlisi i estratègies efectives.
#S'ha sol·licitat crear una vista que proporcioni detalls clau sobre les companyies i les seves transaccions. 
#Serà necessària que creïs una vista anomenada VistaMarketing que contingui la següent informació: 
#Nom de la companyia. Telèfon de contacte. País de residència. Mitjana de compra realitzat per cada companyia.
#Presenta la vista creada, ordenant les dades de major a menor mitjana de compra.

#creamos la vista
CREATE VIEW VistaMarketing AS
SELECT c.company_name AS compañia,c.phone AS telefono,c.country AS pais, 
ROUND(AVG(tr.amount),2) AS compra_media
FROM fact_transactions AS tr
JOIN dim_companies AS c ON c.id=tr.company_id
WHERE tr.declined = 0
GROUP BY tr.company_id,c.company_name,c.phone,c.country;

#Consultamos ordenando de mayor a menor compra_media
SELECT *
FROM vistamarketing
ORDER BY compra_media DESC;

#################################################################################################################################################################################################################################################################################################

#NIVEL 3

#Exercici 1
#Crea una nova taula que reflecteixi l'estat de les targetes de crèdit basat en si les tres últimes transaccions han estat declinades aleshores és inactiu, 
#si almenys una no és rebutjada aleshores és actiu. Partint d’aquesta taula respon:
#Quantes targetes estan actives?

WITH transacciones_tarjeta AS(  #usamos una common table expresion (tabla temporal) que nos permite usar funciones de ventana
SELECT tr.card_id,tr.declined,tr.timestamp,
        ROW_NUMBER() OVER(      # la funcion ROW_NUMBER permite la particion de un campo en este caso card_id
        PARTITION BY card_id ORDER BY timestamp DESC #ordenado por fecha en orden descendente, ya que queremos las ultimas 3 transacciones
        ) AS particion  
FROM fact_transactions tr
  ) # cerramos la tabla temporal y la usaremos en el siguiente select
SELECT card_id,
#usamos un case para crear una columna a partir de la condicion de la suma de declined, si la suma de declined es igual a 3 entonces inactivo caso contrario activo
CASE WHEN SUM(declined) = 3 THEN 'inactivo'ELSE 'activo'END AS estado_tarjeta, 
SUM(declined) AS total_operaciones_declinadas #sumamos las operaciones declinadas
FROM transacciones_tarjeta
WHERE particion <=3 # llamamos al alias de la funcion row_number y aplicamos la condición menor o igual a 3 transacciones 
GROUP BY card_id;

#Una vez ya sabemos los datos ahora si creamos la tabla con las buenas practicas
CREATE TABLE IF NOT EXISTS estado_tarjetas_credito (
    card_id VARCHAR(50) PRIMARY KEY,
    estado_tarjeta VARCHAR(20),
    total_operaciones_declinadas INT,
    FOREIGN KEY (card_id) REFERENCES dim_credit_card(id) #añadimos la referencia con la dim_credit_card
);



INSERT INTO estado_tarjetas_credito(
card_id,estado_tarjeta,total_operaciones_declinadas #Hacemos el insert a traves de la consulta
)
WITH transacciones_tarjeta AS(  #usamos una common table expresion (tabla temporal) que nos permite usar funciones de ventana
SELECT tr.card_id,tr.declined,tr.timestamp,
        ROW_NUMBER() OVER(      # la funcion ROW_NUMBER permite la particion de un campo en este caso card_id
        PARTITION BY card_id ORDER BY timestamp DESC #ordenado por fecha en orden descendente, ya que queremos las ultimas 3 transacciones
        ) AS particion  
FROM fact_transactions tr
  ) # cerramos la tabla temporal y la usaremos en el siguiente select
SELECT card_id,
#usamos un case para crear una columna a partir de la condicion de la suma de declined, si la suma de declined es igual a 3 entonces inactivo caso contrario activo
CASE WHEN SUM(declined) = 3 THEN 'inactivo'ELSE 'activo'END AS estado_tarjeta, 
SUM(declined) AS total_operaciones_declinadas #sumamos las operaciones declinadas
FROM transacciones_tarjeta
WHERE particion <=3 # llamamos al alias de la funcion row_number y aplicamos la condición menor o igual a 3 transacciones 
GROUP BY card_id;

#verificamos el numero de tarjetas activas
SELECT COUNT(*)
FROM estado_tarjetas_credito
WHERE estado_tarjeta='activo';



#Exercici 2
#Crea una taula amb la qual puguem unir les dades de l'arxiu de products.csv amb la base de dades creada
# (ja que fins ara no podíem fer-ho), tenint en compte que des de transaction tens product_ids. Genera la següent consulta:
#Necessitem conèixer el nombre de vegades que s'ha venut cada producte.

#creamos la tabla dim_products
CREATE TABLE IF NOT EXISTS dim_products(
id INT PRIMARY KEY,
product_name VARCHAR(50),
price DECIMAL(10,2),
colour VARCHAR(20),
weight DECIMAL(10,2),
warehouse_id VARCHAR(10),
category VARCHAR(20),
brand VARCHAR(20),
cost DECIMAL(10,2),
launch_date DATE
);

#Hacemos el insert en dim_products desde staging_products
INSERT INTO dim_products
(id,product_name,price,colour,weight,warehouse_id,category,brand,cost,launch_date
)
SELECT 
id,product_name, 
CAST(REPLACE(price, '$', '') AS DECIMAL(10,2)), #eliminamos el simbolo $ y convertimos a decimal
 colour,weight,warehouse_id,
 category,brand,
 CAST(REPLACE(cost, '$', '') AS DECIMAL(10,2)), #eliminamos el simbolo $ y convertimos a decimal
 launch_date
FROM data.staging_products;


#Exercici 2
#Crea una taula amb la qual puguem unir les dades de l'arxiu de products.csv amb la base de dades creada (ja que fins ara no podíem fer-ho), 
#tenint en compte que des de transaction tens product_ids. Genera la següent consulta:
# Necessitem conèixer el nombre de vegades que s'ha venut cada producte.

# Extraemos los ids de la columna product_ids en fact_transactions con la funcion JSON_TABLE()
SELECT 
tr.id AS transaction_id, 
jt.product_id
FROM fact_transactions tr
JOIN JSON_TABLE(
CONCAT('[', tr.product_ids, ']'), '$[*]' COLUMNS (product_id INT PATH '$') 
    # CONCAT('[', t.product_ids, ']') Añade [ ] con concat porque la funcion JSON lee arrays
    # '$[*] el $ sera nuestra columna 't.product_ids' y con [*] recorre todos los elementos del array 
    # COLUMNS extrae cada elemento y lo convierte a columna 
    # (product_id INT PATH '$') lo renombras a product_id, guárdalo como INT de lo extraido con '$' = t.product_ids 
) AS jt; # referenciamos la funcion como tabla


#Creamos la tabla intermedia para guardar los ids extraidos de la columna product_ids de fact_transaction
CREATE TABLE transaction_products (
    transaction_id VARCHAR(50),
    product_id INT,
    PRIMARY KEY (transaction_id, product_id), # la clave primaria sera compuesta para evitar duplicidad, una misma transaccion puede tener muchos productos asociados
    FOREIGN KEY (transaction_id) REFERENCES fact_transactions(id), #referenciamos como clave foranea transaction_id con id en fact_transactions
    FOREIGN KEY (product_id) REFERENCES dim_products(id)  # referenciamos product_id con id de dim_products recien creada
);

#Ahora realizamos el insert en transaction_products con la funcion anterior que extrae los productos de la columna products_ids en fact_transactions
INSERT INTO transaction_products(
transaction_id, 
product_id
)
SELECT 
tr.id AS transaction_id, 
jt.product_id
FROM fact_transactions tr
JOIN JSON_TABLE(
CONCAT('[', tr.product_ids, ']'), '$[*]' COLUMNS (product_id INT PATH '$') 
    # CONCAT('[', t.product_ids, ']') Añade [ ] con concat porque la funcion JSON lee arrays
    # '$[*] el $ sera nuestra columna 't.product_ids' y con [*] recorre todos los elementos del array 
    # COLUMNS extrae cada elemento y lo convierte a columna 
    # (product_id INT PATH '$') lo renombras a product_id, guárdalo como INT de lo extraido con '$' = t.product_ids 
) AS jt; # referenciamos la funcion como tabla

#comprobamos que los registros se hayan cargado perfectamente y coincidan con el numero en el insert
SELECT * 
FROM transaction_products;

#verificamos el numero de veces que se ha vendido cada producto
SELECT tp.product_id AS id,p.product_name AS producto,COUNT(*) AS ventas_producto
FROM transaction_products AS tp
JOIN dim_products AS p ON p.id=tp.product_id
GROUP BY product_id,p.product_name;





