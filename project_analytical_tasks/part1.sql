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
