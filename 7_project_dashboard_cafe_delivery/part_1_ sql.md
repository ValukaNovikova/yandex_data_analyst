# Подготовка запросов для QL-чартов

## Задача 1. Расчёт DAU

Расчёт ежедневного количества активных зарегистрированных клиентов за май и июнь 2021 года в городе Саранске. Критерием активности считаем размещение заказа. В вывод должны попасть следующие поля: 
    1. `log_date` — дата события.
    2.	`DAU` — количество активных зарегистрированных клиентов.

В выводе результат отсортирован по дате события в возрастающем порядке и ограничен первыми десятью строками.

```ruby
SELECT 
    analytics_events.log_date,
    COUNT(DISTINCT analytics_events.user_id) AS DAU
FROM analytics_events
LEFT JOIN cities USING (city_id)
WHERE analytics_events.event = 'order'
  AND analytics_events.log_date BETWEEN '2021-05-01' AND '2021-06-30'
  AND cities.city_name = 'Саранск'
GROUP BY analytics_events.log_date
ORDER BY analytics_events.log_date
LIMIT 10;
```