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


-- Nivel 1 ---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Exercici 1
--El Country Manager d'Alemanya necessita revisar urgentment les transaccions del dia 12 de març de 2022.

SELECT *
FROM `sprint3-analytics-gene.sprint3_silver.companies_clean` AS co
JOIN `sprint3-analytics-gene.sprint3_silver.transactions_clean` AS t ON co.company_id = t.business_id
WHERE EXTRACT(DATE FROM t.timestamp) = '2022-03-12'
AND co.country='Germany';

--Exercici 2
--Crea una taula intermèdia anomenada sprint3_silver.transactions_recent a partir de la taula 
--sprint3_silver.transactions_clean. El teu objectiu és mantenir totes les columnes, 
--però substituir el timestamp original per un de nou, generat aleatòriament perquè caigui dins dels últims 50 dies.

--PASO 1
CREATE OR REPLACE TABLE `sprint3_silver.transactions_recent` AS
SELECT * EXCEPT(timestamp),
TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL CAST(RAND() * 50 AS INT64)DAY) AS fecha_aleatoria
FROM `sprint3-analytics-gene.sprint3_silver.transactions_clean`;


--PASO 2 
CREATE OR REPLACE TABLE `sprint3_gold.fact_transactions_optimized`
PARTITION BY DATE(timestamp)
CLUSTER BY business_id AS
SELECT *
FROM `sprint3_silver.transactions_recent`;


--Exercici 3

SELECT *
FROM `sprint3_silver.transactions_recent`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY);


SELECT *
FROM `sprint3_gold.fact_transactions_optimized`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY);


--Exercici 4

--Creamos nuestra vista materializada
CREATE OR REPLACE MATERIALIZED VIEW `sprint3_gold.mv_daily_sales` AS
SELECT DATE(timestamp) AS fecha, SUM(amount) AS ventas_totales 
FROM `sprint3_gold.fact_transactions_optimized` 
WHERE declined=0
GROUP BY fecha;

-- consultamos los datos de la vista
SELECT fecha, ROUND(ventas_totales,2) AS ventas_totales
FROM `sprint3_gold.mv_daily_sales` 
ORDER BY fecha DESC;


--Nivel 2 ---------------------------------------------------------------------------------------------------------------------------------------------------------------

--Exercici 1

WITH VIP_Stats AS (
SELECT
user_id,
COUNT(transaction_id) AS num_compras,
SUM(amount) AS total_gastado,
ROUND(AVG(amount), 2) AS ticket_medio,
MAX(amount) AS max_compra
FROM `sprint3_silver.transactions_clean`
WHERE declined = 0
GROUP BY user_id
HAVING SUM(amount) > 500
),
users_combined AS (
SELECT
uc.user_id,
CONCAT(uc.name, ' ', uc.surname) AS nombre_completo,
uc.email,
vs.num_compras,
vs.ticket_medio,
vs.max_compra,
ROUND(vs.total_gastado,2) AS total_gastado
FROM `sprint3_silver.users_combined` AS uc
JOIN VIP_Stats AS vs ON uc.user_id = vs.user_id
)
SELECT *
FROM users_combined
ORDER BY total_gastado DESC;

--Exercici 2

WITH ventas_diarias AS (
SELECT fecha AS fecha_venta,
ventas_totales AS ventas_hoy,
LAG(ventas_totales) OVER (ORDER BY fecha) AS ventas_ayer
FROM `sprint3_gold.mv_daily_sales`
)
SELECT fecha_venta,
ROUND(ventas_hoy, 2) AS ventas_hoy,
ROUND(ventas_ayer, 2) AS ventas_ayer,
ROUND(SAFE_DIVIDE(ventas_hoy - ventas_ayer, ventas_ayer) * 100,2) AS Diff_Percentual
FROM ventas_diarias
ORDER BY fecha_venta;

-- Exercici 3

SELECT fecha AS fecha_venta, 
ROUND(ventas_totales,2) as ventas_hoy,
ROUND(SUM(ventas_totales) OVER (PARTITION BY EXTRACT(YEAR FROM fecha) ORDER BY fecha ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) AS ventas_acumuladas_YTD
FROM `sprint3_gold.mv_daily_sales` 
ORDER BY fecha_venta;

-- Exercici 4

WITH segmentacion_cliente AS (
SELECT
user_id, EXTRACT(DATE FROM timestamp) AS fecha,
ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp) as orden_compras,
amount AS compras
FROM `sprint3_silver.transactions_clean`
WHERE declined = 0
),
primeras3_compras AS(
SELECT  user_id,fecha,orden_compras,compras
FROM segmentacion_cliente
WHERE orden_compras <=3 -- filtramos primero las primeras 3 compras por cliente
)
SELECT pr.user_id, CONCAT(uc.name, ' ' ,uc.surname) as nombre_completo, uc.email, 
pr.fecha AS fecha_3ra_compra, pr.compras AS importe_3ra_compra,
ROUND(AVG(pr.compras) OVER (PARTITION BY pr.user_id),2) AS avg_primeras3_compras -- hacemos el promedio solo de las 3 primeras compras por cliente
FROM `primeras3_compras` AS pr
JOIN `sprint3_silver.users_combined` AS uc ON pr.user_id = uc.user_id
QUALIFY pr.orden_compras = 3; -- Solo clientes que hayan completado 3 compras


--Nivel 3 ---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Exercici 1
CREATE OR REPLACE TABLE `sprint3_gold.dim_transactions_flat` AS
SELECT
tc.transaction_id,
tc.business_id,
tc.card_id,
tc.timestamp,
tc.amount,
tc.declined,
tc.product_ids,
tc.user_id,
tc.lat,
tc.longitude,
pc.product_id AS product_sku,
pc.name AS product_name,
pc.price AS product_price
FROM `sprint3_silver.transactions_clean` AS tc
CROSS JOIN UNNEST(tc.product_ids) AS product_id
LEFT JOIN `sprint3_silver.products_clean` AS pc ON product_id = pc.product_id;


--Exercici 2:

SELECT 
product_name AS producto,
COUNT(*) AS unidades_vendidas,
FROM `sprint3_gold.dim_transactions_flat`
GROUP BY product_sku,product_name
ORDER BY unidades_vendidas DESC
LIMIT 5;


--Exercici 3:

--1. User Defined Functions (UDF)
CREATE OR REPLACE FUNCTION `sprint3_gold.calculate_tax`(
  importe_base FLOAT64,
  porcentaje_iva FLOAT64,
  decimales INT64
)
RETURNS FLOAT64
AS (
  ROUND(importe_base * porcentaje_iva, decimales)
);

--2 Integració i Orquestració:
--actualizamos la tabla dim_transactions_flat
CREATE OR REPLACE TABLE `sprint3_gold.dim_transactions_flat` AS
SELECT tc.transaction_id,
tc.business_id,
tc.card_id,
tc.timestamp,
tc.amount,
tc.declined,
tc.product_ids,
tc.user_id,
tc.lat,
tc.longitude,
pc.product_id AS product_sku,
pc.name AS product_name,
pc.price AS product_price,
pc.price + `sprint3_gold.calculate_tax`(pc.price, 0.21, 2) AS product_price_tax_inc --precio + funcion calcula precio con impuestos incluidos
FROM `sprint3_silver.transactions_clean` AS tc
CROSS JOIN UNNEST(tc.product_ids) AS product_id
LEFT JOIN `sprint3_silver.products_clean` AS pc ON product_id = pc.product_id;

