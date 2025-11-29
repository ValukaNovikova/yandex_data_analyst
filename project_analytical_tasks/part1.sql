-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	COUNT(u.id) AS total_count, -- Общее количество игроков, зарегистрированных в игре
	SUM(u.payer) AS payer_count, -- Количество платящих игроков
	ROUND(AVG(u.payer) * 100, 4) AS payer_share -- Доля платящих игроков от общего количества пользователей, зарегистрированных в игре
FROM fantasy.users u;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- В CTE находим общее количество зарегистрированных игроков в разрезе разрезе рас
SELECT 
	DISTINCT r.race, -- Наименование расы
	SUM(u.payer) OVER (PARTITION BY u.race_id) AS payer_race_count, -- Количество платящих игроков этой расы
	COUNT(u.race_id) OVER (PARTITION BY u.race_id) AS race_count, -- Общее количество зарегистрированных игроков этой расы
	ROUND(AVG(u.payer) OVER (PARTITION BY u.race_id) * 100, 4) AS payer_race_share -- Доля платящих игроков среди всех зарегистрированных игроков этой расы 
FROM fantasy.users u
LEFT JOIN fantasy.race r ON u.race_id = r.race_id -- Присоединение таблицы с наименованиями рас
ORDER BY payer_race_share DESC; -- Сортировка по убыванию доли платящих игроков

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT(transaction_id) AS total_count_transactions, -- Общее количество покупок
	SUM(amount) AS total_sum_amount, -- Суммарная стоимость всех покупок
	MIN(amount) AS min_amount, -- Минимальная стоимость покупки
	MAX(amount) AS max_amount, -- Максимальная стоимость покупки
	ROUND(AVG(amount)::numeric, 4) AS avg_amount, -- Среднее значение стоимости покупки
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::numeric, 4) AS median_amount, -- Медиана стоимости покупки
	ROUND(STDDEV(amount)::numeric, 4) AS stand_dev_amount -- Стандартное отклонение стоимости покупки
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT 
	SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) AS count_null, -- Количество покупок с нулевой стоимостью
	ROUND((SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END)::numeric / COUNT(transaction_id) * 100), 4) AS share_null -- Доля от общего числа покупок
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
-- Общее количество продаж и игроков
WITH total_metrics AS (
	SELECT 
		COUNT(transaction_id) AS count_events, -- Общее количество продаж
		COUNT(DISTINCT id) AS count_users -- Общее количество уникальных игроков, совершивших покупки
	FROM fantasy.events
	WHERE amount <> 0 -- Убираем нулевые продажи
),
-- Количество внутриигровых продаж по предметам, а также количество игроков, которые хотя бы раз покупали предмет
stats_items AS (
	SELECT 
		i.game_items, -- Наименование эпического предмета
		COUNT(e.transaction_id) AS count_items, -- Количество продаж каждого эпического предмета
		COUNT(DISTINCT e.id) AS unique_users -- Уникальное количество игроков, которые купили данный эпический предмет 
	FROM fantasy.events e 
	LEFT JOIN fantasy.items i ON e.item_code = i.item_code
	WHERE amount <> 0 -- Убираем нулевые продажи
	GROUP BY i.game_items
)
SELECT 
	game_items, -- Наименование эпического предмета
	count_items, -- Количество продаж каждого эпического предмета
	ROUND(count_items::numeric / (SELECT count_events FROM total_metrics) * 100, 4) AS share_items, -- Доля продажи каждого предмета от всех продаж
	ROUND(unique_users::numeric / (SELECT count_users FROM total_metrics) * 100, 4) AS share_users -- Доля игроков, которые хотя бы раз покупали предмет
FROM stats_items
ORDER BY count_items DESC; -- Сортировка по количеству продаж каждого эпического предмета
