-- ЧАСТЬ 1
-- Выведите список сотрудников с именами сотрудников, получающими самую высокую зарплату в отделе. 
-- Столбцы в результирующей таблице: first_name, last_name, salary, industry, name_ighest_sal. 
-- Последний столбец - имя сотрудника для данного отдела с самой высокой зарплатой.
-- Выведите аналогичный список, но теперь укажите сотрудников с минимальной зарплатой.
-- В каждом случае реализуйте расчет двумя способами: с использованием функций min max (без оконных функций) и 
-- с использованием first/last value

-- запрос с группировкой
with max_salary_by_industry as (
	select distinct on(industry)
		industry,
		first_name || ' ' || last_name as full_name
	from salary
	order by industry, salary desc
), min_salary_by_industry as (
	select distinct on(industry)
		industry,
		first_name || ' ' || last_name as full_name
	from salary
	order by industry, salary
)
select
	first_name,
	last_name,
	salary,
	industry,
	max_salary_by_industry.full_name as name_ighest_sal,
	min_salary_by_industry.full_name as name_lowest_sal
from salary
join max_salary_by_industry using(industry)
join min_salary_by_industry using(industry)


-- запрос с оконными функциями
select
	first_name,
	last_name,
	salary,
	industry,
	last_value(first_name || ' ' || last_name) over(partition by industry 
													order by salary RANGE BETWEEN
            										UNBOUNDED PRECEDING AND
            										UNBOUNDED FOLLOWING) as name_ighest_sal,
	first_value(first_name || ' ' || last_name) over(partition by industry 
													order by salary RANGE BETWEEN
            										UNBOUNDED PRECEDING AND
            										UNBOUNDED FOLLOWING) as name_lowest_sal
from salary


-- ЧАСТЬ 2
-- Отберите данные по продажам за 2.01.2016. Укажите для каждого магазина его адрес, сумму проданных товаров в штуках, сумму проданных товаров в рублях.
-- Столбцы в результирующей таблице: SHOPNUMBER , CITY , ADDRESS, SUM_QTY SUM_QTY_PRICE

select
	sales."SHOPNUMBER",
	"CITY",
	"ADDRESS",
	sum("QTY") as "SUM_QTY",
	sum("QTY" * "PRICE") as "SUM_QTY_PRICE"
from sales join shops using("SHOPNUMBER")
join goods using("ID_GOOD")
where "DATE" = '2016-01-02'::date
group by sales."SHOPNUMBER", "CITY", "ADDRESS"

-- Отберите за каждую дату долю от суммарных продаж (в рублях на дату). Расчеты проводите только по товарам направления ЧИСТОТА.
-- Столбцы в результирующей таблице: DATE_, CITY, SUM_SALES_REL

with sales_by_date as (
	select
		"DATE",
		"CITY",
		sum("QTY" * "PRICE") as "SUM_SALES"
	from sales join shops using("SHOPNUMBER")
	JOIN goods using("ID_GOOD")
	where "CATEGORY" = 'ЧИСТОТА'
	group by "DATE", "CITY"
), total_sales as (
	select
		sum("QTY" * "PRICE") as "TOTAL_SUM_SALES"
  	from sales join shops using("SHOPNUMBER")
  	JOIN goods using("ID_GOOD")
  	where "CATEGORY" = 'ЧИСТОТА'
) select 
	"DATE",
	"CITY",
	"SUM_SALES"/"TOTAL_SUM_SALES" as "SUM_SALES_REL"
  from sales_by_date
  cross join total_sales
  order by 1,2

-- Выведите информацию о топ-3 товарах по продажам в штуках в каждом магазине в каждую дату.
-- Столбцы в результирующей таблице: DATE_ , SHOPNUMBER, ID_GOOD

with sum_sales_by_good_shop_date as (
	select
		"DATE",
		"ID_GOOD",
		"SHOPNUMBER",
		sum("QTY") as sum_sales
	from sales join shops using("SHOPNUMBER")
	JOIN goods using("ID_GOOD")
	where "CATEGORY" = 'ЧИСТОТА'
	group by "DATE", "SHOPNUMBER", "ID_GOOD"
	order by "SHOPNUMBER", "ID_GOOD", "DATE"
) select
	"DATE",
	"SHOPNUMBER",
	"ID_GOOD"
from (
	select 
		"DATE",
		"ID_GOOD",
		"SHOPNUMBER",
		sum_sales,
		row_number() over(partition by "SHOPNUMBER", "DATE" ORDER BY sum_sales desc) as rn
  	 from sum_sales_by_good_shop_date) q
where rn between 1 and 3

-- Выведите для каждого магазина и товарного направления сумму продаж в рублях за предыдущую дату. Только для магазинов Санкт-Петербурга.
-- Столбцы в результирующей таблице: DATE_, SHOPNUMBER, CATEGORY, PREV_SALES
with cte as (
	select
		"DATE",
		"SHOPNUMBER",
		"CATEGORY",
		sum("QTY" * "PRICE") as sum_sales
	from sales join shops using("SHOPNUMBER")
	JOIN goods using("ID_GOOD")
	where "CITY" = 'СПб'
	group by "DATE", "SHOPNUMBER", "CATEGORY")
select 
	"DATE",
	"SHOPNUMBER",
	"CATEGORY",
	coalesce(lag(sum_sales) OVER(PARTITION BY "SHOPNUMBER", "CATEGORY" ORDER BY "DATE"), 0) as "PREV_SALES"
from cte

-- ЧАСТЬ 3
-- Создайте таблицу query (количество строк - порядка 20) с данными о поисковых запросах на маркетплейсе.
-- Поля в таблице: searchid, year, month, day, userid, ts, devicetype, deviceid, query. ts- время запроса в формате unix.
-- 💡 Рекомендация по наполнению столбца query: Заносите последовательные поисковые запросы. Например, к, ку, куп, купить, купить кур, купить куртку.
-- Для каждого запроса определим значение is_final:
-- Если пользователь вбил запрос (с определенного устройства), и после данного запроса больше ничего не искал, то значение равно 1
-- Если пользователь вбил запрос (с определенного устройства), и до следующего запроса прошло более 3х минут, то значение также равно 1
-- Если пользователь вбил запрос (с определенного устройства), И следующий запрос был короче, И до следующего запроса прошло прошло более минуты, то значение равно 2
-- Иначе - значение равно 0

CREATE TABLE query (
    searchid serial PRIMARY KEY ,
    year INT,
    month INT,
    day INT,
    userid INT,
    ts INT,
    devicetype VARCHAR(50),
    deviceid VARCHAR(50),
    query VARCHAR(255),
    is_final INT
);

INSERT INTO query (year, month, day, userid, ts, devicetype, deviceid, query)
VALUES
    (2024, 11, 3, 101, 1698998400, 'ios', 'device_001', 'к'),
    (2024, 11, 3, 101, 1698998460, 'ios', 'device_001', 'ку'),
    (2024, 11, 3, 101, 1698998520, 'ios', 'device_001', 'куп'),
    (2024, 11, 3, 101, 1698998580, 'ios', 'device_001', 'купить'),
    (2024, 11, 3, 101, 1698998640, 'ios', 'device_001', 'купить кур'),
    (2024, 11, 3, 101, 1698998700, 'ios', 'device_001', 'купить куртку'),
    (2024, 11, 3, 102, 1698998800, 'desktop', 'device_002', 'сум'),
    (2024, 11, 3, 102, 1698998810, 'desktop', 'device_002', 'сумки'),
    (2024, 11, 3, 102, 1698998820, 'desktop', 'device_002', 'сумка'),
    (2024, 11, 3, 102, 1698998880, 'desktop', 'device_002', 'сумка кожа'),
    (2024, 11, 3, 102, 1698998940, 'desktop', 'device_002', 'сумка кожа черная'),
    (2024, 11, 3, 103, 1698999000, 'android', 'device_003', 'часы'),
    (2024, 11, 3, 103, 1698999060, 'android', 'device_003', 'часы женские'),
    (2024, 11, 3, 103, 1698999120, 'android', 'device_003', 'часы женские синий'),
    (2024, 11, 3, 103, 1698999180, 'android', 'device_003', 'часы женские синий кожаный ремень'),
    (2024, 11, 3, 103, 1698999245, 'android', 'device_003', 'к'),
    (2024, 11, 3, 103, 1698999260, 'android', 'device_003', 'корм'),
    (2024, 11, 3, 103, 1698999555, 'android', 'device_003', 'новый фильтр'),
    (2024, 11, 3, 104, 1698999240, 'android', 'device_004', 'телевизор'),
    (2024, 11, 3, 104, 1698999300, 'android', 'device_004', 'телевизор LG'),
    (2024, 11, 3, 104, 1698999360, 'android', 'device_004', 'телевизор LG 55'),
    (2024, 11, 3, 104, 1698999420, 'android', 'device_004', 'телевизор LG 55 дюймов'),
    (2024, 11, 3, 105, 1698999480, 'desktop', 'device_005', 'ноутбук'),
    (2024, 11, 3, 105, 1698999540, 'desktop', 'device_005', 'ноутбук для работы');

-- обновление final
with main as (
	select
        searchid,
		userid,
		deviceid,
		ts,
		query,
		lead(ts) over(partition by userid, deviceid order by ts) - ts as delta_next_ts,
		length(query) as len_query,
		lead(length(query)) over(partition by userid, deviceid order by ts) as len_next_query
	from query
), final_calculation as (
	select *,
		case 
			when delta_next_ts is null then 1
			when delta_next_ts > 60*3 then 1
			when len_query > len_next_query and delta_next_ts > 60 then 2
			else 0 
		end as final
	from main)
update query set is_final = final_calculation.final 
from final_calculation
where query.searchid = final_calculation.searchid

-- Выведите данные о запросах в определенный день (выберите сами), у которых is_final пользователей устройства android равен 1 или 2.
-- Столбцы в результирующей таблице:
--  `year`, `month`, `day`, `userid`, `ts` , `devicetype`, `deviceid` , `query`, `next_query`, `is_final`

select 
	year, 
	month, 
	day, 
	userid, 
	ts, 
	devicetype, 
	deviceid, 
	query, 
	lead(query) over(partition by userid, deviceid order by ts) as next_query, 
	is_final
from query
where year=2024 and month=11 and day=3 and devicetype='android' and is_final in (1,2)