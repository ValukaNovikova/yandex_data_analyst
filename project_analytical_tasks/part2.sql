-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Число зарегистрированных игроков
WITH race_users AS (
	SELECT 
		r.race, -- Наименование расы
		COUNT(DISTINCT u.id) AS count_users, -- Количество зарегистрированных игроков в разрезе рас
		COUNT(DISTINCT e.id) AS count_users_events -- Уникальное количество игроков, которые совершали покупки
	FROM fantasy.users u
	LEFT JOIN fantasy.race r USING(race_id) -- Чтобы оставить наименование расы
	LEFT JOIN fantasy.events e USING(id) -- Чтобы оставить только тех игроков, у которых есть покупки
	GROUP BY r.race
),
-- Число платящих покупателей
race_users_unique AS (
		SELECT 
		r.race, -- Наименование расы
		COUNT(DISTINCT CASE WHEN u.payer = 1 THEN e.id END) AS count_payer_users -- Число платящих покупателей
	FROM fantasy.events e 
	INNER JOIN fantasy.users u USING(id) -- Оставляем пользователей, которые совершали покупки 
	LEFT JOIN fantasy.race r USING(race_id)
	GROUP BY r.race
),
-- Расчеты, связанные с покупками
race_events AS (
	SELECT 
		r.race, -- Наименование расы
		COUNT(DISTINCT e.id) AS count_users_events, -- Количество покупателей
		COUNT(e.transaction_id) AS count_events, -- Общее количество покупок
		AVG(e.amount::numeric) AS avg_amount, -- Средняя стоимость покупок
		SUM(e.amount) AS sum_amount -- Сумма стоимости всех покупок
	FROM fantasy.users u 
	LEFT JOIN fantasy.events e USING(id) -- Чтобы присоединить расу
	LEFT JOIN fantasy.race r USING(race_id) -- Чтобы оставить наименование расы
	WHERE e.amount <> 0 -- Убираем нулевые значения
	GROUP BY r.race
)
SELECT 
	ru.race, -- Наименование расы
	ru.count_users, -- Количество зарегистрированных игроков в разрезе рас
	ru.count_users_events, -- Уникальное количество игроков, которые совершали покупки
	ROUND(ru.count_users_events::numeric / ru.count_users, 4) AS share_count_users_events, -- Доля от общего количества зарегистрированных игроков
	ROUND(ruu.count_payer_users::numeric / re.count_users_events, 4) AS share_users_payer, -- Доля платящих игроков среди игроков, которые совершили внутриигровые покупки
	ROUND(re.count_events::numeric / re.count_users_events, 4) AS avg_count_events_users, -- Среднее количество покупок на одного игрока, совершившего внутриигровые покупки
	ROUND(avg_amount, 4) AS avg_amount_users, -- Средняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
	ROUND(re.sum_amount::numeric / re.count_users_events, 4) AS avg_sum_amount_users -- Средняя суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки
FROM race_users ru
LEFT JOIN race_users_unique ruu USING(race)
LEFT JOIN race_events re USING(race);
