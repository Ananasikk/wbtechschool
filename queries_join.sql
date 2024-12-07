-- ЧАСТЬ 1
-- 1. Найти клиента с самым долгим временем ожидания между заказом и доставкой. Для этой задачи у вас есть таблицы "Customers", "Orders"

select o.customer_id, name
from orders o
join customers c using(customer_id)
where shipment_date::timestamp - order_date::timestamp = (
	select max(shipment_date::timestamp - order_date::timestamp) 
	from orders )
group by o.customer_id, name

-- 2. Найти клиентов, сделавших наибольшее количество заказов, и для каждого из них найти среднее время между заказом и доставкой, 
-- а также общую сумму всех их заказов. Вывести клиентов в порядке убывания общей суммы заказов.

with cnt_orders as (
	select
		customer_id,
		count(order_id) as cnt,
		avg(shipment_date::timestamp - order_date::timestamp) as avg_shipment,
		sum(order_ammount) as sum_ammount
	from orders
	group by customer_id
) select 
	cnt_orders.customer_id, 
	customers.name,
	avg_shipment,
	sum_ammount
from cnt_orders
join customers using(customer_id)
where cnt = (select max(cnt) from cnt_orders)
order by sum_ammount desc

-- 3. Найти клиентов, у которых были заказы, доставленные с задержкой более чем на 5 дней, и клиентов, у которых были заказы, 
-- которые были отменены. Для каждого клиента вывести имя, количество доставок с задержкой, количество отмененных заказов и 
-- их общую сумму. Результат отсортировать по общей сумме заказов в убывающем порядке.

select
	orders.customer_id,
	name,
	count(order_id) filter(where (shipment_date::timestamp - order_date::timestamp) > interval '5 days') as cnt_orders_with_5_days_delay,
	count(order_id) filter(where order_status = 'Cancel') as cancelled_orders,
	sum(order_ammount) filter(where ((shipment_date::timestamp - order_date::timestamp) > interval '5 days') or order_status = 'Cancel') as sum_ammount
from orders
join customers using(customer_id)
group by orders.customer_id, name
having 
	count(order_id) filter(where (shipment_date::timestamp - order_date::timestamp) > interval '5 days') > 0 
	or count(order_id) filter(where order_status = 'Cancel') > 0
order by sum_ammount desc

-- ЧАСТЬ 2
-- Задача: Напишите SQL-запрос, который выполнит следующие задачи:
-- 1. Вычислит общую сумму продаж для каждой категории продуктов.
-- 2. Определит категорию продукта с наибольшей общей суммой продаж.
-- 3. Для каждой категории продуктов, определит продукт с максимальной суммой продаж в этой категории.

with sum_ammount_by_category as (
	select 
		product_category,
		sum(order_ammount) sum_ammount
	from orders_2 join products_2 using(product_id)
	group by product_category
), max_sum_ammount_category as (
	select 
		product_category
	from sum_ammount_by_category
	where sum_ammount = (select max(sum_ammount) from sum_ammount_by_category)
), sum_amount_product as (
	select 
		product_category,
		product_name,
		sum(order_ammount) sum_ammount
	from orders_2 join products_2 using(product_id)
	group by product_category, product_name
), max_sum_amount_product_by_category as  (
	select 
		DISTINCT ON (product_category)
		product_category,
		product_name,
		sum_ammount as max_sum_amount
	from sum_amount_product
	order by product_category, sum_ammount desc
) select 
	sabc.product_category as product_category,
	sum_ammount,
	msac.product_category as max_amount_category,
	msapbc.product_name as max_amount_product
  from sum_ammount_by_category sabc
  join max_sum_amount_product_by_category msapbc using (product_category)
  cross join max_sum_ammount_category msac