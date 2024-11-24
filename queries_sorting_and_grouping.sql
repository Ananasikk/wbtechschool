-- Для каждого города выведите число покупателей из соответствующей таблицы, сгруппированных 
-- по возрастным категориям и отсортированных по убыванию количества покупателей в каждой категории.

select
	city,
	age_category,
	count(id) as cnt
from ( 
	select
		id,
		city,
		case when age between 0 and 20 then 'young'
			 when age between 21 and 49 then 'adult'
			 when age >= 50 then 'old' 
		end as age_category
	from users ) as users_info
group by 
	city,
	age_category
order by 2, 3 desc

-- Рассчитайте среднюю цену категорий товаров в таблице products, в названиях товаров которых присутствуют слова «hair» или «home». 
-- Среднюю цену округлите до двух знаков после запятой. Столбец с полученным значением назовите avg_price.

select 
	category,
	round(avg(price)::numeric, 2) as avg_price
from products
where name ilike '%hair%' or name ilike '%home%'
group by category

-- Назовем “успешными” (’rich’) селлерами тех:
-- кто продает более одной категории товаров
-- и чья суммарная выручка превышает 50 000

-- Остальные селлеры (продают более одной категории, но чья суммарная выручка менее 50 000) будут обозначаться как ‘poor’. Выведите для каждого продавца количество категорий, средний рейтинг его категорий, суммарную выручку, а также метку ‘poor’ или ‘rich’.
-- Назовите поля: seller_id, total_categ, avg_rating, total_revenue, seller_type.Выведите ответ по возрастанию id селлера.
-- Примечание: Категория “Bedding” не должна учитываться в расчетах.

select
	seller_id,
	total_categ,
	round(avg_rating, 2) as avg_rating,
	total_revenue,
	case
		when total_revenue > 50000 then 'rich'
		else 'poor'
	end as seller_type
from (
	select
		seller_id,
		count(distinct category) as total_categ,
		sum(revenue) as total_revenue,
		avg(rating) as avg_rating
	from sellers
	where category != 'Bedding'
	group by seller_id
	having count(distinct category) > 1) t1
order by seller_id

-- Для каждого из неуспешных продавцов (из предыдущего задания) посчитайте, сколько полных месяцев прошло с даты регистрации продавца.
-- Отсчитывайте от того времени, когда вы выполняете задание. Считайте, что в месяце 30 дней. Например, для 61 дня полных месяцев будет 2.
-- Также выведите разницу между максимальным и минимальным сроком доставки среди неуспешных продавцов. Это число должно быть одинаковым для всех неуспешных продавцов.
-- Назовите поля: seller_id, month_from_registration ,max_delivery_difference.Выведите ответ по возрастанию id селлера.
-- Примечание: Категория “Bedding” по-прежнему не должна учитываться в расчетах.

select
	seller_id,
	(current_date::date - date_reg)/30 as month_from_registration,
	max(max_delivery_days) over() - min(min_delivery_days) over() as max_delivery_difference
from (
	select
		seller_id,
		count(distinct category) as total_categ,
		sum(revenue) as total_revenue,
		min(to_date(date_reg, 'dd/mm/yyyy')) as date_reg,
		min(delivery_days) as min_delivery_days,
		max(delivery_days) as max_delivery_days
	from sellers
	where category != 'Bedding'
	group by seller_id
	having count(distinct category) > 1) t1
where total_revenue <= 50000
order by seller_id

-- Отберите продавцов, зарегистрированных в 2022 году и продающих ровно 2 категории товаров с суммарной выручкой, превышающей 75 000.
-- Выведите seller_id данных продавцов, а также столбец category_pair с наименованиями категорий, которые продают данные селлеры.
-- Например, если селлер продает товары категорий “Game”, “Fitness”, то для него необходимо вывести пару категорий category_pair с разделителем “-” в алфавитном порядке (т.е. “Game - Fitness”).
-- Поля в результирующей таблице: seller_id, category_pair

select
	seller_id,
	category_pair
from (
	select
		seller_id,
		count(distinct category) as total_categ,
		sum(revenue) as total_revenue,
		min(to_date(date_reg, 'dd/mm/yyyy')) as date_reg,
		string_agg(category, ' - ' ORDER BY category) as category_pair
	from sellers
	group by seller_id
	having count(distinct category) = 2) t1
where total_revenue >= 75000 and EXTRACT(YEAR FROM date_reg) = 2022