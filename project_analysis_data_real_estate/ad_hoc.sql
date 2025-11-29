-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Собираем общую таблицу для создания сводной, также оставляем объявления только 2015-2018 годов
clean_advertisement AS (
	SELECT 
		f.id, -- Идентификатор квартиры
		c.city, -- Название населенного пункта
		t.type, -- Название типа населенного пункта
		a.days_exposition, -- Длительность нахождения объявления на сайте 
		-- Категоризация по регионам
		CASE 
			WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'Ленинградская область'
		END AS region, 
		-- Категоризация по сегментам активности
		CASE 
			WHEN a.days_exposition IS NULL THEN 'non category' -- Добавлена категория "non category"
			WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1. Около одного месяца'
			WHEN a.days_exposition BETWEEN 31 AND 90 THEN '2. От одного до трёх месяцев'
			WHEN a.days_exposition BETWEEN 91 AND 180 THEN '3. От трёх месяцев до полугода'
			WHEN a.days_exposition > 180 THEN '4. Более полугода'
		END AS activity_segment, 
		COUNT(f.id) OVER (PARTITION BY
			(CASE 
				WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
				ELSE 'Ленинградская область'
			END)
			) AS city_count, -- Количество объявлений по городам
		a.last_price::numeric / f.total_area AS costs, -- Стоимость квадратного метра
		a.last_price, -- Стоимость квартиры в объявлении
		f.total_area, -- Общая площадь квартиры 
		f.rooms, -- Число комнат
		f.balcony, -- Количество балконов в квартире
		f.floors_total -- Этажность дома
	FROM real_estate.advertisement a  
	INNER JOIN real_estate.flats f USING (id)
	INNER JOIN real_estate.city c USING (city_id)
	INNER JOIN real_estate.type t USING (type_id) 
	WHERE id IN (SELECT * FROM filtered_id)
	  AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
	  AND t.type = 'город'
)
-- Основной запрос 
SELECT 
	ca.region, -- Регион
	ca.activity_segment, -- Сегменты активности
	COUNT(ca.id) AS count_flats, -- Количество продаваемых квартир
	ROUND(COUNT(ca.id)::numeric / ca.city_count  * 100, 2) AS share_count_flats, -- Доля объявлений, выраженная в процентах (отредактировано)
	ROUND(AVG(ca.last_price)::numeric, 2) AS avg_price, -- Средняя цена квартиры
	ROUND(AVG(ca.costs)::numeric, 2) AS avg_costs, -- Средняя стоимость квадратного метра
	ROUND(AVG(ca.total_area)::numeric, 2) AS avg_total_area, -- Средняя площадь недвижимости 
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ca.rooms))::numeric, 4) AS median_rooms, -- Медианное значение числа комнат
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ca.balcony))::numeric, 4) AS median_balcony, -- Медианное значение количества балконов
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ca.floors_total))::numeric, 4) AS median_floors_total -- Медианное значение этажности дома
FROM clean_advertisement ca
GROUP BY ca.region, ca.activity_segment, ca.city_count 
ORDER BY ca.region DESC;

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Статистика по публикации объявлений
publish_stat AS (
	SELECT 
		EXTRACT(MONTH FROM a.first_day_exposition) AS number_month, -- Месяц публикации объявления
		COUNT(a.first_day_exposition) AS publish_count, -- Количество опубликованных объявлений
		AVG(a.last_price::numeric / f.total_area) AS publish_avg_cost, -- Средняя стоимость квартир по опубликованным объявлениям
		AVG(f.total_area) AS publish_avg_area -- Средняя общая площадь квартир по опубликованным объявлениям
	FROM real_estate.advertisement a 
	INNER JOIN real_estate.flats f USING (id)
	INNER JOIN real_estate.type t USING (type_id) 
	WHERE id IN (SELECT * FROM filtered_id)
	  AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
	  AND t.type = 'город' -- Оставляем только города
	GROUP BY EXTRACT(MONTH FROM a.first_day_exposition)
),
-- Статистика по снятию объявлений
removing_stat AS (
	SELECT 
		EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::int) AS number_month, -- Месяц публикации объявления
		COUNT(a.first_day_exposition) AS removing_count, -- Количество снятых объявлений
		AVG(a.last_price::numeric / f.total_area) AS removing_avg_cost, -- Средняя стоимость квартир по снятым объявлениям
		AVG(f.total_area) AS removing_avg_area -- Средняя общая площадь квартир по снятым объявлениям
	FROM real_estate.advertisement a 
	INNER JOIN real_estate.flats f USING (id)
	INNER JOIN real_estate.type t USING (type_id) 
	WHERE id IN (SELECT * FROM filtered_id)
	  AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
	  AND a.days_exposition IS NOT NULL -- Оставляем только снятые объявления
	  AND t.type = 'город' -- Оставляем только города
	GROUP BY EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::int)
)
SELECT 
	-- Выделение месяца из номера месяца
	CASE
		WHEN number_month = 1 THEN 'Январь'
		WHEN number_month = 2 THEN 'Февраль'
		WHEN number_month = 3 THEN 'Март'
		WHEN number_month = 4 THEN 'Апрель'
		WHEN number_month = 5 THEN 'Май'
		WHEN number_month = 6 THEN 'Июнь'
		WHEN number_month = 7 THEN 'Июль'
		WHEN number_month = 8 THEN 'Август'
		WHEN number_month = 9 THEN 'Сентябрь'
		WHEN number_month = 10 THEN 'Октябрь'
		WHEN number_month = 11 THEN 'Ноябрь'
		WHEN number_month = 12 THEN 'Декабрь'
	END AS month,
	DENSE_RANK() OVER (ORDER BY publish_count DESC) AS publish_rank, -- Ранжирование по публикации объявлениям
	publish_count, ROUND(publish_avg_cost::numeric, 2) AS publish_avg_cost, ROUND(publish_avg_area::numeric, 2) AS publish_avg_area, -- Рассчитанные в publish_stat показатели
	DENSE_RANK() OVER (ORDER BY removing_count DESC) AS publish_rank, -- Ранжирование по снятию объявлений
	removing_count, ROUND(removing_avg_cost::numeric, 2) AS removing_avg_cost, ROUND(removing_avg_area::numeric, 2) AS removing_avg_area -- Рассчитанные в removing_stat показатели
FROM publish_stat
LEFT JOIN removing_stat USING (number_month)
ORDER BY number_month;
