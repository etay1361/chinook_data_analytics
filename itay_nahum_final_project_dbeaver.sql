
/* checking the data + api part */
select *
from track t;


select *
from playlisttrack p ;


select *
from playlist p;


select *
from mediatype m;


select *
from invoiceline i;


select *
from invoice i;


select *
from genre g;


select *
from employee e;


select *
from customer c;


select *
from artist a;


select MAX(a.last_update)
from artist a;


select *
from album a;


select MAX(i.invoicedate),
       MIN(i.invoicedate)
from invoice i;


/*-------------------------------------------*/
/* data warehouse part*/

select current_database();


create schema dwh;

/* dim_currency */


select *
from stg.currency;

select count(distinct(c.invoicedate))
from stg.currency c;


create table dwh.dim_currency as
	select *
	from stg.currency;

select *
from dim_currency dc;


/* i created the dim_currency table using the currency data from the stg schema.
the table contains the relevant dates and the exchange rate from usd to ils,
which will be used later for currency conversion in the analysis. */



/* dim_playlist*/


select *
from playlisttrack p;


select *
from playlist p;


with playlist_x as(
	select p.playlistid , p.trackid,
		   p2."name", p.last_update 
	from stg.playlisttrack p inner join stg.playlist p2
	on p.playlistid = p2.playlistid
)
select *
from playlist_x;



with playlist_x as(
	select p.playlistid , p.trackid,
		   p2."name", p.last_update 
	from stg.playlisttrack p right join stg.playlist p2
	on p.playlistid = p2.playlistid
)
select *
from playlist_x
where trackid is null;


create table dwh.dim_playlist as
	select p.playlistid , p.trackid,
		   p2."name", p.last_update 
	from stg.playlisttrack p inner join stg.playlist p2
	on p.playlistid = p2.playlistid;


select *
from dim_playlist dp;


/* to create the dim_playlist table,
i used an inner join because the playlist table contains all playlist ids,
so there should not be any rows without a match.
in addition, i selected only the relevant field from the playlist table,
which is the playlist name. */



/* dim_customer*/


select *
from customer c;


with customer_x as(
	select c.customerid,
		   initcap(c.firstname) as firstname,
		   initcap(c.lastname) as lastname,
		   c.company, c.address, c.city,
		   c.state, c.country, c.postalcode,
		   c.phone, c.fax, c.email,
		   split_part(c.email, '@', 2) as domain,
		   c.supportrepid, c.last_update
	from stg.customer c
)
select *
from customer_x;

create table dwh.dim_customer as
	select c.customerid,
		   initcap(c.firstname) as firstname,
		   initcap(c.lastname) as lastname,
		   c.company, c.address, c.city,
		   c.state, c.country, c.postalcode,
		   c.phone, c.fax, c.email,
		   split_part(c.email, '@', 2) as domain,
		   c.supportrepid, c.last_update
	from stg.customer c


select *
from dim_customer dc;


/* i chose to write all the table columns manually because there are changes in the firstname
and lastname columns, and i wanted to avoid keeping both the original and updated columns.
in addition, i added the domain column as part of the select statement. */



/*dim_employee*/

select *
from employee e;

select *
from department_budget db;


with employee_x as (
	select e.*,
		   db.department_name, db.budget,
		   date_part('year', age(e.last_update, e.hiredate)) as year_of_work,
		   split_part(e.email, '@', 2) as domain,
		   case
			   when e.employeeid in(select e.reportsto from employee e)
			   then 1
			   else 0
		   end as is_manager			
	from stg.employee e left join stg.department_budget db
	on e.departmentid = db.department_id
	order by e.employeeid
)
select *
from employee_x;

create table dwh.dim_employee as
	select e.*,
			db.department_name, db.budget,
			date_part('year', age(e.last_update, e.hiredate)) as year_of_work,
			split_part(e.email, '@', 2) as domain,
			case
				when e.employeeid in(select e.reportsto from employee e)
				then 1
				else 0
			end as is_manager			
	from stg.employee e left join stg.department_budget db
	on e.departmentid = db.department_id
	order by e.employeeid;


select *
from dim_employee de;


/* i selected all columns from the employee table, together with the department name
and budget columns from the department_budget table.
i calculated the years of work using the hiredate and last_update fields.
i used last_update because the database does not confirm that the employee is still active today.
i also used split_part to get the domain from the email address.
to check if an employee is a manager, i checked if the employeeid appears
in the reportsto column of another employee. if it appears there,
the employee is considered a manager. */


/* dim_track */


select *
from track t;


select *
from album a;


select *
from artist a ;


select *
from mediatype m;

select *
from genre g ;


with all_last_updates as (
    select last_update
    from stg.track
    
    union all
    
    select last_update
    from stg.album
    
    union all
    
    select last_update
    from stg.artist
    
    union all
    
    select last_update
    from stg.mediatype
    
    union all
    
    select last_update
    from stg.genre
 )
select
    min(last_update) as earliest_last_update,
    max(last_update) as latest_last_update,
    max(last_update) - min(last_update) as difference
from all_last_updates;


with track_x as(
	select t.trackid, t."name" as track_name, t.composer,
		   t.bytes, t.unitprice, t.last_update,
		   a.title, a2.artistid, a.albumid, a2."name" as artist_name,
		   m.mediatypeid, m."name" as media_type_name,
		   g.genreid, g."name" as genre_name,
		   t.milliseconds / 1000 as seconds,
		   to_char(make_interval(secs => t.milliseconds / 1000), 'mi:ss') as duration
	from stg.track t inner join stg.album a
	on t.albumid = a.albumid inner join stg.artist a2 
	on a.artistid = a2.artistid inner join stg.mediatype m
	on t.mediatypeid = m.mediatypeid inner join stg.genre g
	on t.genreid = g.genreid
)
select *
from track_x;


create table dwh.dim_track as
	select t.trackid, t."name" as track_name, t.composer,
		   t.bytes, t.unitprice, t.last_update,
		   a.title, a2.artistid, a.albumid, a2."name" as artist_name,
		   m.mediatypeid, m."name" as media_type_name,
		   g.genreid, g."name" as genre_name,
		   t.milliseconds / 1000 as seconds,
		   to_char(make_interval(secs => t.milliseconds / 1000), 'mi:ss') as duration
	from stg.track t inner join stg.album a
	on t.albumid = a.albumid inner join stg.artist a2 
	on a.artistid = a2.artistid inner join stg.mediatype m
	on t.mediatypeid = m.mediatypeid inner join stg.genre g
	on t.genreid = g.genreid;


select *
from dim_track dt;


/* the dim_track table was created by joining the album, artist, mediatype, and genre tables to the main track table.
when creating the table, there is no need to include duplicate join key columns from track,
such as albumid, mediatypeid, and genreid, because these columns are taken from the joined tables instead.
the artistid column is taken from the join between the album and artist tables.
i also checked the last_update values in all five related tables.
the difference between the earliest and latest last_update was less than 6 seconds,
so i kept only the last_update from the track table because the other last_update columns do not add meaningful information.
i also converted the track duration from milliseconds to seconds
and added another field that displays the duration in mm:ss format. */


/* fact_invoice */

select *
from invoice i;

select distinct(i.billingcountry)
from invoice i
order by 1; 

select *
from customer c;

select count(distinct(i.billingaddress))
from invoice i;

select count(distinct(c.address))
from customer c;


select i.billingaddress
from invoice i
except 
select c.address
from customer c;


select c.address
from customer c
except
select i.billingaddress
from invoice i;


with invoice_x as (
	select *
	from stg.invoice i
)
select *
from invoice_x;


create table dwh.fact_invoice as
	select *
	from stg.invoice i;


/* i created the fact_invoice table using all columns from the invoice table,
including the billing address fields.
i decided to keep the address fields after comparing the billing addresses in invoice
with the customer addresses. first, i compared the number of unique addresses and found
one additional billing address. then, i used except and found the address that does not
appear in the customer table. */


/* fact_invoiceline */


select *
from invoiceline i;

select MAX(i.quantity)
from invoiceline i;


with invoiceline_x as(
	select *,
		   i.quantity * i.unitprice as line_total
	from stg.invoiceline i
)
select *
from invoiceline_x;


create table dwh.fact_invoiceline as
	select *,
		   i.quantity * i.unitprice as line_total
	from stg.invoiceline i;


/* i created the fact_invoiceline table using all columns from the invoiceline table,
together with an additional column that calculates the line_total by multiplying
the quantity by the unit price. */



/* run validation checks */


select *
from dim_playlist dp;


select count(*) as total_rows,
	   count(distinct(dp.playlistid)) as unique_playlist
from dim_playlist dp;


select count(*) as total_rows,
	   count(distinct(dp.trackid)) as unique_track
from dim_playlist dp;


select count(*) as total_rows,
	   count(distinct(dc.customerid )) as unique_customer
from dim_customer dc;


select count(*) as total_rows,
	   count(distinct(de.employeeid)) as unique_employee
from dim_employee de;


select count(*) as total_rows,
	   count(distinct(dt.trackid)) as unique_track
from dim_track dt;


select count(*) as total_rows,
	   count(distinct(fi.invoiceid)) as unique_invoice
from fact_invoice fi;


select count(*) as total_rows,
	   count(distinct(fil.invoicelineid)) as unique_invoiceline
from fact_invoiceline fil;


select count(*) as total_rows,
       count(distinct invoicedate) as unique_dates,
       count(*) - count(invoicedate) as null_dates
from dwh.dim_currency;


/* add primary keys */


alter table dwh.dim_customer
add primary key (customerid);

alter table dwh.dim_employee
add primary key (employeeid);

alter table dwh.dim_track
add primary key (trackid);

alter table dwh.dim_playlist
add primary key (playlistid, trackid);

alter table dwh.fact_invoice
add primary key (invoiceid);

alter table dwh.fact_invoiceline
add primary key (invoicelineid);

alter table dwh.dim_currency
add primary key (invoicedate);


/* add foreign keys */


alter table dwh.fact_invoice
add foreign key (customerid)
references dwh.dim_customer(customerid);

alter table dwh.fact_invoiceline
add foreign key (invoiceid)
references dwh.fact_invoice(invoiceid);

alter table dwh.fact_invoiceline
add foreign key (trackid)
references dwh.dim_track(trackid);

alter table dwh.dim_customer
add foreign key (supportrepid)
references dwh.dim_employee(employeeid);

alter table dwh.dim_playlist
add foreign key (trackid)
references dwh.dim_track(trackid);



/* important remark! */


/* while reviewing the country values, i found that the same country appeared
under two different names: 'USA' and 'United States'.
to avoid inconsistent results in the analyses, i standardized the country value
by updating 'USA' to 'United States' in the billingcountry column
of the fact_invoice table. */


update dwh.fact_invoice 
set billingcountry = 'United States'
where billingcountry  = 'USA';


/* --- data analysis dwh --- */

/* 1 */


select *
from dim_playlist dp;


select dp.playlistid, dp."name",
       count(dp.trackid) as total_tracks
from dim_playlist dp
group by dp.playlistid, dp."name"
order by total_tracks asc;


select dp.playlistid, dp."name",
       count(dp.trackid) as total_tracks
from dim_playlist dp
group by dp.playlistid, dp."name"
order by total_tracks desc;


with playlist_summary as (
    select dp.playlistid,
           dp."name" as playlist_name,
           count(dp.trackid) as total_tracks
    from dim_playlist dp
    group by 1,2
), playlist_rank as (
    select playlistid, playlist_name, total_tracks,
           dense_rank() over (order by total_tracks desc) as max_rank,
           dense_rank() over (order by total_tracks asc) as min_rank,
           avg(total_tracks) over () as avg_tracks
    from playlist_summary
)
select playlistid, playlist_name,
       total_tracks, avg_tracks,
	   case
	       when max_rank = 1 then 'max'
	       when min_rank = 1 then 'min'
	   end as playlist_type
from playlist_rank
where max_rank = 1
   or min_rank = 1;


/* before this analysis, i used two validation queries to check if there were ties
for the playlists with the highest and lowest number of tracks.
because ties were found, this analysis uses dense_rank to make sure that all playlists
with the same highest or lowest number of tracks are included in the result
the playlists are ranked once from highest to lowest and once from lowest to highest,
and only the playlists with rank 1 in either direction are displayed.
the analysis also calculates the average number of tracks per playlist. */


/* 2 */
select *
from fact_invoice fi;


select *
from fact_invoiceline fi;

select *
from dim_track dt;


with songs_rank as (
	select dt.trackid, dt.track_name,
		   count(fi.trackid) as num_of_sales 
	from dim_track dt left join fact_invoiceline fi
	on dt.trackid = fi.trackid
	group by 1,2
), songs_groups as(
	select
	   case
	   		when num_of_sales = 0 then '0'
	   		when num_of_sales between 1 and 5 then '1-5'
	   		when num_of_sales between 6 and 10 then '6-10'
	   		else '>10'
	   end as song_team	   
	from songs_rank
)
select song_team,
	   count(*) as num_of_songs
from songs_groups
group by 1
order by 2 desc;


/* this analysis divides all tracks into four groups based on the number of sales.
i used a left join so tracks with no sales are also included in the result.
i used the 6-10 group to avoid overlap with the 1-5 group. */


/* 3 */


select *
from fact_invoice fi;


select distinct(fi.billingcountry)
from fact_invoice fi;

select count(distinct(fi.billingcountry))
from fact_invoice fi;



with sales_per_country as (
	select fi.billingcountry,
		   sum(fi.total) as total_amount
	from fact_invoice fi
	group by 1
)
(
select *
from sales_per_country
order by total_amount desc 
limit 5
)
union all
(
select *
from sales_per_country 
order by total_amount asc
limit 5
);


/* question 3 part b */


select *
from fact_invoiceline fi;


with sales_per_country as (
	select fi.billingcountry,
		   sum(fi.total) as total_amount
	from fact_invoice fi
	group by 1
), top_bottom_5 as (
	(
	select billingcountry
	from sales_per_country
	order by total_amount desc 
	limit 5
	)
	union all
	(
	select billingcountry
	from sales_per_country 
	order by total_amount asc
	limit 5
	)
), genre_per_country as(
	select top_bottom_5.billingcountry,
		   sum(fi2.line_total) as total_sales,
		   dt.genreid, dt.genre_name
	from top_bottom_5 inner join fact_invoice fi
	on top_bottom_5.billingcountry = fi.billingcountry inner join fact_invoiceline fi2
	on fi.invoiceid = fi2.invoiceid inner join dim_track dt
	on fi2.trackid = dt.trackid
	group by 1,3,4
), country_total as (
	select *,
	       sum(total_sales) over  (partition by billingcountry) as total_amount
	from genre_per_country
), percent_per_genre as (
	select *,
		   round(total_sales / total_amount * 100,2) as sales_percent
	from country_total
), genre_rank as (
    select *,
           rank() over (partition by billingcountry order by sales_percent desc) as genre_rank
    from percent_per_genre
)
select *
from genre_rank
order by 1,7;


/* this analysis first identifies the top 5 and bottom 5 countries by total sales.
for these countries, it calculates the sales amount for each genre,
the percentage of each genre from the total country sales,
and ranks the genres inside each country by their sales percentage. */


/* 4 */


select *
from  fact_invoice fi;


with country_customer as (
	select fi.billingcountry,
		   count(distinct(fi.customerid)) as total_customers,
		   count(fi.invoiceid) as total_orders,
		   sum(fi.total) as total_amount,
			   case
			   	when count(distinct(fi.customerid)) = 1 then 'Other'
			   	else fi.billingcountry
			   end as country		   
	from fact_invoice fi
	group by 1
), country_other as (
	select country,
		   sum(total_customers) as country_customer,
		   sum(total_amount) as country_amount,
		   sum(total_orders) as country_orders
	from country_customer
	group by 1
), country_summary as (
	select country, country_customer,
		   round(country_orders / country_customer, 2) as avg_order_per_customer,
		   round(country_amount / country_customer ,2) as avg_amount_per_customer
	from country_other
)
select *
from country_summary
order by 1;


/* this analysis calculates the number of customers, average orders per customer,
and average revenue per customer for each country.
countries with only one customer are grouped together under 'other'. */


/* 5 */


select *
from dim_employee de;

select *
from fact_invoice fi;

select *
from fact_invoiceline fi;

select *
from dim_customer dc;


with employees_data as (
	select de.employeeid,
		   concat(de.firstname, ' ', de.lastname) as full_name,
		   de.year_of_work, fi.customerid, fi.invoiceid,
		   extract(year from fi.invoicedate) as year, fi.total 
	from dim_employee de inner join dim_customer dc
	on de.employeeid = dc.supportrepid inner join fact_invoice fi
	on dc.customerid = fi.customerid
), per_year as (
	select employeeid, full_name, year_of_work, "year",
		   count(distinct(customerid)) as customers_per_year,
		   sum(total) as year_total
	from employees_data
	group by 1, 2, 3, 4
), prev_year as (
	select *,
		   lag(year_total) over (partition by employeeid order by "year") as prev_year_sales
	from per_year
), employees_summary as (
	select *,
		   round((year_total - prev_year_sales) / prev_year_sales * 100, 2) as growth_percent
	from prev_year
)
select *
from employees_summary;


/* this analysis shows each employee's years of work, the number of unique customers
handled each year, and the yearly sales growth compared to the previous year. */



/* additional sql analyses - questions 6, 7 and 8 */


/* 6 */


/* sales seasonality by country:
for each of the top 10 countries by total sales,
identify the best and worst sales month
and calculate the difference between them.*/



with countries_sales as (
	select fi.billingcountry,
		   extract(month from fi.invoicedate) as month,
		   sum(fi.total) as sales_amount_per_month,
		   sum(sum(fi.total)) over (partition by fi.billingcountry) as country_total_sales
	from fact_invoice fi 
	group by 1, 2
), top_10_countries as (
	select distinct(billingcountry) as country, 
		   country_total_sales
	from countries_sales
	order by 2 desc 
	limit 10
), top_countries_sales as (
	select countries_sales.*
	from countries_sales inner join top_10_countries
	on countries_sales.billingcountry = top_10_countries.country
), rank_month as (
	select *,
		   rank() over (partition by billingcountry order by sales_amount_per_month desc) as rank_best,
		   rank() over (partition by billingcountry order by sales_amount_per_month asc) as rank_worst
	from top_countries_sales
), best_worst as (
	select *
	from rank_month
	where rank_best = 1
		or rank_worst =1
), summary as (
    select 
        billingcountry,
        MAX(case when rank_best = 1 then month end) AS best_month,
        MAX(case when rank_best = 1 then sales_amount_per_month end) as best_sales,
        MAX(case when rank_worst = 1 then month end) AS worst_month,
        MAX(case when rank_worst = 1 then sales_amount_per_month end) as worst_sales,
        MAX(case when rank_best = 1 then sales_amount_per_month end) -
        MAX(case when rank_worst = 1 then sales_amount_per_month end) as sales_difference
    FROM best_worst
    GROUP BY 1
)
select *
from summary;


/*
The purpose of this analysis was to focus on the 10 countries with the highest total sales
and check the sales performance by month.
For each country, I calculated the total sales for every month across all years,
then ranked the months from the highest sales to the lowest and also from the lowest to the highest.
This made it possible to identify the best and worst sales month for each of the top 10 countries
and compare the difference between them.
The idea behind this analysis is to find possible seasonal patterns and understand
which months usually perform better or worse in each country, so this information can support
better decisions such as promotions, marketing activity, and preparation for stronger or weaker sales periods.*/


/* 7 */


/* customer concentration by country:
For countries with at least 10 customers,
check how much of the total sales comes from the top 3 customers
and classify the concentration level.*/


select fi.billingcountry ,count(distinct(fi.customerid))
from fact_invoice fi
group by 1
order by 2 desc;


with ten_customers_country as (
	select fi.billingcountry,
		   sum(fi.total) as total_country_amount,
		   count(distinct(fi.customerid)) as unique_customers
	from fact_invoice fi
	group by 1
	having count(distinct(fi.customerid)) >= 10
), customer_data as (
	select ten_customers_country.*, fi.customerid,
		   sum(fi.total) as customer_amount
	from ten_customers_country inner join fact_invoice fi
	on ten_customers_country.billingcountry = fi.billingcountry
	group by 1, 2, 3, 4
), rank_customers as (
	select *,
		   row_number() over (partition by billingcountry order by customer_amount desc) as rank_
	from customer_data
), top_3_customers as (
	select *
	from rank_customers
	where rank_ < 4
), sum_top_customers as (
	select *,
		   sum(customer_amount) over (partition by billingcountry) as top_customers_amount
	from top_3_customers
), concentration_ as (
	select distinct(billingcountry), total_country_amount,
		   unique_customers, top_customers_amount,
	       round(top_customers_amount / total_country_amount * 100, 2) as sales_percent
	from sum_top_customers
), summary as (
	select *,
		   case
		   	when sales_percent < 25 then 'low concentration'
		   	when sales_percent >= 25 and sales_percent < 50 then 'medium concentration'
		   	else 'high concentration'
		   end as concentration_level	   
	from concentration_
)
select *
from summary
order by 5 desc;


/* customer concentration by country:
this analysis checks how dependent each country is on its top customers.
i included only countries with at least 10 unique customers to make the result more meaningful.
for each country, i calculated the sales of every customer and used row_number
to select exactly the top 3 customers, even when several customers had the same sales amount.
then i calculated what percentage of the country's total sales came from those top 3 customers
and classified the concentration level as low, medium, or high.
below 25% is considered low concentration,
25% to below 50% is considered medium concentration,
and 50% and above is considered high concentration.
the goal is to identify countries where sales depend heavily on a small number of customers. */


/* 8 */

/* customer retention and repeat purchases:
divide customers into groups based on the number of orders they made
and compare the number of customers, total orders, average orders per customer,
total revenue, and average revenue per customer.
the goal is to understand customer retention and how important returning customers
are to the company's sales. */


with customer_summary as (
    select customerid,
           count(distinct invoiceid) as num_of_orders,
           sum(total) as total_revenue
    from fact_invoice
    group by customerid
), customer_groups as (
    select *,
           case
               when num_of_orders = 1 then '1 order'
               when num_of_orders between 2 and 3 then '2-3 orders'
               else '4+ orders'
           end as customer_group
    from customer_summary
)
select customer_group,
       count(customerid) as num_of_customers,
       sum(num_of_orders) as num_of_orders,
       round(avg(num_of_orders), 2) as avg_orders_per_customer,
       round(sum(total_revenue), 2) as total_revenue,
       round(avg(total_revenue), 2) as avg_revenue_per_customer
from customer_groups
group by customer_group
order by 1;


/* the analysis shows that the number of customers increases in the groups with a higher number of orders.
this means that many customers do not make only one purchase, but return and place more orders.
returning customers also generate higher revenue, which shows how important repeat purchases are to the company's sales.
these results can help the company understand customer behavior and focus on encouraging customers to make more purchases in the future. */




