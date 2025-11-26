CREATE DATABASE IF NOT EXISTS webinar_db;
USE webinar_db;

DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount DECIMAL(10, 2),
    created_at DATETIME,
    device_info JSON, 
    FOREIGN KEY (user_id) REFERENCES users(id)
);

DROP TABLE IF EXISTS transactions_no_keys;
DROP TABLE IF EXISTS users_no_keys;

CREATE TABLE users_no_keys (
    id INT,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions_no_keys (
    id INT,
    user_id INT,
    amount DECIMAL(10, 2),
    created_at DATETIME,
    device_info JSON
);


DELIMITER $$
CREATE PROCEDURE GenerateData()
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE user_count INT DEFAULT 1000;
    DECLARE trx_count INT DEFAULT 100000;

    SET i = 0;
    WHILE i < user_count DO
        INSERT INTO users (name, email) 
        VALUES (
            CONCAT('User_', i), 
            CONCAT('user', i, '@example.com')
        );
        SET i = i + 1;
    END WHILE;

    
    SET i = 0;
    WHILE i < trx_count DO
        INSERT INTO transactions (user_id, amount, created_at, device_info) 
        VALUES (
            TRUNCATE(RAND() * user_count, 0) + 1,   -- Случайный юзер
            ROUND(RAND() * 10000, 2),               -- Сумма до 10 000
            NOW() - INTERVAL TRUNCATE(RAND() * 365, 0) DAY, -- Случайная дата за год
            JSON_OBJECT(
                'os', ELT(TRUNCATE(RAND() * 3, 0) + 1, 'iOS', 'Android', 'Windows'),
                'model', CONCAT('Phone v', TRUNCATE(RAND() * 10, 0))
            )
        );
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL GenerateData(); 

DELIMITER $$
CREATE PROCEDURE GenerateDataNoKeysBig()
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE user_count INT DEFAULT 10000;
    DECLARE trx_count INT DEFAULT 10000000;

    SET i = 0;
    WHILE i < user_count DO
        INSERT INTO users_no_keys (id, name, email) 
        VALUES (
        	i,
            CONCAT('User_', i), 
            CONCAT('user', i, '@example.com')
        );
        SET i = i + 1;
    END WHILE;

    
    SET i = 0;
    WHILE i < trx_count DO
        INSERT INTO transactions_no_keys (id, user_id, amount, created_at, device_info) 
        VALUES (
        	id,
            TRUNCATE(RAND() * user_count, 0) + 1,   -- Случайный юзер
            ROUND(RAND() * 10000, 2),               -- Сумма до 10 000
            NOW() - INTERVAL TRUNCATE(RAND() * 365, 0) DAY, -- Случайная дата за год
            JSON_OBJECT(
                'os', ELT(TRUNCATE(RAND() * 3, 0) + 1, 'iOS', 'Android', 'Windows'),
                'model', CONCAT('Phone v', TRUNCATE(RAND() * 10, 0))
            )
        );
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL GenerateDataNoKeys(); 

-- ==============================
EXPLAIN SELECT * FROM transactions_no_keys_sorted WHERE amount = 5000;
alter table transactions_no_keys_sorted
add constraint amount_key primary key (amount);
create index amount_idx on transactions_no_keys_sorted(amount);

create TABLE transactions_no_keys_sorted as
select
*
from transactions_no_keys 
order by amount

CREATE INDEX idx_amount ON transactions(amount);

EXPLAIN SELECT * FROM transactions WHERE amount = 5000;

DROP INDEX idx_amount ON transactions;

EXPLAIN ANALYZE SELECT * FROM transactions WHERE amount = 5000;

CREATE INDEX idx_amount ON transactions(amount);

EXPLAIN ANALYZE SELECT * FROM transactions WHERE amount = 5000;	
-- ==============================
select
t.*,
(select avg(amount) from transactions) as avg_amount
from transactions as t

FLUSH STATUS;

explain
SELECT u.name, COUNT(t.id) 
FROM users u
JOIN (
	select
		*
	from
		transactions
) t ON u.id = t.user_id 
GROUP BY u.name;

SHOW SESSION STATUS LIKE 'Created_tmp%';

SHOW VARIABLES LIKE 'innodb_buffer_pool_size';


-- SELECT
--  count_star,
--  sum_created_tmp_disk_tables,
--  sum_created_tmp_tables
-- FROM performance_schema.events_statements_summary_by_digest
-- WHERE digest_text LIKE '%JOIN%'
-- ORDER BY sum_created_tmp_disk_tables DESC
-- LIMIT 5;

-- id: Идентификатор шага.
-- select_type: тип запроса (SIMPLE без подзапросов)
-- table: таблица, к которой идет обращение
-- type: тип доступа к данным
-- 	ALL: Full Table Scan (читает всю таблицу)
-- 	index: читаем всё дерево индекса (чуть лучше ALL)
-- 	range: Читаем диапазон строк (например WHERE id > 100)
-- 	ref: Поиск по не уникальному индексу (например все транзакции одного юзера)
-- 	eq_ref: поиск по уникальному ключу (PK)
-- const: Поиск по PK одной строки.
-- possible_keys: какие индексы база могла бы использовать
-- key: какой индекс реально выбрала
-- rows: Примерное колво строк, которое базе придется прочитать
-- Extra: Доп. инфо.
-- 	Using where: фильтрация данных после чтения.
-- 	Using temporary: создание временной таблицы (при GROUP BY без индекса)
-- 	Using filesort: сортировка без индекса (тяжелая операция)

-- ==============================

ANALYZE TABLE transactions_no_keys, users_no_keys;
EXPLAIN SELECT u.name 
FROM users u 
JOIN transactions t ON u.id = t.user_id;
-- GROUP BY u.id;


-- ==============================
SELECT 
  id,
  -- Извлекаем ОС (строка без кавычек)
  device_info->>'$.os' AS os, 
  -- Извлекаем Модель
  device_info->>'$.model' AS model
FROM transactions
where user_id < 5;

-- Медленный запрос (Full Scan, так как нельзя проиндексировать JSON напрямую)
EXPLAIN ANALYZE
SELECT * 
FROM transactions 
WHERE device_info->>'$.os' = 'iOS';

-- 1. Добавляем виртуальную колонку (она не занимает места на диске)
ALTER TABLE transactions
ADD COLUMN device_os VARCHAR(50) 
GENERATED ALWAYS AS (device_info->>'$.os') VIRTUAL;
SELECT 
*
from transactions;

-- 2. Создаем индекс на этой колонке
CREATE INDEX idx_device_os ON transactions(device_os);

-- 3. Проверяем новый запрос
EXPLAIN  ANALYZE SELECT * FROM transactions WHERE device_os = 'iOS';

SHOW INDEX FROM users;

SELECT DATABASE();
SELECT 
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) as size_mb
FROM information_schema.tables 
WHERE table_schema = DATABASE()
ORDER BY size_mb DESC;

SELECT 
    table_name AS 'Table',
    table_rows AS 'Rows',
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
    ROUND(data_length / 1024 / 1024, 2) AS 'Data (MB)',
    ROUND(index_length / 1024 / 1024, 2) AS 'Index (MB)'
FROM information_schema.tables 
WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;
