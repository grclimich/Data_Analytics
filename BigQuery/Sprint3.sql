/* @datacloud.settings
{
  "version": 1,
  "service": "BIG_QUERY",
  "connectionInfo": {
    "billingProjectId": "sprint3-analytics-gene",
    "location": "EU"
  },
  "dialect": "GOOGLE_SQL"
}
*/

--Nivell 1: Entorn i Ingesta Híbrida (Code-First)--------------------------------------------------------------

--Exercici 1: Arquitectura de Dades (Lògica vs. Física)
--Previamente ya hemos creado con la interfaz grafica de Bigquery la capa bronce.

--Crearemos la capa silver a traves del siguiente codigo:

CREATE SCHEMA `sprint3_silver`
OPTIONS(
location='EU'
);

--Crearemos la capa gold a traves del shell de comandos con el siguiente codigo:
--bq --location=EU mk --dataset sprint3-analytics-gene:sprint3_gold



--Exercici 2: Ingesta en Capa Bronze (Connexió DDL)


CREATE OR REPLACE EXTERNAL TABLE
`sprint3-analytics-gene.sprint3_bronze.transactions_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  skip_leading_rows = 1,
  field_delimiter = ';'
);


CREATE OR REPLACE EXTERNAL TABLE
`sprint3-analytics-gene.sprint3_bronze.american_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv'],
  field_delimiter = ',',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE
`sprint3-analytics-gene.sprint3_bronze.european_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv'],
  field_delimiter = ',',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE
`sprint3-analytics-gene.sprint3_bronze.credit_cards_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv'],
  field_delimiter = ',',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE
`sprint3-analytics-gene.sprint3_bronze.companies_raw`
(
    company_id STRING,
    company_name STRING,
    phone STRING,
    email STRING,
    country STRING,
    website STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
    field_delimiter = ',',
    skip_leading_rows = 1
);


--Exercici 4

--A)

-- escribe prompt a la IA:
-- Write a SQL query to create a new table called transactions_raw_native in the sprint3_bronze dataset. 
--It should contain all data from the transactions_raw table. Please use CREATE OR REPLACE TABLE
-- so I don't get errors if I run it more than once
CREATE OR REPLACE TABLE
  `sprint3-analytics-gene`.`sprint3_bronze`.`transactions_raw_native` AS
SELECT
*
FROM
  `sprint3-analytics-gene`.`sprint3_bronze`.`transactions_raw`;


--B)

--Comparacion de costos en consulta entre transactions_raw vs transactions_raw_native 
SELECT id
FROM `sprint3-analytics-gene.sprint3_bronze.transactions_raw`;

SELECT id
FROM `sprint3-analytics-gene.sprint3_bronze.transactions_raw_native`;


--ahora lo mismo pero aplicando LIMIT y vemos las diferencias

SELECT *
FROM `sprint3-analytics-gene.sprint3_bronze.transactions_raw`
LIMIT 5;

SELECT *
FROM `sprint3-analytics-gene.sprint3_bronze.transactions_raw_native`
LIMIT 5;


--Exercici 5

SELECT DATE(timestamp) AS fecha, ROUND(SUM(amount),2) AS total_ingresos
FROM `sprint3-analytics-gene.sprint3_bronze.transactions_raw`
WHERE EXTRACT (YEAR from timestamp)  = 2021 
AND declined=0
GROUP BY fecha
ORDER BY total_ingresos DESC
LIMIT 5;


--Exercici 6

SELECT co.company_name AS nombre_empresa, co.country AS pais, DATE(tr.timestamp) AS fecha 
FROM `sprint3_bronze.transactions_raw` AS tr 
JOIN `sprint3_bronze.companies_raw` AS co ON tr.business_id = co.company_id 
WHERE tr.amount BETWEEN 100 AND 200 
AND DATE(tr.timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-13')
AND tr.declined=0;


-- Nivell 2: Neteja i Transformació (ELT).----------------------------------------------------------------

--Exercici 1: 
CREATE OR REPLACE TABLE `sprint3_silver.products_clean` AS
SELECT id AS product_id, 
product_name AS name,
CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id, 
 CAST(price AS FLOAT64) AS price, 
 category,weight,brand,cost,colour,launch_date
FROM `sprint3-analytics-gene.sprint3_bronze.products_raw`;

--confirmamos los datos 
SELECT *
FROM `sprint3-analytics-gene.sprint3_bronze.products_raw`
LIMIT 10;

--Exercici 2: 

CREATE OR REPLACE TABLE `sprint3_silver.transactions_clean` AS
SELECT id AS transaction_id,
    business_id,card_id,
    timestamp,
    IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS monto,
    declined,
    ARRAY(
        SELECT SAFE_CAST(TRIM(product_id) AS INT64)
        FROM UNNEST(SPLIT(product_ids, ',')) AS product_id
         ) AS product_ids,
    user_id,
    SAFE_CAST(lat AS FLOAT64) AS lat,
    SAFE_CAST(longitude AS FLOAT64) AS longitude,
FROM `sprint3-analytics-gene.sprint3_bronze.transactions_raw`;

-- Exercici 3

--Creamos la tabla sprint3_silver.users_combined uniendo american_users_raw y european_users_raw:

CREATE OR REPLACE TABLE `sprint3_silver.users_combined` AS
SELECT
    id AS user_id,name,surname,phone,email,birth_date, country, 'American' AS origin, city, postal_code
FROM `sprint3-analytics-gene.sprint3_bronze.american_users_raw`

UNION ALL

SELECT
    id AS user_id,name, surname, phone, email, birth_date, country, 'Europe' AS origin, city, postal_code
FROM `sprint3-analytics-gene.sprint3_bronze.european_users_raw`;

#confirmamos los datos:
SELECT *
FROM `sprint3-analytics-gene.sprint3_silver.users_combined` 
LIMIT 10;

-- Exercici 4

-- 1) Creamos la tabla sprint_silver.companies_clean desde la tabla bronze_companies_raw

CREATE OR REPLACE TABLE `sprint3-analytics-gene.sprint3_silver.companies_clean` AS
SELECT *
FROM `sprint3-analytics-gene.sprint3_bronze.companies_raw`;

-- 2) Creamos la tabla credit_cards_clean desde la tabla credit_cards_raw y renombramos el id
CREATE OR REPLACE TABLE `sprint3_silver.credit_cards_clean` AS
SELECT
    id AS card_id,
    user_id,
    iban,
    pan,
    pin,
    cvv,
    track1,
    track2,
    expiring_date
FROM `sprint3_bronze.credit_cards_raw`;



--Nivell 3: Presentació de Dades i Creació de Vistes.---------------------------------------------------------

--Exercici 1

CREATE OR REPLACE VIEW `sprint3_gold.v_marketing_kpis` AS 
SELECT 
    co.company_id AS id,
    co.company_name AS empresa,
    co.phone AS telefono,
    co.country AS pais,
    AVG(t.amount) AS compra_media,
    CASE WHEN AVG(t.amount) > 260 THEN 'Premium' ELSE 'Standard' END AS tipo
FROM `sprint3-analytics-gene.sprint3_silver.companies_clean` AS co
JOIN `sprint3-analytics-gene.sprint3_silver.transactions_clean` AS t ON co.company_id = t.business_id
WHERE declined=0 
GROUP BY co.company_id, co.company_name, co.phone, co.country;


-- comprobamos los datos ordenando desde premium por orden de compra media:

SELECT 
  empresa,
  telefono,
  ROUND(compra_media,2) as compra_media,
  tipo
FROM `sprint3-analytics-gene.sprint3_gold.v_marketing_kpis` 
ORDER BY compra_media DESC, tipo DESC;



--Exercici 2: 

CREATE OR REPLACE TABLE `sprint3_gold.product_sales_ranking` AS
WITH productos_venta AS (
SELECT
        product_id,
        COUNT(*) AS total_sold
    FROM `sprint3-analytics-gene.sprint3_silver.transactions_clean`,
    UNNEST(product_ids) AS product_id
    WHERE declined=0
    GROUP BY product_id
    ORDER BY product_id
    )
    SELECT p.product_id,
    p.name,
    p.price,
    COALESCE(pv.total_sold, 0) AS total_sold,
    p.colour,
    FROM `sprint3-analytics-gene.sprint3_silver.products_clean` AS p
    LEFT JOIN productos_venta AS pv ON p.product_id = pv.product_id
    ORDER BY pv.total_sold DESC;

--comprobamos los datos
  SELECT *
  FROM `sprint3-analytics-gene.sprint3_gold.product_sales_ranking`
  LIMIT 1000;



--Exercici 3: Exportació de Resultats

SELECT *
FROM `sprint3-analytics-gene.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;