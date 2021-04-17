CREATE TABLE config (
	id int8 NOT NULL GENERATED ALWAYS AS IDENTITY,
	shopify_api_key varchar NOT NULL,
	shopify_password varchar NOT NULL,
	shopify_shop_subdomain varchar NOT NULL,
	shopify_shared_secret varchar NOT NULL,
	cassaincloud_api_key varchar NOT NULL,
	cassaincloud_x_version varchar NULL DEFAULT '1.0.0'::character VARYING
	CONSTRAINT config_pkey PRIMARY KEY (id)
);


CREATE TABLE public.shopify_products (
	shop text NOT NULL,
	product_id text NOT NULL,
	product_json jsonb NULL,
	image jsonb NULL,
	title text NULL,
	vendor text NULL,
	tags text NULL,
	"timestamp" timestamp NULL,
	product_type text NULL,
	CONSTRAINT shopify_products_pkey PRIMARY KEY (shop, product_id)
);
CREATE INDEX idxginp_image ON public.shopify_products USING gin (image jsonb_path_ops);
CREATE INDEX idxginp_product_json ON public.shopify_products USING gin (product_json jsonb_path_ops);
                
      
create or replace function get_element_list(p_value jsonb, p_keyname text)
  returns text
as 
$$ 
   select string_agg(x.val ->> p_keyname, '|')
   from jsonb_array_elements(p_value) as x(val);
$$
language sql;

create or replace function get_flat_list(p_value jsonb)
  returns text
as 
$$ 
   select string_agg(x.val, '|')
   from jsonb_array_elements_text(p_value) as x(val);
$$
language sql;

create view v_categories as
select distinct 
	product_type as id,
	product_type as descrizione
from
	public.shopify_products;


create or replace view v_options as
select name as id, name as descrizione, string_agg(opts, '|') as valori from (
select distinct
options.name,
jsonb_array_elements_text(values) as opts
from
	shopify_products as products,
	jsonb_to_recordset(products.product_json -> 'options') as 
	options(id text, name text, values jsonb)
order by 1,2) propts
group by name;

create or replace view v_items as
select
	cast(product_id as int8) as id,
	title as descrizione,
	title as "Descrizione Pulsante",
	product_type as "Id Categoria",
	'Gioielleria' as "Id Reparto",
	CAST(product_json -> 'variants' -> 0 ->> 'price' AS float4) as prezzo,
	false as "Prodotto Venduto al Peso",
	null as tara,
	null as icona,
	replace(tags,', ','|') as tags,
	case when jsonb_array_length(product_json -> 'variants') > 1 then true else false end as multivariante,
	case when jsonb_array_length(product_json -> 'variants') > 1 then null else cast(product_json -> 'variants' -> 0 ->> 'inventory_item_id' as int8) end as "Barcode Interno",
	case when jsonb_array_length(product_json -> 'variants') > 1 then null else product_json -> 'variants' -> 0 ->> 'sku' end as "Id Interno",
	title as "Descrizione Scontrino",
	get_element_list(product_json -> 'options', 'id') as attributi,
	null as colore 
from
	public.shopify_products;


create or replace view v_skus as
select
	cast(variants.product_id as int8) as "Id Item",
	cast(variants.id as int8)  as "Id Sku",
	null as "[Size]",
	null as "[Colore]",
	null as "[Taglia]",
	null as "[Iniziale]",
	null as "[Fantasia]",
	variants.price  as prezzo,
	cast(variants.inventory_item_id as int8) as "Barcode Interno",
	variants.sku as "Id Interno"
from
	shopify_products as products,
	jsonb_to_recordset(products.product_json -> 'variants') as 
	variants(id text, product_id text, price float4, sku text, inventory_item_id text, title text, option1 text, option2 text, option3 text)
where jsonb_array_length(product_json -> 'variants') > 1;


create or replace view v_costs as
select
	cast(variants.product_id as int8) as "Id / Barcode di Vendita",
	cast(1 as int8)  as "ID Fornitore",
	1  as costo,
	'Gioielleria' as "ID Reparto",
	null as "Sconto 1",
	null as "Sconto 2",
	null as "Sconto 3",
	null as "Sconto 4",
	null as "Codice Interno Fornitore",
	null as "Barcode Fornitore"	
from
	shopify_products as products,
	jsonb_to_recordset(products.product_json -> 'variants') as 
	variants(id text, product_id text , sku text)
where variants.sku = '' ;

create or replace view v_stocks_items as
select
	cast(products.product_id as int8) as "Id / Barcode di Vendita",
	case when jsonb_array_length(product_json -> 'variants') > 1 then null else true end as "Magazzino Attivo",
	case when jsonb_array_length(product_json -> 'variants') > 1 then null else 10000 end as "Soglia di Allarme", 
	case when jsonb_array_length(product_json -> 'variants') > 1 then null else cast(product_json -> 'variants' -> 0 ->> 'inventory_quantity' as int8) end as giacenza
from
	shopify_products as products
where jsonb_array_length(product_json -> 'variants') = 1;

create or replace view v_stocks_skus as
select
	cast(variants.id as int8) as "Id / Barcode di Vendita",
	true as "Magazzino Attivo",
	10000 as "Soglia di Allarme",
	cast(variants.inventory_quantity as int8) as giacenza
from
	shopify_products as products,
jsonb_to_recordset(products.product_json -> 'variants') as variants(id text, product_id text, sku text, inventory_quantity text)
where jsonb_array_length(product_json -> 'variants') > 1;




