

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."action_type" AS ENUM (
    'Mise à jour budget',
    'Retour',
    'Lot de vente',
    'Archivage appareil',
    'Vente lot',
    'Reverse',
    'Nettoyage',
    'Mise en test',
    'Réception',
    'Rack soldeur',
    'Démontage terminé',
    'Démontage',
    'Qualité',
    'Logistique'
);


ALTER TYPE "public"."action_type" OWNER TO "postgres";


CREATE TYPE "public"."aftersales_status" AS ENUM (
    'Terminé',
    'En cours'
);


ALTER TYPE "public"."aftersales_status" OWNER TO "postgres";


CREATE TYPE "public"."brand_grade" AS ENUM (
    'Rang A',
    'Rang B',
    'Rang Premium'
);


ALTER TYPE "public"."brand_grade" OWNER TO "postgres";


CREATE TYPE "public"."device_grade" AS ENUM (
    'Platinum',
    'Gold',
    'Silver',
    'Bronze'
);


ALTER TYPE "public"."device_grade" OWNER TO "postgres";


CREATE TYPE "public"."reparation_status" AS ENUM (
    'En cours',
    'Attente validation diagnostic',
    'Invalidation - diagnostic',
    'Invalidation - DEEE (diagnostic)',
    'En cours de réparation',
    'Attente validation réparation',
    'Attente invalidation réparation',
    'Invalidation - réparation',
    'Invalidation - DEEE (réparation)',
    'Terminé'
);


ALTER TYPE "public"."reparation_status" OWNER TO "postgres";


CREATE TYPE "public"."sub_type_aftersales" AS ENUM (
    'declaration',
    'evolution',
    'conclusion'
);


ALTER TYPE "public"."sub_type_aftersales" OWNER TO "postgres";


CREATE TYPE "public"."sub_type_reparation" AS ENUM (
    'initial_diagnostic',
    'initial_repair',
    'quality_nc_diagnostic',
    'quality_nc_repair'
);


ALTER TYPE "public"."sub_type_reparation" OWNER TO "postgres";


CREATE TYPE "public"."user_roles" AS ENUM (
    'Pièces détachées',
    'Logistique',
    'Qualité',
    'Nettoyage',
    'Sales',
    'Réparation',
    'Supply',
    'Admin',
    'Super admin',
    'Admin pièces détachées',
    'Admin logistique',
    'Admin qualité',
    'Admin nettoyage',
    'Admin sales',
    'Admin réparation',
    'Admin supply'
);


ALTER TYPE "public"."user_roles" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."device_budget"("device_id_param" "uuid", "action_id_param" "uuid", "custom_price_param" real) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$--script for device budget after reception, after miseEnTest, after diag, after repar etc >> see doc made by Max

begin





end;$$;


ALTER FUNCTION "public"."device_budget"("device_id_param" "uuid", "action_id_param" "uuid", "custom_price_param" real) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_action_details"("action_id_param" "uuid") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$select
  json_build_object(
    'status',
    da.status,
    'sub_area_name',
    sas.name,
    'area_name',
    astorage.name,
    'repair_type',
    lastrepair.type,
    'repair_status',
    lastrepair.status,
    'functional_device',
    lastrepair.functional_device,
    'refill_done',
    lastrepair.refill_done,
    'error_code',
    lastrepair.error_code,
    'diag_request_email',
    diagrequest.creator,
    'diag_valid_email',
    diagvalid.creator,
    'repair_request_email',
    repairrequest.creator,
    'repair_valid_email',
    repairvalid.creator,
    'tests_pre',
    testspre.alltestspre,
    'tests_post',
    testspost.alltestspost,
    'failures',
    failures.allfailures,
    'quality_grade',
    quality.grade,
    'wholesale',
    quality.wholesale,
    'nogo_reason',
    quality.nogo_reason,
    'imperfection',
    quality.imperfection,
    'custom_sale_price',
    salelot.custom_sale_price,
    'salelot_status',
    salelot.status,
    'salelot_name',
    salelot.name,
    'aftersales_status',
    aftersales.status,
    'comments',
    CASE
      WHEN lastrepair.comments IS NOT NULL THEN lastrepair.comments
      WHEN quality.comments IS NOT NULL THEN quality.comments
      WHEN aftersales.comments IS NOT NULL THEN aftersales.comments
      ELSE NULL
    END
  ) as result
from
  public.device_actions da
  join public.sub_areas_storage sas on da.sub_area_storage_id = sas.id
  join public.areas_storage astorage on sas.areas_storage_id = astorage.id
  left join lateral (
    select
      u.email as creator
    from
      public.device_actions_reparations dar
      join public.users u on u.id = dar.creator
    where
      action_id_param = dar.action_id
      and (
        (
          da.type = 'Mise en test'
          and dar.status = 'Attente validation diagnostic'
          and dar.type = 'initial_diagnostic'
        )
        or (
          da.type = 'Retour interne - réparation'
          and dar.status = 'Attente validation'
          and dar.type = 'quality_nc_diagnostic'
        )
      )
      and dar.archived is false
    order by
      dar.created_at asc
    limit
      1
  ) diagrequest on true
  left join lateral (
    select
      u.email as creator
    from
      public.device_actions_reparations dar
      join public.users u on u.id = dar.creator
    where
      action_id_param = dar.action_id
      and (
        (
          da.type = 'Mise en test'
          and dar.status = 'En cours de réparation'
          and dar.type = 'initial_diagnostic'
        )
        or (
          da.type = 'Retour interne - réparation'
          and dar.status = 'En cours de réparation'
          and dar.type = 'quality_nc_diagnostic'
        )
      )
      and dar.archived is false
    order by
      dar.created_at asc
    limit
      1
  ) diagvalid on true
  left join lateral (
    select
      u.email as creator
    from
      public.device_actions_reparations dar
      join public.users u on u.id = dar.creator
    where
      action_id_param = dar.action_id
      and (
        (
          da.type = 'Mise en test'
          and dar.status = 'Attente validation réparation'
          and dar.type = 'initial_repair'
        )
        or (
          da.type = 'Retour interne - réparation'
          and dar.status = 'Attente validation réparation'
          and dar.type = 'quality_nc_repair'
        )
      )
      and dar.archived is false
    order by
      dar.created_at asc
    limit
      1
  ) repairrequest on true
  left join lateral (
    select
      u.email as creator
    from
      public.device_actions_reparations dar
      join public.users u on u.id = dar.creator
    where
      action_id_param = dar.action_id
      and (
        (
          da.type = 'Mise en test'
          and dar.status = 'Terminé'
          and dar.type = 'initial_repair'
        )
        or (
          da.type = 'Retour interne - réparation'
          and dar.status = 'Terminé'
          and dar.type = 'quality_nc_repair'
        )
      )
      and dar.archived is false
    order by
      dar.created_at asc
    limit
      1
  ) repairvalid on true
  left join lateral (
    select
      dar.id,
      dar.comments,
      dar.status,
      dar.type,
      dar.error_code,
      dar.refill_done,
      dar.functional_device
    from
      public.device_actions_reparations dar
    where
      action_id_param = dar.action_id
      and dar.archived is false
    order by
      dar.created_at desc
    limit
      1
  ) lastrepair on true
  left join lateral (
    select
      array_agg(dt.name) as alltestspre
    from
      public.device_actions_reparation_tests dart
      join public.device_tests dt on dart.test_id = dt.id
    where
      dart.reparation_id = lastrepair.id
      and dart.archived is false
      and dart.type = 'pre'
  ) testspre on true
  left join lateral (
    select
      array_agg(dt.name) as alltestspost
    from
      public.device_actions_reparation_tests dart
      join public.device_tests dt on dart.test_id = dt.id
    where
      dart.reparation_id = lastrepair.id
      and dart.archived is false
      and dart.type = 'post'
  ) testspost on true
  left join lateral (
    select
      array_agg(dmf.name) as allfailures
    from
      public.device_actions_reparation_failures darf
      join public.device_micro_failures dmf on darf.micro_failure_id = dmf.id
    where
      darf.reparation_id = lastrepair.id
      and darf.archived is false
  ) failures on true
  left join lateral (
    select
      daq.grade,
      daq.wholesale,
      daq.nogo_reason,
      daq.imperfection,
      daq.comments
    from
      public.device_actions_quality daq
    where
      da.type = 'Qualité'
      and action_id_param = daq.action_id
      and daq.archived is false
    order by
      daq.created_at desc
    limit
      1
  ) quality on true
  left join lateral (
    select
      dasl.custom_sale_price,
      dasl.status,
      spl.name
    from
      public.device_actions_sales_lot dasl
      join public.sales_purchase_lots spl on dasl.sale_lot_id = spl.id
    where
      dasl.action_id = action_id_param
      and dasl.archived is false
  ) salelot on true
  left join lateral (
    select
      daa.status,
      daa.justified_comments as comments
    from
      public.device_actions_aftersales daa
    where
      daa.action_id = action_id_param
      and daa.archived is false
  ) aftersales on true
where
  da.id = action_id_param;$$;


ALTER FUNCTION "public"."get_action_details"("action_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_area_occupation_rate"("org_id_param" "uuid", "area_id_param" "uuid") RETURNS numeric
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
    SELECT 
        COALESCE(SUM(current_devices.count), 0)::numeric / NULLIF(SUM(sas.capacity), 0)
    FROM 
        public.sub_areas_storage sas
        JOIN public.areas_storage a ON a.id = sas.areas_storage_id
        JOIN public.areas_categories ac ON ac.id = a.area_category_id
    LEFT JOIN (
        SELECT 
            latest_actions.sub_area_storage_id,
            COUNT(DISTINCT latest_actions.device_id) AS count
        FROM (
            SELECT DISTINCT ON (device_id)
                device_id,
                sub_area_storage_id
            FROM 
                public.device_actions
            WHERE 
                archived = false
            ORDER BY 
                device_id, last_edit DESC
        ) AS latest_actions
        WHERE 
            latest_actions.sub_area_storage_id IS NOT NULL
        GROUP BY 
            latest_actions.sub_area_storage_id
    ) AS current_devices ON sas.id = current_devices.sub_area_storage_id
    WHERE 
        ac.category = 'devices' 
        AND ac.organization_id = org_id_param
        AND sas.areas_storage_id = area_id_param;
$$;


ALTER FUNCTION "public"."get_area_occupation_rate"("org_id_param" "uuid", "area_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_areas_filter"("org_id_param" "uuid", "area_cat_param" "text") RETURNS json[]
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$DECLARE
    result json[];
BEGIN
    SELECT array_agg(row_to_json(t))
    INTO result
    FROM (
        SELECT 
            a.name,
            a.id
        FROM 
            public.areas_storage a
            JOIN public.areas_categories ac ON ac.id = a.area_category_id
        WHERE 
            (area_cat_param is null or ac.category = area_cat_param)
            AND ac.organization_id = org_id_param
        ORDER BY 
            a.name ASC
    ) t;
    
    RETURN COALESCE(result, '{}');
END;$$;


ALTER FUNCTION "public"."get_areas_filter"("org_id_param" "uuid", "area_cat_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_brand_details"("model_param" "text") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$select
  json_build_object(
    'id',
    b.id,
    'name',
    b.name,
    'sp_serialnbformat_criteria',
    b.sp_serialnbformat_criteria,
    'subcat_name',
    dssc.name,
    'subcat_id',
    dssc.id
  )
from
  public.brands b
  join public.device_references dr on dr.brand_id = b.id
  join public.device_service_sub_categories dssc on dssc.id = dr.device_service_sub_category_id
where
  dr.model = model_param
  and dr.archived is false
limit
  1;$$;


ALTER FUNCTION "public"."get_brand_details"("model_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clients"("organization_id_param" "uuid" DEFAULT NULL::"uuid", "offset_value" bigint DEFAULT 0) RETURNS json[]
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$SELECT array_agg(
      jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'archived', c.archived,
        'contacts', COALESCE(
          (SELECT array_agg(cc.email)
          FROM public.client_contacts cc 
          WHERE cc.client_id = c.id), 
          ARRAY[]::text[]
        ),
        'sales_group_id', g.id,
        'sales_group_name', g.name,
        'address1',c.address,
        'address2',c.address_complement,
        'zip',c.zipcode,
        'city',c.city,
        'country',c.country,
        'comments',c.comments
      )
    )
    FROM
      public.clients c
      LEFT JOIN public.client_supplier_groups g ON c.group_id = g.id
    WHERE
      c.owner_id = organization_id_param
    LIMIT 10
    OFFSET offset_value;$$;


ALTER FUNCTION "public"."get_clients"("organization_id_param" "uuid", "offset_value" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_actions"("param_id" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$--script to list actions for a given device + some subaction data, for page deviceDetails

declare result json;

begin
set
  search_path = '';

select
  json_agg(row_to_json(device_data)) into result
from
  (
    select
      da.id,
      da.type,
      da.created_at,
      u.email as creator,
      reception.compliance,
      reception.grade as reception_grade,
      reception.prequalif_comments,
      reception.prequalif,
      da.finished,
      repar.status as repar_status,
      aftersales.status as aftersales_status,
      aftersales.output as aftersales_output
    from
      public.device_actions da
      left join public.users u on da.creator = u.id
      left join lateral (
        select
          *
        from
          public.device_actions_aftersales daa
        where
          da.id = daa.action_id
        order by
          created_at desc
        limit
          1
      ) aftersales on true
      left join lateral (
        select
          status
        from
          public.device_actions_reparations darep
        where
          da.id = darep.action_id
        order by
          created_at desc
        limit
          1
      ) repar on true
      left join lateral (
        select
          *
        from
          public.device_actions_reception darec
        where
          da.id = darec.action_id
        order by
          created_at desc
        limit
          1
      ) reception on true
    where
      da.device_id = param_id
    order by
      da.created_at desc
  ) device_data;

RETURN result;

end;$$;


ALTER FUNCTION "public"."get_device_actions"("param_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_areadata"("device_id_param" "uuid") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$SELECT 
        json_build_object(
            'sub_area_id', sas.id,
            'sub_area_name', sas.name,
            'area_id', a.id,
            'area_name', a.name,
            'area_type', ac.name
        ) AS result
    FROM 
        public.device_actions da
        JOIN public.sub_areas_storage sas ON da.sub_area_storage_id = sas.id
        JOIN public.areas_storage a ON a.id = sas.areas_storage_id
        JOIN public.areas_categories ac ON ac.id = a.area_category_id
    WHERE 
        da.device_id = device_id_param
    ORDER BY 
        da.created_at DESC 
    LIMIT 1;$$;


ALTER FUNCTION "public"."get_device_areadata"("device_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_details"("id_param" "uuid" DEFAULT NULL::"uuid", "barcode_param" "text" DEFAULT NULL::"text", "organization_param" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$--script for page deviceDetails

declare result json;

begin
select
  row_to_json(device_data) into result
from
  (
    select
      d.id,
      d.created_at,
      dareception.creator,
      d.barcode,
      dssc.name as service_sub_category_name,
      dssc.name as service_sub_category_id,
      dss.name as sub_service_name,
      b.name as brand_name,
      dr.model as model,
      dr.id as model_id,
      dr.price_new,
      dr.color,
      dr.year_production,
      d.status,
      da.area_type,
      da.area_name,
      da.sub_area_name,
      da.sub_area_id,
      da.created_at as last_action_date,
      purchlot.lotname as purchase_lot,
      purchlot.sourcename as source,
      purchlot.salesman_lot,
      purchlot.device_pricing_mode,
      daaftst.status as status_aftersales,
      dareparstatus.status as status_repar,
      total_price.sum as sp_budget,
      dabudgetprediag.prediag_addedvalue as prediag_addedvalue,
      dabudgetprediag.purchase_price,
      salelot.name as sale_lot,
      d.imported_youzd,
      d.archived,
      (
        select
          MIN(sip.sale_price)
        from
          public.sales_invoice_import sip
        where
          sip.device_id = d.id
      ) as sale_price_invoicing,
      array(
        select
          file_url
        from
          public.devices_files df
        where
          df.device_id = d.id
          and df.type = 'defective_sp_reception'
          and df.archived is false
      ) as defective_sp_reception_files,
      array(
        select
          file_url
        from
          public.devices_files df
        where
          df.device_id = d.id
          and df.type = 'nameplate'
          and df.archived is false
      ) as nameplate_files
    from
      public.devices d
      left join public.device_references dr on d.device_reference_id = dr.id
      left join public.device_service_sub_categories dssc on dr.device_service_sub_category_id = dssc.id
      left join public.device_service_categories dsc on dssc.device_service_category_id = dsc.id
      left join public.device_sub_services dss on dsc.device_sub_service_id = dss.id
      left join public.brands b on dr.brand_id = b.id
      left join lateral (
        select
          da.created_at,
          sa.id as sub_area_id,
          sa.name as sub_area_name,
          a.name as area_name,
          ac.name as area_type
        from
          public.device_actions da
          join public.sub_areas_storage sa on da.sub_area_storage_id = sa.id
          join public.areas_storage a on sa.areas_storage_id = a.id
          join public.areas_categories ac on a.area_category_id = ac.id
        where
          da.device_id = d.id
        order by
          da.created_at desc
        limit
          1
      ) da on true
      left join lateral (
        select
          daa.status
        from
          public.device_actions_aftersales daa
          join public.device_actions da on da.id = daa.action_id
        where
          da.device_id = d.id
          and da.type ilike '%retour%'
          and daa.action_id = da.id
        order by
          da.created_at desc
        limit
          1
      ) daaftst on true
      
      left join lateral (
        select
          dar.status
        from
          public.device_actions_reparations dar
          join public.device_actions da on da.id = dar.action_id
        where
          da.device_id = d.id
          and da.type ilike 'Mise en test'
          and dar.action_id = da.id
        order by
          da.created_at desc,
          dar.created_at desc
        limit
          1
      ) dareparstatus on true
      left join lateral (
        select
          SUM(sr.price_new * sq.quantity)
        from
          public.sparepart_references sr
          join public.sparepart_requests sq on sr.id = sq.sparepart_reference_id
        where
          sq.device_id = d.id
      ) total_price on true
      left join lateral (
        select
          dab.prediag_addedvalue,
          dab.purchase_price
        from
          public.device_actions_budget dab
          join public.device_actions da on da.id = dab.action_id
        where
          da.device_id = d.id
          and (
            da.type ilike '%budget%'
            or da.type = 'Réception'
          )
          and dab.id = da.id
        order by
          dab.created_at desc
        limit
          1
      ) dabudgetprediag on true
      left join lateral (
        select
          creator
        from
          public.device_actions da
        where
          da.device_id = d.id
          and da.type = 'Réception'
        order by
          da.created_at desc
        limit
          1
      ) dareception on true
      left join lateral (
        select
          spl.name as lotname,
          spl.device_pricing_mode,
          s.name as sourcename,
          s.salesman_lot
        from
          public.sales_purchase_lots spl
          join public.sale_purchase_lot_devices spld on spld.sale_purchase_lot_id = spl.id
          join public.clients c on spl.client_id = c.id
          join public.suppliers s on spl.supplier_id = s.id
        where
          spld.device_id = d.id
          and spld.archived is false
          and spl.id = spld.sale_purchase_lot_id
          and c.owner_id = organization_param
        order by
          spld.created_at desc
        limit
          1
      ) purchlot on true
      left join lateral (
        select
          spl.name
        from
          public.sales_purchase_lots spl
          join public.sale_purchase_lot_devices spld on spld.sale_purchase_lot_id = spl.id
          join public.suppliers s on s.id = spl.supplier_id
        where
          spld.device_id = d.id
          and spld.archived is false
          and spl.id = spld.sale_purchase_lot_id
          and s.id = organization_param
        order by
          spld.created_at desc
        limit
          1
      ) salelot on true
    where
      (
        id_param is not null
        and d.id = id_param
      )
      or (
        id_param is null
        and barcode_param is not null
        and d.barcode = barcode_param
      )
  ) device_data;

RETURN result;

end;$$;


ALTER FUNCTION "public"."get_device_details"("id_param" "uuid", "barcode_param" "text", "organization_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_reference_details"("searchterm" "text") RETURNS json
    LANGUAGE "plpgsql"
    AS $$--script to get deviceReference details based on its id

declare 
  result json;
  search_uuid uuid;
begin
  -- Convert searchterm to UUID, handling potential invalid input
  BEGIN
    search_uuid := searchterm::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    -- Return null if conversion fails
    RETURN NULL;
  END;

  select
    to_json(ds) into result
  from
    (
      select
        dr.created_at,
        dr.id,
        dr.model,
        b.id as brand,
        dssc.id as type,
        dr.price_new,
        dr.color,
        dr.year_production,
        dr.length,
        dr.width,
        dr.height,
        dr.parcel_size,
        dr.spareka_model,
        dr.pose_type,
        dr.weight,
        dr.wash_capacity,
        dr.dry_capacity,
        dr.efficiency_class,
        dr.archived,
        dss.name as sub_service,
        dsc.name as service
      from
        public.device_references dr
        join public.brands b on dr.brand_id = b.id
        join public.device_service_sub_categories dssc on dssc.id = dr.device_service_sub_category_id
        join device_service_categories dsc on dsc.id=dssc.device_service_category_id
        join device_sub_services dss on dss.id=dsc.device_sub_service_id
      where
        dr.id = search_uuid
      limit 1
    ) ds;

  -- Return the result (which will be NULL if no matching row is found)
  RETURN result;

end;$$;


ALTER FUNCTION "public"."get_device_reference_details"("searchterm" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_references_raw"("searchterm" "text", "offset_param" bigint DEFAULT 0) RETURNS json
    LANGUAGE "plpgsql"
    AS $$--script for deviceRef basic data, for searchbar on field 'model'

declare result json;

begin
select
  json_agg(ds)::json into result
from
  (
    select
      dr.id,
      dr.model,
      b.name as brand,
      dssc.name as type,
      dssc.id as type_id
    from
      public.device_references dr
      join public.brands b on dr.brand_id = b.id
      join public.device_service_sub_categories dssc on dssc.id = dr.device_service_sub_category_id
    where
      dr.archived is false
      and dr.model ilike '%' || searchterm || '%'
    order by dr.model asc
    offset offset_param
    limit 10
  ) ds;

if result is null then result := '[]'::json;

end if;

RETURN result;

end;$$;


ALTER FUNCTION "public"."get_device_references_raw"("searchterm" "text", "offset_param" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_reparation"("deviceid_param" "uuid") RETURNS json
    LANGUAGE "sql"
    AS $$--script for reparation data (diag, repar, qualNoGo)

with
  base_data as (
    select
      a.id,
      a.creator,
      a.created_at,
      a.type,
      dar.status,
      dar.functional_device,
      dar.error_code,
      dar.comments,
      dar.refill_done,
      dar.type as dar_type,
      dar.id as last_reparation_id, -- Add this to capture the last reparation ID
      diag_by.creator as diag_by,
      repar_by.creator as repar_by,
      diag_valid_by.creator as diag_valid_by,
      repar_valid_by.creator as repar_valid_by
    from
      public.device_actions a
      left join lateral (
        select
          *
        from
          device_actions_reparations dar
        where
          dar.action_id = a.id
        order by
          dar.created_at desc
        limit
          1
      ) dar on true
      left join lateral (
        select
          *
        from
          device_actions_reparations diag_by
        where
          diag_by.action_id = a.id
          and diag_by.status = 'Attente validation diagnostic'
        order by
          diag_by.created_at asc
        limit
          1
      ) diag_by on true
      left join lateral (
        select
          *
        from
          device_actions_reparations repar_by
        where
          repar_by.action_id = a.id
          and repar_by.status = 'Attente validation réparation'
        order by
          repar_by.created_at asc
        limit
          1
      ) repar_by on true
      left join lateral (
        select
          *
        from
          device_actions_reparations diag_valid_by
        where
          diag_valid_by.action_id = a.id
          and (
            diag_valid_by.status = 'En cours de réparation'
            or diag_valid_by.status = 'Invalidation - diagnostic'
            or diag_valid_by.status = 'Invalidation - DEEE (diagnostic)'
          )
        order by
          diag_valid_by.created_at asc
        limit
          1
      ) diag_valid_by on true
      left join lateral (
        select
          *
        from
          device_actions_reparations repar_valid_by
        where
          repar_valid_by.action_id = a.id
          and (
            repar_valid_by.status = 'Terminé'
            or repar_valid_by.status = 'Invalidation - réparation'
            or repar_valid_by.status = 'Invalidation - DEEE (réparation)'
          )
        order by
          repar_valid_by.created_at asc
        limit
          1
      ) repar_valid_by on true
    where
      a.device_id = deviceid_param
      and a.type = 'Mise en test'
  ),
  micro_failures as (
    select
      a.id as action_id,
      a.last_reparation_id, -- Use the last reparation ID from base_data
      array_agg(distinct darf.micro_failure_id) as micro_failure_ids,
      array_agg(distinct dmif.macro_failure_id) as macro_failure_ids,
      array_agg(distinct dmif.name) as micro_failure_names
    from
      base_data a
      left join device_actions_reparation_failures darf on darf.reparation_id = a.last_reparation_id -- Match with last reparation ID
      left join device_micro_failures dmif on darf.micro_failure_id = dmif.id
    where
      darf.micro_failure_id is not null
    group by
      a.id,
      a.last_reparation_id
  ),
  tests_pre as (
    select
      a.id as action_id,
      array_agg(
        json_build_object(
          'test_id', dartpre.test_id,
          'test_name', dt.name
        )
      ) filter (where dartpre.test_id is not null) as tests
    from
      base_data a
      left join device_actions_reparation_tests dartpre on dartpre.reparation_id = a.last_reparation_id
        and dartpre.archived is false
        and dartpre.type = 'pre'
      left join device_tests dt on dt.id = dartpre.test_id
    group by
      a.id
  ),
  tests_post as (
    select
      a.id as action_id,
      array_agg(
        json_build_object(
          'test_id', dartpost.test_id,
          'test_name', dt.name
        )
      ) filter (where dartpost.test_id is not null) as tests
    from
      base_data a
      left join device_actions_reparation_tests dartpost on dartpost.reparation_id = a.last_reparation_id
        and dartpost.archived is false
        and dartpost.type = 'post'
      left join device_tests dt on dt.id = dartpost.test_id
    group by
      a.id
  )
select
  json_agg(
    json_build_object(
      'id',
      bd.id,
      'creator',
      bd.creator,
      'created_at',
      bd.created_at,
      'status',
      bd.status,
      'micro_failure_ids',
      COALESCE(mf.micro_failure_ids, '{}'::uuid[]),
      'micro_failure_names',
      COALESCE(mf.micro_failure_names, '{}'::text[]),
      'macro_failure_ids',
      COALESCE(mf.macro_failure_ids, '{}'::uuid[]),
      'testspre',
      COALESCE(tp.tests, '{}'),
      'testspost',
      COALESCE(tpo.tests, '{}'),
      'functional_device',
      bd.functional_device,
      'error_code',
      bd.error_code,
      'comments',
      bd.comments,
      'refill_done',
      bd.refill_done,
      'type',
      bd.dar_type,
      'diag_by',
      bd.diag_by,
      'repar_by',
      bd.repar_by,
      'diag_valid_by',
      bd.diag_valid_by,
      'repar_valid_by',
      bd.repar_valid_by,
      'lastrep',
      bd.last_reparation_id
    )
  )
from
  base_data bd
  left join micro_failures mf on mf.action_id = bd.id
  left join tests_pre tp on tp.action_id = bd.id
  left join tests_post tpo on tpo.action_id = bd.id$$;


ALTER FUNCTION "public"."get_device_reparation"("deviceid_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_device_sub_service"("subcat_param" "uuid") RETURNS json
    LANGUAGE "sql" STABLE
    AS $$SELECT json_build_object(
        'id',dss.id,
        'name', dss.name
    )
    FROM public.device_service_sub_categories dssc
    JOIN public.device_service_categories dsc ON dsc.id = dssc.device_service_category_id
    JOIN public.device_sub_services dss ON dss.id = dsc.device_sub_service_id
    WHERE dssc.id = subcat_param;$$;


ALTER FUNCTION "public"."get_device_sub_service"("subcat_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_devices_admin"("org_id_param" "uuid", "area_cat_id" "uuid", "area_id" "uuid", "subarea_id" "uuid", "repair_status_param" "text") RETURNS json
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT json_agg(device_info) 
  FROM (
    SELECT
      d.id,
      d.barcode,
      dssc.name as service_sub_category_name,
      b.name as brand_name,
      dr.model,
      d.created_at,
      lastaction.last_edit,
      lastaction.status,
      lastaction.subarea_name,
      lastaction.area_name,
      lastaction.areacat_name,
      darepar.status as status_repar,
      spreq.data as spreq
    FROM
      public.devices d
      LEFT JOIN public.device_references dr ON d.device_reference_id = dr.id
      LEFT JOIN public.device_service_sub_categories dssc ON dr.device_service_sub_category_id = dssc.id
      LEFT JOIN public.brands b ON dr.brand_id = b.id
      LEFT JOIN LATERAL (
        SELECT
          da.last_edit,
          da.status,
          sas.name as subarea_name,
          a.name as area_name,
          ac.name as areacat_name,
          sas.id as subarea_id,
          a.id as area_id,
          ac.id as areacat_id
        FROM
          public.device_actions da
          JOIN public.sub_areas_storage sas ON da.sub_area_storage_id = sas.id
          JOIN public.areas_storage a ON sas.areas_storage_id = a.id
          JOIN public.areas_categories ac ON a.area_category_id = ac.id
        WHERE
          ac.organization_id = org_id_param
          AND da.device_id = d.id
        ORDER BY
          da.created_at DESC
        LIMIT 1
      ) lastaction ON TRUE
      LEFT JOIN LATERAL (
        SELECT
          dar.status
        FROM
          public.device_actions_reparations dar
          JOIN public.device_actions da ON da.id = dar.action_id
        WHERE
          da.device_id = d.id
          AND da.type = 'Mise en test'
          AND da.archived IS FALSE
          AND dar.action_id = da.id
          AND dar.archived IS FALSE
        ORDER BY
          da.created_at DESC
        LIMIT 1
      ) darepar ON TRUE
      LEFT JOIN LATERAL (
        SELECT
          ARRAY_AGG(
            json_build_object(
              'id', spreq.id,
              'quantity', spreq.quantity,
              'status', last_spreq_action.status,
              'name', sssc.name,
              'price_new_request', spreq.price_new_request
            )
          ) AS data
        FROM
          public.sparepart_requests spreq
          JOIN public.sparepart_service_sub_categories sssc ON sssc.id = spreq.sparepart_service_sub_category_id
          LEFT JOIN LATERAL (
            SELECT 
              spreqa.status 
            FROM 
              sparepart_requests_actions spreqa 
            WHERE 
              spreqa.sparepart_request_id = spreq.id 
              AND spreqa.archived IS FALSE 
            ORDER BY 
              spreqa.created_at DESC 
            LIMIT 1
          ) last_spreq_action ON TRUE
        WHERE
          spreq.device_id = d.id
          AND spreq.archived IS FALSE
        GROUP BY spreq.device_id
      ) spreq ON TRUE
    WHERE
      lastaction.areacat_id IS NOT NULL
      AND (area_cat_id IS NULL OR area_cat_id = lastaction.areacat_id)
      AND (area_id IS NULL OR area_id = lastaction.area_id)
      AND (subarea_id IS NULL OR subarea_id = lastaction.subarea_id)
      AND (
        repair_status_param IS NULL
        OR repair_status_param ILIKE '%validation%'
        OR (repair_status_param = 'En cours' AND EXISTS (
          SELECT 1 FROM unnest(spreq.data) AS sp
          WHERE (sp->>'price_new_request')::numeric IS NOT NULL
        ))
        OR (repair_status_param = 'En cours de réparation' AND NOT EXISTS (
          SELECT 1 FROM unnest(spreq.data) AS sp
          WHERE sp->>'status' NOT IN ('Pièce en stock', 'Pièce reçue')
        ))
      )
    ORDER BY lastaction.last_edit DESC
  ) as device_info;
$$;


ALTER FUNCTION "public"."get_devices_admin"("org_id_param" "uuid", "area_cat_id" "uuid", "area_id" "uuid", "subarea_id" "uuid", "repair_status_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_devices_barcode"("barcode_param" "text" DEFAULT NULL::"text", "organization_param" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$--look for devices with basic data, based on part or complete barcode (not id)

declare 
  result json;
begin
  select
    json_agg(ds)::json into result
  from
    (
      select
        d.id,
        d.barcode,
        da.status
      from
        public.devices d
        join public.device_ownership_transfer dot on dot.device_id = d.id
        left join lateral (select status from device_actions da where da.device_id=d.id order by created_at desc limit 1) da on true
      where
        d.archived is false
        and d.barcode ilike '%' || barcode_param || '%'
        and dot.new_owner = organization_param
    ) ds;

  -- Handle case when no rows are found (return empty array instead of null)
  if result is null then
    result := '[]'::json;
  end if;

  RETURN result;
end;$$;


ALTER FUNCTION "public"."get_devices_barcode"("barcode_param" "text", "organization_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_devices_model"("model_param" "uuid", "organization_id_param" "uuid") RETURNS json[]
    LANGUAGE "plpgsql"
    AS $$--look for devices with basic data, based on exact deviceRefId (modelId)

declare device_results json[];

begin
select
  array_agg(
    json_build_object(
      'id',
      d.id,
      'barcode',
      d.barcode,
      'model',
      d.device_reference_id,
      'status',
      d.status,
      'location',
      subarea.location
    )
  ) into device_results
from
  devices d
  join public.device_ownership_transfer dot on d.id = dot.device_id
  left join lateral (
    select
      sas.name as location
    from
      public.device_actions da
      join sub_areas_storage sas on sas.id = da.sub_area_storage_id
    where
      da.device_id = d.id
    order by
      da.created_at desc
    limit
      1
  ) subarea on true
where
  d.device_reference_id = model_param
  and dot.new_owner = organization_id_param;

RETURN device_results;

end;$$;


ALTER FUNCTION "public"."get_devices_model"("model_param" "uuid", "organization_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_devices_salesearch"("brand_param" "text" DEFAULT NULL::"text", "service_sub_category_param" "text" DEFAULT NULL::"text", "offset_value" integer DEFAULT 0, "yearmin" integer DEFAULT NULL::integer, "yearmax" integer DEFAULT NULL::integer, "pricemin" double precision DEFAULT NULL::double precision, "pricemax" double precision DEFAULT NULL::double precision, "subservice_param" "text" DEFAULT NULL::"text", "qualgrade_param" "text" DEFAULT NULL::"text", "brandgrade_param" "text" DEFAULT NULL::"text", "wholesale_param" boolean DEFAULT NULL::boolean, "sort_field" "text" DEFAULT 'created_at'::"text", "sort_type" "text" DEFAULT 'asc'::"text", "organization_id_param" "uuid" DEFAULT NULL::"uuid", "barcode_param" "text" DEFAULT NULL::"text", "status_param" "text"[] DEFAULT NULL::"text"[], "purchase_lot_param" "text" DEFAULT NULL::"text") RETURNS SETOF json
    LANGUAGE "sql"
    AS $$--get all devices that respect params set. Only organization_id_param is compulsory, the others no.

select
  row_to_json(ds)
from
  (
    select
      d.id,
      d.barcode,
      dssc.name as service_sub_category_name,
      b.name as brand_name,
      b.grade as brand_grade,
      dr.model,
      dr.year_production,
      dr.price_new,
      dss.name as service_sub_category,
      d.status,
      lastaction.sub_area_id,
      lastaction.area_name,
      lastaction.sub_area_name,
      daqualdetails.grade as quality_grade,
      daqualdetails.wholesale,
      salepriceauto.sale_price as sale_price_auto,
      salepricecustom.custom_sale_price as sale_price_real,
      purchase_lot.name as purchase_lot,
      CASE 
        WHEN salepricecustom.custom_sale_price IS NULL THEN salepriceauto.sale_price
        ELSE salepricecustom.custom_sale_price
      END as sale_price_final
    from
      public.devices d
      left join public.device_references dr on d.device_reference_id = dr.id
      left join public.device_service_sub_categories dssc on dr.device_service_sub_category_id = dssc.id
      left join public.device_service_categories dsc on dssc.device_service_category_id = dsc.id
      left join public.device_sub_services dss on dsc.device_sub_service_id = dss.id
      left join public.brands b on dr.brand_id = b.id
      left join lateral (
        select
          last_edit
        from
          public.device_actions
        where
          device_id = d.id
        order by
          created_at desc
        limit
          1
      ) da on true
      left join lateral (
        select
          da.created_at,
          da.last_edit,
          sas.id as sub_area_id,
          sas.name as sub_area_name,
          a.name as area_name,
          ac.name as area_type
        from
          public.device_actions da
          join public.sub_areas_storage sas on da.sub_area_storage_id = sas.id
          join public.areas_storage a on sas.areas_storage_id = a.id
          join public.areas_categories ac on ac.id=a.area_category_id
        where
          da.device_id = d.id
        order by
          da.created_at desc
        limit
          1
      ) lastaction on true
      left join lateral (
        select
          daq.wholesale,
          daq.grade
        from
          public.device_actions_quality daq
          join public.device_actions da on da.id = daq.action_id
        where
          da.device_id = d.id
          and da.type = 'Qualité'
          and daq.action_id = da.id
        order by
          da.created_at desc,
          daq.created_at desc
        limit
          1
      ) daqualdetails on true
      left join lateral (
        select
          spl.name
        from
          public.sales_purchase_lots spl
          join public.sale_purchase_lot_devices spld on spld.sale_purchase_lot_id = spl.id
          join public.clients c on spl.client_id = c.id
          join public.suppliers s on spl.supplier_id = s.id
        where
          spld.device_id = d.id
          and spld.archived is false
          and spl.id = spld.sale_purchase_lot_id
          and c.owner_id = organization_id_param
        order by
          spld.created_at desc
        limit
          1
      ) purchase_lot on true
      left join lateral (
        select
          spl.name,
          spl.id
        from
          public.sales_purchase_lots spl
          join public.sale_purchase_lot_devices spld on spld.sale_purchase_lot_id = spl.id
          join public.suppliers s on s.id = spl.supplier_id
        where
          spld.device_id = d.id
          and spld.archived is false
          and spl.id = spld.sale_purchase_lot_id
          and s.id = organization_id_param
        order by
          spld.created_at desc
        limit
          1
      ) sale_lot on true
      left join lateral (
        select
          das.custom_sale_price
        from
          public.device_actions_sales_lot das
          join public.device_actions da on da.id = das.action_id
        where
          da.device_id = d.id
          and da.type = 'Lot de vente'
          and das.action_id = da.id
          and das.sale_lot_id = sale_lot.id
        order by
          da.created_at desc,
          das.created_at desc
        limit
          1
      ) salepricecustom on true
      left join lateral (
        select
          dab.sale_price
        from
          public.device_actions_budget dab
          join public.device_actions da on da.id = dab.action_id
        where
          da.device_id = d.id
          and (
            da.type ilike '%budget%'
            or da.type = 'Réception'
          )
          and dab.action_id = da.id
        order by
          da.created_at desc
        limit
          1
      ) salepriceauto on true
    where
      d.archived is false
      and sale_lot is null
      and (
        barcode_param is null
        or d.barcode ilike '%' || barcode_param || '%'
      )
      and (
        brand_param is null
        or b.name = brand_param
      )
      and (
        service_sub_category_param is null
        or dsc.name = service_sub_category_param
      )
      and (
        status_param is null
        or d.status = ANY(status_param)
      )
      and (
        purchase_lot_param is null
        or purchase_lot.name = purchase_lot_param
      )
      and (
        pricemin is null
        or dr.price_new >= pricemin
      )
      and (
        pricemax is null
        or dr.price_new <= pricemax
      )
      and (
        yearmin is null
        or dr.year_production >= yearmin
      )
      and (
        yearmax is null
        or dr.year_production <= yearmax
      )
      and (
        subservice_param is null
        or dss.name = subservice_param
      )
      and (
        qualgrade_param is null
        or daqualdetails.grade = qualgrade_param
      )
      and (
        wholesale_param is null
        or daqualdetails.wholesale = wholesale_param
      )
      and (
        brandgrade_param is null
        or b.grade = brandgrade_param
      )
    order by
      case
        when sort_field = 'created_at'
        and sort_type = 'asc' then d.created_at
      end asc,
      case
        when sort_field = 'created_at'
        and sort_type = 'desc' then d.created_at
      end desc,
      case
        when sort_field = 'last_edit'
        and sort_type = 'asc' then lastaction.last_edit
      end asc,
      case
        when sort_field = 'last_edit'
        and sort_type = 'desc' then lastaction.last_edit
      end desc,
      case
        when sort_field = 'service'
        and sort_type = 'asc' then dss.name
      end asc,
      case
        when sort_field = 'service'
        and sort_type = 'desc' then dss.name
      end desc,
      case
        when sort_field = 'type_device'
        and sort_type = 'asc' then dssc.name
      end asc,
      case
        when sort_field = 'type_device'
        and sort_type = 'desc' then dssc.name
      end desc,
      case
        when sort_field = 'quality_grade'
        and sort_type = 'asc' then daqualdetails.grade
      end asc,
      case
        when sort_field = 'quality_grade'
        and sort_type = 'desc' then daqualdetails.grade
      end desc,
      case
        when sort_field = 'brand_grade'
        and sort_type = 'asc' then b.grade
      end asc,
      case
        when sort_field = 'brand_grade'
        and sort_type = 'desc' then b.grade
      end desc,
      case
        when sort_field = 'brand'
        and sort_type = 'asc' then b.name
      end asc,
      case
        when sort_field = 'brand'
        and sort_type = 'desc' then b.name
      end desc,
      case
        when sort_field = 'purchase_lot'
        and sort_type = 'asc' then purchase_lot.name
      end asc,
      case
        when sort_field = 'purchase_lot'
        and sort_type = 'desc' then purchase_lot.name
      end desc,
      case
        when sort_field = 'new_device_price'
        and sort_type = 'asc' then dr.price_new
      end asc,
      case
        when sort_field = 'new_device_price'
        and sort_type = 'desc' then dr.price_new
      end desc,
      case
        when sort_field = 'year_production'
        and sort_type = 'asc' then dr.year_production
      end asc,
      case
        when sort_field = 'year_production'
        and sort_type = 'desc' then dr.year_production
      end desc,
      -- Default sort if no match is found
      case
        when sort_field != 'created_at' then d.created_at
      end asc
    limit
      10
    offset
      offset_value
  ) ds;$$;


ALTER FUNCTION "public"."get_devices_salesearch"("brand_param" "text", "service_sub_category_param" "text", "offset_value" integer, "yearmin" integer, "yearmax" integer, "pricemin" double precision, "pricemax" double precision, "subservice_param" "text", "qualgrade_param" "text", "brandgrade_param" "text", "wholesale_param" boolean, "sort_field" "text", "sort_type" "text", "organization_id_param" "uuid", "barcode_param" "text", "status_param" "text"[], "purchase_lot_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_devices_search"("brand_param" "text" DEFAULT NULL::"text", "service_sub_category_param" "text" DEFAULT NULL::"text", "area_id" "uuid" DEFAULT NULL::"uuid", "offset_value" integer DEFAULT 0, "sort_field" "text" DEFAULT 'created_at'::"text", "organization_id_param" "uuid" DEFAULT NULL::"uuid", "archived_param" boolean DEFAULT false, "barcode_param" "text" DEFAULT NULL::"text", "status_param" "text" DEFAULT NULL::"text", "subarea_id_param" "uuid" DEFAULT NULL::"uuid", "model_param" "text" DEFAULT NULL::"text", "purchase_lot_param" "text" DEFAULT NULL::"text", "sale_lot_param" "text" DEFAULT NULL::"text", "source_param" "text" DEFAULT NULL::"text", "aftersales_status_param" "text" DEFAULT NULL::"text", "repar_status_param" boolean DEFAULT false) RETURNS SETOF json
    LANGUAGE "sql"
    AS $$--searchbar devices. Only organization_id_param is compulsory

select
  row_to_json(ds)
from
  (
    select
      d.id,
      d.barcode,
      dssc.name as service_sub_category_name,
      b.name as brand_name,
      dr.model,
      d.status,
      d.created_at,
      lastaction.created_at as last_action_date
    from --
      public.devices d
      left join public.device_references dr on d.device_reference_id = dr.id
      left join public.device_service_sub_categories dssc on dr.device_service_sub_category_id = dssc.id
      left join public.brands b on dr.brand_id = b.id
      left join lateral (
        select
          da.created_at,
          sa.id as subareaid,
          sa.name as subareaname,
          a.id as areaid
        from
          public.device_actions da
          join public.sub_areas_storage sa on da.sub_area_storage_id = sa.id
          join public.areas_storage a on sa.areas_storage_id = a.id
        where
          da.device_id = d.id
        order by
          da.created_at desc
        limit
          1
      ) lastaction on true
      left join lateral (
        select
          daa.status
        from
          public.device_actions_aftersales daa
          join public.device_actions da on daa.action_id = da.id
        where
          d.id = da.device_id
          and da.type ilike '%retour%'
          and da.id = daa.action_id
        order by
          da.created_at desc
        limit
          1
      ) daastatus on true
      left join lateral (
        select
          daq.created_at
        from
          public.device_actions_quality daq
          join public.device_actions da on da.id = daq.action_id
        where
          da.device_id = d.id
          and da.type ilike '%qualit%'
          and daq.action_id = da.id
        order by
          da.created_at desc
        limit
          1
      ) daqualdate on true
      left join lateral (
        select
          dar.status
        from
          public.device_actions_reparations dar
          join public.device_actions da on da.id = dar.action_id
        where
          da.device_id = d.id
          and da.type = 'Mise en test'
          and dar.action_id = da.id
        order by
          da.created_at desc
        limit
          1
      ) dareparstatus on true
      left join lateral (
        select
          spl.name as lot_name,s.name as source_name
        from
          public.sales_purchase_lots spl
          join public.sale_purchase_lot_devices spld on spld.sale_purchase_lot_id = spl.id
          join public.clients c on spl.client_id = c.id
          join public.suppliers s on spl.supplier_id = s.id
        where
          spld.device_id = d.id
          and spld.archived is false
          and spl.id = spld.sale_purchase_lot_id
          and c.owner_id = organization_id_param
        order by
          spld.created_at desc
        limit
          1
      ) purchase_lot on true
      left join lateral (
        select
          spl.name
        from
          public.sales_purchase_lots spl
          join public.sale_purchase_lot_devices spld on spld.sale_purchase_lot_id = spl.id
          join public.suppliers s on s.id = spl.supplier_id
        where
          spld.device_id = d.id
          and spld.archived is false
          and spl.id = spld.sale_purchase_lot_id
          and s.id = organization_id_param
        order by
          spld.created_at desc
        limit
          1
      ) sale_lot on true
    where
      (
        brand_param is null
        or b.name ilike '%' || brand_param || '%'
        or barcode_param is null
        or d.barcode ilike '%' || barcode_param || '%'
        or model_param is null
        or dr.model ilike '%' || model_param || '%'
      ) --searchbar
      and (
        service_sub_category_param is null
        or dssc.name ilike '%' || service_sub_category_param || '%'
      )
      and (
        area_id is null
        or lastaction.areaid = area_id
      )
      and (
        archived_param is null
        or d.archived = archived_param
      )
      and (
        status_param is null
        or d.status ilike '%' || status_param || '%'
      )
      and (
        subarea_id_param is null
        or lastaction.subareaid = subarea_id_param
      )
      and (
        purchase_lot_param is null
        or purchase_lot.lot_name ilike concat('%', purchase_lot_param, '%')
      )
      and (
        sale_lot_param is null
        or sale_lot.name ilike '%' || sale_lot_param || '%'
      )
      and (
        source_param is null
        or purchase_lot.source_name ilike '%' || source_param || '%'
      )
      and (
        aftersales_status_param is null
        or daastatus.status = aftersales_status_param
      )
      and (
        repar_status_param is false
        or (
          repar_status_param = true
          and dareparstatus.status ilike '%attente%'
        )
      )
    order by
      case
        when sort_field = 'barcode' then d.barcode
      end asc,
      case
        when sort_field = 'price_new' then dr.price_new
      end asc,
      case
        when sort_field = 'service_sub_category_name' then dssc.name
      end asc,
      case
        when sort_field = 'sub_area_name' then lastaction.subareaname
      end asc,
      case
        when sort_field = 'last_qual' then daqualdate.created_at
      end desc,
      -- Default sort if no match is found
      case
        when sort_field != 'created_at' then d.created_at
      end desc
    limit
      10
    offset
      offset_value
  ) ds;$$;


ALTER FUNCTION "public"."get_devices_search"("brand_param" "text", "service_sub_category_param" "text", "area_id" "uuid", "offset_value" integer, "sort_field" "text", "organization_id_param" "uuid", "archived_param" boolean, "barcode_param" "text", "status_param" "text", "subarea_id_param" "uuid", "model_param" "text", "purchase_lot_param" "text", "sale_lot_param" "text", "source_param" "text", "aftersales_status_param" "text", "repar_status_param" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_failures"("device_subcat_id" "uuid", "p_org_id" "uuid") RETURNS json
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$--get failures with both org_id and device_subcat_id, for diag/repar/qualityNoGo

SELECT json_agg(json_build_object(
  'micro_failure_id', dmif.id,
  'micro_failure_name', dmif.name,
  'macro_failure_id', dmif.macro_failure_id,
  'macro_failure_name', dmaf.name
))
FROM public.device_micro_failures dmif
JOIN public.device_macro_failures dmaf ON dmaf.id = dmif.macro_failure_id
WHERE dmaf.device_service_sub_category_id = device_subcat_id
  AND dmaf.organization_id = p_org_id;$$;


ALTER FUNCTION "public"."get_failures"("device_subcat_id" "uuid", "p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_notifs_count"("user_id_param" "text") RETURNS bigint
    LANGUAGE "sql"
    AS $$
    SELECT
     count(id) FROM public.notifications WHERE user_id_param = ANY(recipients) AND read IS FALSE;
$$;


ALTER FUNCTION "public"."get_notifs_count"("user_id_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_purchlot_devices"("salelot_id_param" "uuid", "files_param" boolean DEFAULT false) RETURNS json[]
    LANGUAGE "sql" STABLE
    AS $$select
  COALESCE(
    array_agg(
      json_build_object(
        'id',
        d.id,
        'barcode',
        d.barcode,
        'service_sub_category_name',
        dssc.name,
        'brand_name',
        b.name,
        'model',
        dr.model,
        'status',
        lastaction.status,
        'year_production',
        dr.year_production,
        'price_new',
        dr.price_new,
        'grade',
        dareception.grade,
        'prequalif',
        dareception.prequalif,
        'purch_price',
        dabudget.purchase_price,
        'custom_purch_price',
        dabudget.purchase_price_custom,
        'purch_price_final',
        case
          when dabudget.purchase_price_custom is not null then dabudget.purchase_price_custom
          else dabudget.purchase_price
        end,
        'micro_failure_names',
        failures.micro_failure_names,
        'macro_failure_names',
        failures.macro_failure_names,
        'spreq',
        ARRAY(
          select distinct
            sssc.name
          from
            public.sparepart_requests spreq
            join public.sparepart_service_sub_categories sssc on spreq.sparepart_service_sub_category_id = sssc.id
          where
            spreq.device_id = d.id
            and spreq.archived is false
        ),
        'file_url',
        case
          when files_param then (
            select
              df.file_url
            from
              public.devices_files df
            where
              df.device_id = d.id
              and df.type = 'defective_sp_reception_file'
              and df.archived is false
            order by
              df.created_at desc
            limit
              1
          )
          else null
        end
      )
    ),
    '{}'
  )::json[]
from
  public.sales_purchase_lots spl
  join public.sale_purchase_lot_devices spld on spl.id = spld.sale_purchase_lot_id
  join public.devices d on d.id = spld.device_id
  left join public.device_references dr on d.device_reference_id = dr.id
  left join public.device_service_sub_categories dssc on dr.device_service_sub_category_id = dssc.id
  left join public.brands b on dr.brand_id = b.id
  left join lateral (
    select
      da.status
    from
      public.device_actions da
    where
      da.device_id = d.id
    order by
      da.created_at desc
    limit
      1
  ) lastaction on true
  left join lateral (
    select
      dar.grade,
      dar.prequalif
    from
      public.device_actions_reception dar
      join public.device_actions da on da.id = dar.action_id
    where
      da.device_id = d.id
      and da.type = 'Réception'
      and dar.action_id = da.id
    order by
      da.created_at desc,
      dar.created_at desc
    limit
      1
  ) dareception on true
  left join lateral (
    select
      dab.purchase_price_custom,dab.purchase_price
    from
      public.device_actions_budget dab
      join public.device_actions da on da.id = dab.action_id
    where
      da.device_id = d.id
      and dab.action_id = da.id
    order by
      da.created_at desc,
      dab.created_at desc
    limit
      1
  ) dabudget on true
  left join lateral (
    select
      array_agg(distinct dmif.name) as micro_failure_names,
      array_agg(distinct dmaf.name) as macro_failure_names
    from
      public.device_actions da
      join public.device_actions_reparations darepar on da.id = darepar.action_id
      left join device_actions_reparation_failures darf on darf.reparation_id = darepar.id
      left join device_micro_failures dmif on darf.micro_failure_id = dmif.id
      left join device_macro_failures dmaf on dmif.macro_failure_id = dmaf.id
    where
      da.device_id = d.id
      and darepar.action_id = da.id
      and darf.micro_failure_id is not null
  ) failures on true
where
  spl.id = salelot_id_param
  and spld.archived is false;$$;


ALTER FUNCTION "public"."get_purchlot_devices"("salelot_id_param" "uuid", "files_param" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sale_purch_lots"("p_organization_id" "uuid", "type_lot" character varying DEFAULT NULL::character varying, "hidden_param" boolean DEFAULT false, "archived_param" boolean DEFAULT false, "offset_param" bigint DEFAULT NULL::bigint, "name_lot_param" "text" DEFAULT NULL::"text", "supplier_name_param" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$--for a given org_id:

select
  json_agg(row_to_json(lots_data))
from
  (
    select
      spl.id,
      spl.supplier_id,
      spl.client_id,
      spl.hidden,
      spl.name,
      s.name as supplier_name,
      c.name as client_name,
      spl.created_at,
      spl.device_pricing_mode,
      lastaction.last_edit,
      sg.id as group_id,
      sg.name as group_name
    from
      public.sales_purchase_lots spl
      left join public.suppliers s on spl.supplier_id = s.id
      left join public.clients c on spl.client_id = c.id
      left join lateral (select spla.created_at as last_edit from public.sales_purchase_lot_actions spla where spl.id = spla.sales_purchase_lot_id order by created_at desc limit 1) lastaction on true
      left join public.client_supplier_groups sg on sg.id=s.id
    where
      (
        case
          when type_lot is null then (
            c.owner_id = p_organization_id
            or s.owner_id = p_organization_id
          )
        end
        or case
          when type_lot = 'purchase' then s.owner_id = p_organization_id
          and spl.supplier_id != p_organization_id
        end
        or case
          when type_lot = 'sale' then c.owner_id = p_organization_id
          and spl.client_id != p_organization_id
        end
      )
      and case
        when hidden_param is not null then spl.hidden = hidden_param
      end
      and spl.archived = archived_param
      and case
        when name_lot_param is not null then spl.name ilike '%' || name_lot_param || '%'
        else true
      end
      and case
        when supplier_name_param is not null then s.name ilike '%' || supplier_name_param || '%'
        else true
      end
    order by
      spl.created_at desc
    offset 
      case 
        when offset_param is null then 0
        else offset_param
      end
    limit
      case
        when offset_param is null then NULL
        else 10
      end
  ) lots_data;$$;


ALTER FUNCTION "public"."get_sale_purch_lots"("p_organization_id" "uuid", "type_lot" character varying, "hidden_param" boolean, "archived_param" boolean, "offset_param" bigint, "name_lot_param" "text", "supplier_name_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_salelot_devices"("salelot_id_param" "uuid", "files_param" boolean DEFAULT false) RETURNS json[]
    LANGUAGE "sql"
    AS $$select
  array_agg(row_to_json(ds))
from
  (
    select
      d.id,
      d.barcode,
      dssc.name as service_sub_category_name,
      b.name as brand_name,
      b.grade as brand_grade,
      lastaction.status,
      lastaction.sub_area_name,
      lastaction.area_name,
      dr.model,
      dr.price_new,
      dr.year_production,
      dss.name as service_sub_category,
      daqualdetails.grade as quality_grade,
      daqualdetails.wholesale,
      salepricecustom.custom_sale_price as sale_price_custom,
      salepricecustom.action_id,
      salepriceauto.sale_price as sale_price_auto,
      CASE 
        WHEN salepricecustom.custom_sale_price IS NULL THEN salepriceauto.sale_price
        ELSE salepricecustom.custom_sale_price
      END as sale_price_final,
      CASE 
        WHEN files_param = true THEN files.link1 
        ELSE NULL 
      END as link1,
      CASE 
        WHEN files_param = true THEN files.link2
        ELSE NULL 
      END as link2,
      CASE 
        WHEN files_param = true THEN files.link3
        ELSE NULL 
      END as link3,
      CASE 
        WHEN files_param = true THEN files.link4
        ELSE NULL 
      END as link4,
      CASE 
        WHEN files_param = true THEN files.link5
        ELSE NULL 
      END as link5
    from
      public.sale_purchase_lot_devices spld
      join public.devices d on d.id = spld.device_id
      left join public.device_references dr on d.device_reference_id = dr.id
      left join public.device_service_sub_categories dssc on dr.device_service_sub_category_id = dssc.id
      left join public.device_service_categories dsc on dssc.device_service_category_id = dsc.id
      left join public.device_sub_services dss on dsc.device_sub_service_id = dss.id
      left join public.brands b on dr.brand_id = b.id
      left join lateral (
        select
          da.status,sas.name as sub_area_name,a.name as area_name
        from
          public.device_actions da
          join public.sub_areas_storage sas on sas.id=da.sub_area_storage_id
          join public.areas_storage a on sas.areas_storage_id = a.id
        where
          da.device_id = d.id
        order by
          da.created_at desc
        limit
          1
      ) lastaction on true
      left join lateral (
        select
          daq.wholesale,
          daq.grade
        from
          public.device_actions_quality daq
          join public.device_actions da on da.id = daq.action_id
        where
          da.device_id = d.id
          and da.type = 'Qualité'
          and daq.action_id = da.id
        order by
          da.created_at desc,
          daq.created_at desc
        limit
          1
      ) daqualdetails on true
      left join lateral (
        select
          das.custom_sale_price,da.id as action_id
        from
          public.device_actions_sales_lot das
          join public.device_actions da on da.id = das.action_id
        where
          da.device_id = d.id
          and da.type = 'Lot de vente'
          and das.action_id = da.id
          and das.sale_lot_id = salelot_id_param
        order by
          da.created_at desc,
          das.created_at desc
        limit
          1
      ) salepricecustom on true
      left join lateral (
        select
          dab.sale_price
        from
          public.device_actions_budget dab
          join public.device_actions da on da.id = dab.action_id
        where
          da.device_id = d.id
          and (
            da.type ilike '%budget%'
            or da.type = 'Réception'
          )
          and dab.action_id = da.id
        order by
          da.created_at desc
        limit
          1
      ) salepriceauto on true
      left join lateral (
        select
          MAX(
            case
              when rn = 1 then f.file_url
            end
          ) as link1,
          MAX(
            case
              when rn = 2 then f.file_url
            end
          ) as link2,
          MAX(
            case
              when rn = 3 then f.file_url
            end
          ) as link3,
          MAX(
            case
              when rn = 4 then f.file_url
            end
          ) as link4,
          MAX(
            case
              when rn = 5 then f.file_url
            end
          ) as link5
        from (
          select
            device_id,
            file_url,
            ROW_NUMBER() over (
              partition by
                device_id
              order by
                created_at desc
            ) as rn
          from
            public.devices_files
          where
            type = 'quality' and archived is false
        ) f
        where f.device_id = d.id
        group by f.device_id
      ) files on files_param = true
    where
      spld.sale_purchase_lot_id = salelot_id_param
      and spld.archived is false
  ) ds;$$;


ALTER FUNCTION "public"."get_salelot_devices"("salelot_id_param" "uuid", "files_param" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_salelot_devices_other"("salelot_id_param" "uuid", "type_param" "text") RETURNS json[]
    LANGUAGE "sql"
    AS $$
  --objective: get device_barcode for 
    --type_param=restore_failed (devices with restore failed bc in another lot when lot restored) 
    --or type_param=archive (devices in lot before archive)
  SELECT array_agg(row_to_json(ds))
  FROM (
    SELECT
      d.id,
      d.barcode as name
    FROM
      public.sale_purchase_lot_devices spld
      JOIN public.devices d ON d.id = spld.device_id
    WHERE
      spld.sale_purchase_lot_id = salelot_id_param 
      AND (type_param!='restore_failed' or spld.restore_failed IS true)
      AND (type_param!='archive' or spld.archived IS true)
    LIMIT 100
  ) ds;
$$;


ALTER FUNCTION "public"."get_salelot_devices_other"("salelot_id_param" "uuid", "type_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_saleslots_raw"("org_id_param" "uuid", "client_name_param" "text" DEFAULT NULL::"text", "status_param" "text" DEFAULT NULL::"text", "device_barcode_param" "text" DEFAULT NULL::"text", "offset_param" bigint DEFAULT 0, "spl_id_param" "uuid" DEFAULT NULL::"uuid") RETURNS json[]
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$with
  filtered_lots as (
    select
      spl.id,
      spl.name,
      spl.created_at,
      c.name as client_name,
      c.id as client_id,
      lastaction.created_at as lastedit,
      lastaction.status,
      lastaction.last_editor,
      devices.count as devices_count,
      devices.devices_barcode,
      u.email as creator
    from
      public.sales_purchase_lots spl
      join public.clients c on c.id = spl.client_id
      join public.users u on u.id = spl.creator
      left join lateral (
        select
          COUNT(spld.id) as count,
          ARRAY_AGG(d.barcode) as devices_barcode
        from
          public.sale_purchase_lot_devices spld
          join public.devices d on d.id = spld.device_id
        where
          spld.sale_purchase_lot_id = spl.id
          and spld.archived is false
      ) devices on true
      left join lateral (
        select
          spla.created_at,
          spla.status,
          u.email as last_editor
        from
          public.sales_purchase_lot_actions spla
          join public.users u on u.id = spla.creator
        where
          sales_purchase_lot_id = spl.id
        order by
          spla.created_at desc
        limit
          1
      ) lastaction on true
    where
      spl.archived is false
      and c.owner_id = org_id_param
      and (
        spl_id_param is null
        or spl.id = spl_id_param
      )
      and (
        client_name_param is null
        or c.name ilike '%' || client_name_param || '%'
      )
      and (
        device_barcode_param is null
        or device_barcode_param is not null
        and exists (
          select
            1
          from
            public.sale_purchase_lot_devices spld
            join public.devices d on d.id = spld.device_id
          where
            spld.sale_purchase_lot_id = spl.id
            and spld.archived is false
            and d.barcode ilike '%' || device_barcode_param || '%'
        )
      )
      and (
        status_param is null
        or lastaction.status = status_param
      )
    order by
      spl.created_at desc
    limit
      10
    offset
      offset_param
  )
select
  COALESCE(
    ARRAY_AGG(
      json_build_object(
        'id',
        id,
        'name',
        name,
        'created_at',
        created_at,
        'sales_client',
        client_name,
        'sales_client_id',
        client_id,
        'last_edit',
        lastedit,
        'status',
        status,
        'devices_count',
        devices_count
      )
    ),
    array[]::JSON[]
  )
from
  filtered_lots;$$;


ALTER FUNCTION "public"."get_saleslots_raw"("org_id_param" "uuid", "client_name_param" "text", "status_param" "text", "device_barcode_param" "text", "offset_param" bigint, "spl_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sparepart_reference"("orgid_param" "uuid", "model_id_param" "uuid", "sp_subcat_id_param" "uuid") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$--get spref details + nb in_stock, based on model and sp
select
  json_agg(
    json_build_object(
      'id',
      sr.id,
      'price_new',
      sr.price_new,
      'unavailable',
      sr.unavailable,
      'stock_deee',
      stock_count.count
    )
  )
from
  public.sparepart_references sr
  join public.sparepart_device_references sdr on sr.id = sdr.sparepart_reference_id
  left join lateral (
    select
      count(s.id)
    from
      public.spareparts s
      join public.users u on s.creator = u.id
    where
      s.sparepart_reference_id = sr.id
      and u.organization_id = orgid_param
      and s.archived is false
      and s.in_stock is true
      and s.origin = 'deee'
  ) stock_count on true
where
  sdr.model_id = model_id_param
  and sr.sparepart_service_sub_category_id = sp_subcat_id_param
  and sdr.archived is false
  and sr.archived is false;$$;


ALTER FUNCTION "public"."get_sparepart_reference"("orgid_param" "uuid", "model_id_param" "uuid", "sp_subcat_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spareparts_barcode"("orgid_param" "uuid", "barcode_param" "text") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$--get sp details (from stock) with part of the barcode (not id)

  SELECT
    json_agg(
      json_build_object(
        'id', s.id,
        'barcode', s.barcode,
        'sp',sssc.name,
        'origin',s.origin
      )
    )
  
    FROM public.spareparts s
        JOIN public.users u ON s.creator = u.id
        join public.sparepart_service_sub_categories sssc on sssc.id=s.sparepart_service_sub_category_id
        WHERE s.barcode ilike '%' || barcode_param || '%' AND u.organization_id = orgid_param and s.archived is false;$$;


ALTER FUNCTION "public"."get_spareparts_barcode"("orgid_param" "uuid", "barcode_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spareparts_byserial"("ser_nb_param" "text", "org_id_param" "uuid") RETURNS json[]
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin 
  RETURN ARRAY(
    select
      json_build_object(
        'id',
        s.id,
        'barcode',
        s.barcode,
        'name',
        sssc.name,
        'subarea_id',
        lastaction.subarea_id,
        'subarea_name',
        lastaction.subarea_name,
        'origin',
        s.origin
      )
    from
      public.spareparts s
      join public.sparepart_references sr on s.sparepart_reference_id = sr.id
      join public.sparepart_service_sub_categories sssc on sssc.id = sr.sparepart_service_sub_category_id
      left join lateral (
        select
          sas.id as subarea_id,
          sas.name as subarea_name
        from
          public.sparepart_actions sa
          join public.sub_areas_storage sas on sa.sub_area_storage_id = sas.id
        where
          sa.sparepart_id = s.id
        order by
          sa.created_at desc
        limit
          1
      ) lastaction on true
      join public.users u on s.creator = u.id
    where
      sr.serial_number = ser_nb_param
      and s.in_stock is true
      and u.organization_id = org_id_param
    group by
      s.id,
      s.barcode,
      sssc.name,
      lastaction.subarea_id,
      lastaction.subarea_name
    order by
      s.barcode asc
    limit
      30
  );
end;
$$;


ALTER FUNCTION "public"."get_spareparts_byserial"("ser_nb_param" "text", "org_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spareparts_deviceid"("deviceid_param" "uuid") RETURNS json[]
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$--get all sp from stock, coming from a given deviceId
select
  array_agg(
    json_build_object(
      'id',
      s.id,
      'barcode',
      s.barcode,
      'name',
      sssc.name
    )
  )
from
  public.spareparts s
  join public.sparepart_references sr on s.sparepart_reference_id = sr.id
  join public.sparepart_service_sub_categories sssc on sssc.id = sr.sparepart_service_sub_category_id
where
  s.origin_device_id = deviceid_param
group by
  sssc.name
order by
  sssc.name asc;$$;


ALTER FUNCTION "public"."get_spareparts_deviceid"("deviceid_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spareparts_raw"("org_id_param" "uuid", "offset_param" bigint DEFAULT 0, "in_stock" boolean DEFAULT true, "search_param" "text" DEFAULT NULL::"text") RETURNS json[]
    LANGUAGE "plpgsql" STABLE
    AS $$--offset_param default 0

BEGIN
  RETURN (
    SELECT
      json_agg(
        json_build_object(
          'id', sp.id,
          'barcode', sp.barcode,
          'barcode_legacy', sp.barcode_legacy,
          'name', sssc.name,
          'sp_type_id', sssc.id,
          'subarea_name', spa.subareaname,
          'subarea_id', spa.sub_area_storage_id
        )
      )
    FROM public.spareparts sp
    JOIN public.users u ON sp.creator = u.id
    JOIN public.sparepart_service_sub_categories sssc ON sssc.id = sp.sparepart_service_sub_category_id
    LEFT JOIN LATERAL (
      SELECT 
        spa.origin_device_id,
        spa.sub_area_storage_id,
        sas.name as subareaname
      FROM public.sparepart_actions spa 
      JOIN public.sub_areas_storage sas ON sas.id = spa.sub_area_storage_id
      WHERE spa.sparepart_id = sp.id 
      ORDER BY spa.created_at DESC 
      LIMIT 1
    ) spa ON true
    JOIN public.sparepart_references spref ON spref.id = sp.sparepart_reference_id
    LEFT JOIN LATERAL (
      SELECT 
        array_agg(dr.model) as models
      FROM public.device_references dr 
      JOIN sparepart_device_references sdr ON sdr.model_id = dr.id
      WHERE sdr.sparepart_reference_id = spref.id AND sdr.archived IS false
    ) modellist ON true
    WHERE
      u.organization_id = org_id_param 
      AND sp.archived IS false
      AND CASE 
            WHEN in_stock IS NOT NULL THEN 
              EXISTS (
                SELECT 1 
                FROM sparepart_actions spa2 
                WHERE spa2.sparepart_id = sp.id 
                  AND spa2.in_stock = in_stock 
                ORDER BY spa2.created_at DESC 
                LIMIT 1
              )
            ELSE true
          END
      AND CASE 
            WHEN search_param IS NOT NULL THEN 
              (sp.barcode ILIKE '%' || search_param || '%' OR 
               sp.barcode_legacy ILIKE '%' || search_param || '%' OR 
               sssc.name ILIKE '%' || search_param || '%' OR 
               spref.serial_number ILIKE '%' || search_param || '%' OR 
               spref.reference_supplier ILIKE '%' || search_param || '%' OR 
               COALESCE(spa.origin_device_id::text, '') ILIKE '%' || search_param || '%' OR
               CASE WHEN modellist.models IS NOT NULL THEN 
                 EXISTS (
                   SELECT 1 FROM unnest(modellist.models) m
                   WHERE m ILIKE '%' || search_param || '%'
                 )
               ELSE false END
              )
            ELSE true
          END
    ORDER BY sp.created_at ASC
    LIMIT 10
    OFFSET offset_param
  );
END;$$;


ALTER FUNCTION "public"."get_spareparts_raw"("org_id_param" "uuid", "offset_param" bigint, "in_stock" boolean, "search_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spref_by_serial"("sn_param" "text", "offset_param" bigint DEFAULT 0) RETURNS json
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$--get spref details using part of a serial_number
begin RETURN (
  select
    json_agg(
      json_build_object(
        'id',
        sr.id,
        'name',
        sssc.name,
        'price_new',
        sr.price_new,
        'serial_number',
        sr.serial_number,
        'reference_supplier',
        sr.reference_supplier,
        'waiting_time',
        sr.waiting_time_delivery,
        'unavailable',
        sr.unavailable,
        'source_supplier',
        sr.source_supplier,
        'models',
        (
          select json_agg(json_build_object('id', dr.id, 'model', dr.model))
          from public.sparepart_device_references sdr_inner
          join public.device_references dr on dr.id = sdr_inner.model_id
          where sdr_inner.sparepart_reference_id = sr.id
            and sdr_inner.archived is false
        ),
        'device_type_id',
        dssc.id,
        'device_type_name',
        dssc.name,
        'device_brand_id',
        brand_details.id,
        'device_brand_name',
        brand_details.name,
        'device_brand_spref_criteria',
        brand_details.sp_serialnbformat_criteria,
        'link_product_info',
        sr.link_product_info,
        'comments',
        sr.comments
      )
    )
  from
    public.sparepart_references sr
    join public.sparepart_service_sub_categories sssc on sr.sparepart_service_sub_category_id = sssc.id
    join public.device_service_sub_categories dssc on sssc.device_service_sub_category_id = dssc.id
    left join lateral (
      select
        b.id,
        b.name,
        b.sp_serialnbformat_criteria
      from
        public.brands b
      join public.sparepart_device_references sdr on sdr.sparepart_reference_id = sr.id and sdr.archived is false
      join public.device_references dr on dr.id = sdr.model_id
      where
        b.id = dr.brand_id
      limit
        1
    ) brand_details on true
  where
    sr.serial_number ilike '%' || sn_param || '%'
    and sr.archived is false
  order by
    sr.serial_number asc
  offset
    offset_param
  limit
    10
);

end;$$;


ALTER FUNCTION "public"."get_spref_by_serial"("sn_param" "text", "offset_param" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spref_device_files"("spref_id_param" "uuid", "org_id_param" "uuid") RETURNS json[]
    LANGUAGE "sql"
    AS $$
  SELECT COALESCE(array_agg(json_build_object('file_url', df.file_url)), '{}')::json[]
  FROM public.devices_files df
  JOIN public.sparepart_device_references sdr ON df.device_model_id = sdr.model_id
  WHERE sdr.sparepart_reference_id = spref_id_param 
    AND sdr.archived IS FALSE 
    AND df.archived IS FALSE
  group by df.created_at
  ORDER BY df.created_at DESC
  LIMIT 10;
$$;


ALTER FUNCTION "public"."get_spref_device_files"("spref_id_param" "uuid", "org_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sprequest_details"("spreq_id_param" "uuid", "device_id_param" "uuid", "model_id_param" "uuid", "subcat_id_param" "uuid", "brand_id_param" "uuid", "spref_id_param" "uuid") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$select
  json_build_object(
    'sp_stock_taken',
    (
      select
        json_agg(
          json_build_object('barcode', s.barcode, 'sp', s.id)
        )
      from
        public.spareparts s
      where
        s.sparepart_request_id = spreq_id_param
    ),
    'spfiles',
    (
      select
        json_agg(json_build_object('file_url', spfiles.file_url))
      from
        (
          select
            sf.file_url
          from
            public.spareparts_files sf
          where
            sf.sparepart_request_id = spreq_id_param
            and sf.archived is false
        ) spfiles
    ),
    'nameplate',
    nameplate.file_url,
    'reparation_id',
    darepar.id,
    'sp_stock_avail',
    (
      select
        json_agg(
          json_build_object(
            'spstock_id',
            spstock.id,
            'spstock_barcode',
            spstock.barcode,
            'spstock_subarea',
            spstock.subarea
          )
        )
      from
        (
          select
            stock.id,
            stock.barcode,
            subarea.name as subarea
          from
            public.spareparts stock
            left join public.sparepart_actions spaction on spaction.sparepart_id = stock.id
            left join public.sub_areas_storage subarea on spaction.sparepart_id is not null
            and spaction.sub_area_storage_id = subarea.id
          where
            stock.sparepart_reference_id = spref_id_param
            and stock.in_stock is true
            and stock.archived is false
          order by
            stock.barcode asc
          limit
            30
        ) spstock
    )
  )
from
  public.sparepart_requests spreq
  left join lateral (
    select
      df.file_url
    from
      public.devices_files df
    where
      df.device_id = device_id_param
      and df.archived is false
    order by
      df.created_at desc
    limit
      1
  ) nameplate on true
  left join lateral (
    select
      dar.id
    from
      public.device_actions da
      join public.device_actions_reparations dar on da.id = dar.action_id
    where
      da.device_id = device_id_param
      and da.type = 'Mise en test'
      and da.archived is false
      and dar.archived is false
    order by
      da.created_at desc,
      dar.created_at desc
    limit
      1
  ) darepar on true
where
  spreq.id = spreq_id_param;$$;


ALTER FUNCTION "public"."get_sprequest_details"("spreq_id_param" "uuid", "device_id_param" "uuid", "model_id_param" "uuid", "subcat_id_param" "uuid", "brand_id_param" "uuid", "spref_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sprequests_raw"("deviceid_param" "uuid" DEFAULT NULL::"uuid", "searchterm_param" "text" DEFAULT NULL::"text", "status_param" "text" DEFAULT NULL::"text", "creator_id_param" "uuid" DEFAULT NULL::"uuid") RETURNS json[]
    LANGUAGE "plpgsql"
    AS $$--get spRequests with multiple filter options
declare result json[];

begin
select
  array_agg(
    json_build_object(
      'id',
      spreq.id,
      'created_at',
      spreq.created_at,
      'creator',
      u.email,
      'name',
      sssc.name,
      'name_id',
      sssc.id,
      'comments',
      spreq.comments,
      'quantity',
      spreq.quantity,
      'archived',
      spreq.archived,
      'price_new_request',
      spreq.price_new_request,
      'spref_id',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.id ELSE NULL END,
      'serial_number',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.serial_number ELSE null END,
      'waiting_time',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.waiting_time_delivery ELSE spdetail.waiting_time_delivery END,
      'price_new',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.price_new ELSE spdetail.price_new_request END,
      'reference_supplier',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.reference_supplier ELSE spdetail.reference_supplier END,
      'unavailable',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.unavailable ELSE spdetail.unavailable END,
      'source_supplier',
      CASE WHEN spreq.sparepart_reference_id IS NOT NULL THEN spref.source_supplier ELSE spdetail.source_supplier END,
      'status',
      lastaction.status,
      'last_editor',
      lastaction.email,
      'last_edit',
      lastaction.created_at,
      'archived',
      spreq.archived,
      'issue_id',
      issue.id,
      'issue_type',
      issue.type,
      'issue_conclusion',
      issue.conclusion,
      'non_order',
      lastaction.non_order,
      'device_id',
      d.id,
      'device_barcode',
      d.barcode,
      'device_model',
      dr.model,
      'device_model_id',
      dr.id,
      'device_brand',
      b.name,
      'device_brand_id',
      b.id,
      'device_type',
      dssc.name,
      'device_type_id',
      dssc.id
    )
  ) into result
from
  public.sparepart_requests spreq
  join public.devices d on d.id = spreq.device_id
  join public.device_references dr on dr.id = d.device_reference_id
  join public.brands b on b.id = dr.brand_id
  join public.device_service_sub_categories dssc on dssc.id = dr.device_service_sub_category_id
  join public.users u on u.id = spreq.creator
  join public.sparepart_service_sub_categories sssc on sssc.id = spreq.sparepart_service_sub_category_id
  left join lateral (
    select
      *
    from
      public.sparepart_references spr
    where
      spreq.sparepart_reference_id = spr.id
    limit
      1
  ) spref on true
  left join lateral (
    select
      *
    from
      public.sparepart_requests_details spd
    where
      spreq.id = spd.sparepart_request_id
      and spreq.sparepart_reference_id is null
    order by spd.created_at desc
    limit
      1
  ) spdetail on true
  left join lateral (
    select
      spreqa.created_at,
      spreqa.status,
      spreqa.non_order,
      uu.email
    from
      public.sparepart_requests_actions spreqa
      join public.users uu on uu.id = spreqa.creator
    where
      spreqa.sparepart_request_id = spreq.id
    order by
      spreqa.created_at desc
    limit
      1
  ) lastaction on true
  left join lateral (
    select
      id,
      type,
      conclusion
    from
      public.sparepart_requests_issues sri
    where
      sri.sparepart_request_id = spreq.id
      and sri.conclusion is null
      and sri.archived is false
    order by
      sri.created_at desc
    limit
      1
  ) issue on true
where
  (
    deviceid_param is null
    or spreq.device_id = deviceid_param
  )
  and (
    searchterm_param is null
    or (
      d.barcode ilike '%' || searchterm_param || '%'
      or dr.model ilike '%' || searchterm_param || '%'
      or sssc.name ilike '%' || searchterm_param || '%'
      or (spreq.sparepart_reference_id IS NOT NULL AND spref.serial_number ilike '%' || searchterm_param || '%')
      or (spreq.sparepart_reference_id IS NOT NULL AND spref.reference_supplier ilike '%' || searchterm_param || '%')
      or (spreq.sparepart_reference_id IS NULL AND spdetail.reference_supplier ilike '%' || searchterm_param || '%')
      or b.name ilike '%' || searchterm_param || '%'
      or dssc.name ilike '%' || searchterm_param || '%'
    )
  )
  and (
    status_param is null
    or lastaction.status = status_param
  )
  and (
    creator_id_param is null
    or spreq.creator = creator_id_param
  );

RETURN result;

end;$$;


ALTER FUNCTION "public"."get_sprequests_raw"("deviceid_param" "uuid", "searchterm_param" "text", "status_param" "text", "creator_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subarea_barcode"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") RETURNS json[]
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$--search subarea with exact barcode (not id)
select
  array_agg(json_build_object('id', sas.id, 'name', sas.name))
from
  public.sub_areas_storage sas
  join public.areas_storage a on sas.areas_storage_id = a.id
  join public.areas_categories ac on ac.id = a.area_category_id
where
  ac.organization_id = orgid_param
  and sas.barcode = barcode_param
  and ac.category = category_param;$$;


ALTER FUNCTION "public"."get_subarea_barcode"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subarea_barcode_available"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'name', sas.name,
    'id', sas.id
  ) INTO result
  FROM
    public.sub_areas_storage sas
    JOIN public.areas_storage a ON sas.areas_storage_id = a.id
    JOIN public.areas_categories ac ON ac.id = a.area_category_id
    LEFT JOIN (
      SELECT 
        latest_actions.sub_area_storage_id,
        COUNT(DISTINCT latest_actions.device_id) AS count
      FROM (
        SELECT DISTINCT ON (device_id)
          device_id,
          sub_area_storage_id
        FROM 
          public.device_actions
        WHERE 
          archived = false
        ORDER BY 
          device_id, last_edit DESC
      ) AS latest_actions
      WHERE 
        latest_actions.sub_area_storage_id IS NOT NULL
      GROUP BY 
        latest_actions.sub_area_storage_id
    ) AS current_devices ON sas.id = current_devices.sub_area_storage_id
  WHERE 
    ac.organization_id = orgid_param
    AND sas.barcode = barcode_param
    AND ac.category = category_param
    AND sas.capacity > COALESCE(current_devices.count, 0)
  LIMIT 1;
  
  RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_subarea_barcode_available"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subareas_filter"("area_id_param" "uuid", "offset_param" integer DEFAULT 0, "limit_param" integer DEFAULT 10, "availability_param" boolean DEFAULT true, "area_cat_param" "text" DEFAULT NULL::"text", "org_id_param" "uuid" DEFAULT NULL::"uuid", "subarea_name_param" "text" DEFAULT NULL::"text") RETURNS json[]
    LANGUAGE "plpgsql"
    AS $$--search subarea based on area_id

DECLARE
    result json[];
BEGIN
    SELECT array_agg(row_to_json(t))
    INTO result
    FROM (
        SELECT 
            sas.name,
            sas.id
        FROM 
            public.sub_areas_storage sas
            join public.areas_storage a on a.id=sas.areas_storage_id
            join public.areas_categories ac on ac.id=a.area_category_id
        LEFT JOIN (
            SELECT 
                latest_actions.sub_area_storage_id,
                COUNT(DISTINCT latest_actions.device_id) AS count
            FROM (
                SELECT DISTINCT ON (device_id)
                    device_id,
                    sub_area_storage_id
                FROM 
                    public.device_actions
                WHERE 
                    archived = false
                ORDER BY 
                    device_id, last_edit DESC
            ) AS latest_actions
            WHERE 
                latest_actions.sub_area_storage_id IS NOT NULL
            GROUP BY 
                latest_actions.sub_area_storage_id
        ) AS current_devices ON sas.id = current_devices.sub_area_storage_id
        WHERE 
            ac.category='devices' 
            and ac.organization_id = org_id_param
            AND (area_id_param IS NULL OR sas.areas_storage_id = area_id_param)
            AND (area_cat_param IS NULL OR ac.name = area_cat_param)
            AND (subarea_name_param IS NULL OR sas.name ILIKE '%' || subarea_name_param || '%')
            AND (
                NOT availability_param 
                OR sas.capacity > COALESCE(current_devices.count, 0)
            )
        ORDER BY 
            sas.name ASC
        OFFSET offset_param
        LIMIT limit_param
    ) t;
    RETURN result;
END;$$;


ALTER FUNCTION "public"."get_subareas_filter"("area_id_param" "uuid", "offset_param" integer, "limit_param" integer, "availability_param" boolean, "area_cat_param" "text", "org_id_param" "uuid", "subarea_name_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subareas_generic"("organization_id_param" "uuid", "area_name_param" character varying, "area_type_param" "text" DEFAULT NULL::"text") RETURNS json[]
    LANGUAGE "plpgsql"
    AS $$--script useful for clean or quality, cause I don't have this org's "Zone qualité" or "Zone nettoyage" id >> filter on these generic names and get subarea data
    
    
DECLARE
    result json[];
BEGIN
    
    SELECT array_agg(row_to_json(t))
    INTO result
    FROM (
        SELECT 
            sas.name,
            sas.id
        FROM 
            public.sub_areas_storage sas
            join public.areas_storage a on a.id=sas.areas_storage_id
            join public.areas_categories ac on ac.id=a.area_category_id
            WHERE 
                ac.organization_id=organization_id_param AND
                (
                    (area_type_param IS NULL AND a.name=area_name_param) OR
                    (area_type_param IS NOT NULL AND ac.name=area_type_param)
                )
    ) t;
    RETURN result;
END;$$;


ALTER FUNCTION "public"."get_subareas_generic"("organization_id_param" "uuid", "area_name_param" character varying, "area_type_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subcat_sp"("subcat_param" "uuid") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$select
  json_agg(json_build_object('sp', name,'id',id))
from
  public.sparepart_service_sub_categories
where
  device_service_sub_category_id = subcat_param;$$;


ALTER FUNCTION "public"."get_subcat_sp"("subcat_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_subcat_sp_spareka"("subcat_param" "uuid") RETURNS json
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  SELECT
    json_agg(
      json_build_object(
        'sp', sssc.name,
        'id', sssc.id,
        'spareka_cat', ds.name, --spareka1 = device_services
        'spareka_subcat', dsc.name, --spareka2 = device_service_categories
        'spareka_subsubcat', ssc.name --spareka3 = sparepart_sub_categories
      )
    )
  FROM
    public.sparepart_service_sub_categories sssc
    JOIN public.sparepart_sub_categories ssc ON sssc.sparepart_sub_category_id = ssc.id
    JOIN public.device_service_sub_categories dssc ON sssc.device_service_sub_category_id = dssc.id
    JOIN public.device_service_categories dsc ON dssc.device_service_category_id = dsc.id
    JOIN public.device_sub_services dss ON dsc.device_sub_service_id = dss.id
    JOIN public.device_services ds ON dss.device_service_id = ds.id
  WHERE
    sssc.device_service_sub_category_id = subcat_param;
$$;


ALTER FUNCTION "public"."get_subcat_sp_spareka"("subcat_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_users_raw"("organization_id_param" "uuid" DEFAULT NULL::"uuid", "deleted_param" boolean DEFAULT false) RETURNS json[]
    LANGUAGE "sql"
    AS $$WITH user_data AS (
  SELECT
    u.id,
    u.organization_id,
    u.deleted,
    u.notif_auth,
    u.name,
    u.email,
    u.roles,
    u.hourly_cost,
    u.replacer,
    ARRAY_AGG(DISTINCT e.id) FILTER (WHERE e.id IS NOT NULL) AS employee_ids,
    EXISTS (
      SELECT 1 
      FROM public.users_holidays h 
      WHERE 
        h.user_id = u.id 
        AND h.archived IS FALSE 
        AND CURRENT_DATE BETWEEN h.date_start AND h.date_end
    ) AS holidays
  FROM
    public.users u
    LEFT JOIN LATERAL (
      SELECT 
        o.employee,
        eu.id,
        eu.email
      FROM
        public.organigram o
        JOIN public.users eu ON eu.id = o.employee
      WHERE
        o.manager = u.id AND o.archived IS FALSE
    ) e ON true
  WHERE
    u.organization_id = organization_id_param
    AND (
      deleted_param IS NULL
      OR u.deleted = deleted_param
    )
  GROUP BY 
    u.id, u.organization_id, u.deleted, u.notif_auth, 
    u.email, u.roles,u.name
)
SELECT 
  ARRAY_AGG(
    json_build_object(
      'id', id,
      'organization_id', organization_id,
      'deleted', deleted,
      'notif_auth', notif_auth,
      'email', email,
      'roles', roles,
      'replacer', replacer,
      'employees', employee_ids,
      'holidays', holidays,
      'name',name
    )
    ORDER BY email
  )
FROM user_data;$$;


ALTER FUNCTION "public"."get_users_raw"("organization_id_param" "uuid", "deleted_param" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."on_update_device_actions"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$declare 
updateId uuid;

begin 

if new.type = 'Lot de vente'
and old.finished = true
and new.finished = false then 
  updateId = (
    select
      id
    from
      device_actions
    where
      device_id = new.device_id
      and type = 'Vente lot'
      and archived is false
    order by
      created_at desc
    limit
      1
  );

  update device_actions
  set
    archived = true
  where
    id = updateId;

end if;

end;$$;


ALTER FUNCTION "public"."on_update_device_actions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."on_update_sale_purchase_lot_devices"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$--objective: for each device restored after ANNULé or REFUSé, catch the ones impossible to restore because already in another saleLot
declare 
nb bigint;
actionId uuid;
statusVar text;
priceVar float;
creatorVar uuid;

begin 

if old.archived is true and new.archived is false then 
  nb = (
    select
      count(id)
    from
      public.sale_purchase_lot_devices
    where
      type = 'sale'
      and sale_purchase_lot_id != new.sale_purchase_lot_id
      and device_id = new.device_id
      and archived is false
  );

  if nb > 0 then --impossible restore
    update public.sale_purchase_lot_devices
    set
      restore_failed = true,
      archived = true
    where
      id = new.id;

  else --possible restore
    actionId = (
      select
        id
      from
        device_actions
      where
        archived is false
        and device_id = new.device_id
        and type = 'Lot de vente'
      order by
        created_at desc
      limit
        1
    );

    select status,custom_sale_price,creator 
      into statusVar,priceVar,creatorVar
    from
      device_actions_sales_lot
    where
      action_id = actionId;

    update device_actions
    set
      finished = false
    where
      id = actionId;

    insert into
      device_actions_sales_lot (
        creator,
        action_id,
        type,
        custom_sale_price,
        status,
        sale_lot_id
      )
    values
      (creatorVar, actionId, 'lot_restore',priceVar,statusVar,new.sale_purchase_lot_id);
  end if;

end if;

end;$$;


ALTER FUNCTION "public"."on_update_sale_purchase_lot_devices"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sp_schema_details"("sp_schema_id_param" "uuid") RETURNS json
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN (
        SELECT json_build_object(
            'id', sssc.id,
            'name', sssc.name,
            'nomenclature', sssc.nomenclature,
            'spareka_cat', ssc.name,
            'archived',sssc.archived
        )
        FROM public.sparepart_service_sub_categories sssc
        JOIN public.sparepart_sub_categories ssc ON ssc.id = sssc.sparepart_sub_category_id
        WHERE sssc.id = sp_schema_id_param
    );
END;$$;


ALTER FUNCTION "public"."sp_schema_details"("sp_schema_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_device_actions_reception"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$declare age bigint;

current_year bigint;

begin
if new.year_production is not null then current_year = (
  select
    EXTRACT(
      year
      from
        CURRENT_TIMESTAMP
    )
);

age = current_year - new.year_production;

if age > 10 then
update public.device_actions_reception dar
set
  prequalif = array_append(dar.prequalif, 'Age > 10 ans'),
  compliance = false
from
  public.device_actions da
  join public.devices d on d.id = da.device_id
where
  dar.action_id = da.id
  and d.device_reference_id = NEW.id;

else --age<=10y
update public.device_actions_reception dar
set
  prequalif = array_remove(dar.prequalif, 'Age > 10 ans'),
  compliance = false
from
  public.device_actions da
  join public.devices d on d.id = da.device_id
where
  dar.action_id = da.id
  and d.device_reference_id = NEW.id
  and cardinality(dar.prequalif) > 0;

update public.device_actions_reception dar
set
  prequalif = array_remove(dar.prequalif, 'Age > 10 ans'),
  compliance = true
from
  public.device_actions da
  join public.devices d on d.id = da.device_id
where
  dar.action_id = da.id
  and d.device_reference_id = NEW.id
  and cardinality(dar.prequalif) = 0;

end if; --> or < 10y

end if; --null

RETURN NEW;

end;$$;


ALTER FUNCTION "public"."update_device_actions_reception"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."areas_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" DEFAULT "gen_random_uuid"(),
    "name" character varying,
    "category" character varying
);


ALTER TABLE "public"."areas_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."areas_categories" IS 'cat ou type d''area (tests, stockage, ZR etc)';



COMMENT ON COLUMN "public"."areas_categories"."category" IS 'sp,devices';



CREATE TABLE IF NOT EXISTS "public"."areas_storage" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "display_order" smallint,
    "area_category_id" "uuid"
);


ALTER TABLE "public"."areas_storage" OWNER TO "postgres";


COMMENT ON COLUMN "public"."areas_storage"."name" IS 'Rack A,B,C, ligne 1,2,3, ZR,ZQ etc';



CREATE TABLE IF NOT EXISTS "public"."brands" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "grade" character varying NOT NULL,
    "spareka_ref_change_type" character varying,
    "spareka_ref_change_value" smallint,
    "sp_serialnbformat_criteria" "jsonb",
    "archived" boolean DEFAULT false,
    CONSTRAINT "brands_grade_check" CHECK ((("grade")::"text" = ANY (("enum_range"(NULL::"public"."brand_grade"))::"text"[])))
);


ALTER TABLE "public"."brands" OWNER TO "postgres";


COMMENT ON COLUMN "public"."brands"."spareka_ref_change_type" IS 'start or end of character chain to edit for Spareka model // or null';



COMMENT ON COLUMN "public"."brands"."spareka_ref_change_value" IS 'how many char to delete according to TYPE (start/end)';



COMMENT ON COLUMN "public"."brands"."sp_serialnbformat_criteria" IS 'zero, une ou plusieurs options de structure de spref pour chaque brand';



CREATE TABLE IF NOT EXISTS "public"."client_contacts" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "creator" "text" NOT NULL,
    "client_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "email" "text" NOT NULL,
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."client_contacts" OWNER TO "postgres";


COMMENT ON TABLE "public"."client_contacts" IS 'emails for clients';



ALTER TABLE "public"."client_contacts" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."client_contacts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."client_supplier_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "name" character varying NOT NULL,
    "type" character varying[] NOT NULL,
    "owner_id" "uuid",
    "archived" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."client_supplier_groups" OWNER TO "postgres";


COMMENT ON COLUMN "public"."client_supplier_groups"."type" IS 'client,supplier';



CREATE TABLE IF NOT EXISTS "public"."clients" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "name" character varying NOT NULL,
    "group_id" "uuid",
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "archived" boolean DEFAULT false,
    "address" "text",
    "address_complement" "text",
    "zipcode" "text",
    "city" "text",
    "country" "text",
    "comments" "text"
);


ALTER TABLE "public"."clients" OWNER TO "postgres";


COMMENT ON TABLE "public"."clients" IS 'rls policy on select and update if owner_id=current_user_organization_id';



CREATE TABLE IF NOT EXISTS "public"."device_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "device_id" "uuid" NOT NULL,
    "type" character varying NOT NULL,
    "status" character varying NOT NULL,
    "sub_area_storage_id" "uuid",
    "archived" boolean DEFAULT false,
    "finished" boolean DEFAULT true,
    "last_edit" timestamp without time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."device_actions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_actions"."type" IS 'Mise à jour budget, Retour, Lot de vente, Archivage appareil, Vente lot, Reverse, Nettoyage, Mise en test, Remise en test, Réception, Rack soldeur, Démontage terminé, Démontage, Qualité, Logistique';



COMMENT ON COLUMN "public"."device_actions"."finished" IS 'one action in ACTIONS and several sub_actions linked to it >> batch is finished?';



CREATE TABLE IF NOT EXISTS "public"."device_actions_aftersales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "action_id" "uuid" NOT NULL,
    "type" character varying,
    "archived" boolean DEFAULT false,
    "accepted" boolean NOT NULL,
    "category" character varying,
    "sub_category" character varying,
    "failure_date" timestamp without time zone,
    "nogo_reason" "text",
    "justified" boolean,
    "sale_date" timestamp without time zone,
    "justified_comments" "text",
    "output" character varying,
    "status" character varying,
    "refused_confirmation" boolean,
    "failure_comments" "text"
);


ALTER TABLE "public"."device_actions_aftersales" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_actions_aftersales"."type" IS 'Déclaration,Evolution, Conclusion';



COMMENT ON COLUMN "public"."device_actions_aftersales"."category" IS 'Physique, Suivi';



COMMENT ON COLUMN "public"."device_actions_aftersales"."sub_category" IS 'Litige reception, Retour client';



COMMENT ON COLUMN "public"."device_actions_aftersales"."nogo_reason" IS 'MODE dans V2.1. : Conditionnement non-conforme,Produit deteriore,Produit incomplet';



COMMENT ON COLUMN "public"."device_actions_aftersales"."output" IS 'Reparation,Remboursement,Remplacement';



COMMENT ON COLUMN "public"."device_actions_aftersales"."status" IS 'Fonctionnel,Panne non-correspondante au retour,Panne correspondante au retour';



CREATE TABLE IF NOT EXISTS "public"."device_actions_budget" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "action_id" "uuid" NOT NULL,
    "archived" boolean DEFAULT false,
    "purchase_price" real,
    "purchase_price_custom" real,
    "sale_price" real,
    "transport_cost" real,
    "diagnostic_cost" real,
    "other_cost" real,
    "prediag_cost" real,
    "max_loss" real,
    "prediag_addedvalue" real,
    "cleaning_cost" real,
    "prelog_cost" real,
    "postlog_cost" real,
    "pallet_cost" real,
    "film_cost" real,
    "consumables_cost" real,
    "aftersales_cost" real,
    "energy_cost" real,
    "repair_cost" real,
    "margin" real,
    "storage_cost" real,
    "disassembly_cost" real
);


ALTER TABLE "public"."device_actions_budget" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_actions_budget"."diagnostic_cost" IS 'diagBudgetVar = diagHourlyVar * diagDurationVar;';



COMMENT ON COLUMN "public"."device_actions_budget"."other_cost" IS 'Cout_nettoyage+Cout_log+Cout_palette+Cout_film+Cout_consommableNettoyage+Cout_SAV+Cout_energie';



COMMENT ON COLUMN "public"."device_actions_budget"."prediag_cost" IS '-{Max_loss}+Other_costs';



COMMENT ON COLUMN "public"."device_actions_budget"."max_loss" IS '-(Achat_prix+Achat_transport+Cout_diag)';



COMMENT ON COLUMN "public"."device_actions_budget"."prediag_addedvalue" IS '{Prix de vente estimé}-{All_costs préDiag}';



COMMENT ON COLUMN "public"."device_actions_budget"."cleaning_cost" IS 'Cout_nettoyage (hors froid) = Taux horaire (12) x nombre d’heure jour (7) x nombre d’opérateurs (2) / nombre d’appareil jour (16) //// Cout_nettoyage (froid) = Taux horaire (12) x nombre d’heure jour (7) x nombre d’opérateurs (2) / nombre d’appareil jour (10)';



COMMENT ON COLUMN "public"."device_actions_budget"."prelog_cost" IS 'Cout_log_pre = Taux horaire (13,5) x nombre de temps appareil (0,2)';



COMMENT ON COLUMN "public"."device_actions_budget"."postlog_cost" IS 'Cout_log_post = Taux horaire (13,5) x nombre de temps appareil (0,8)';



COMMENT ON COLUMN "public"."device_actions_budget"."pallet_cost" IS 'IF({service}="froid",4.5,4.5/2)';



COMMENT ON COLUMN "public"."device_actions_budget"."film_cost" IS 'Cout_film (hors froid) = Coût_film unitaire (0,6) Cout_film (froid) = Coût_film unitaire (0,6) x 2';



COMMENT ON COLUMN "public"."device_actions_budget"."consumables_cost" IS '2€';



COMMENT ON COLUMN "public"."device_actions_budget"."aftersales_cost" IS 'Cout_SAV = 7 % x Prix de vente estimé';



COMMENT ON COLUMN "public"."device_actions_budget"."energy_cost" IS '5€';



COMMENT ON COLUMN "public"."device_actions_budget"."repair_cost" IS 'repairHourlyVar * repairDurationVar;';



COMMENT ON COLUMN "public"."device_actions_budget"."margin" IS 'Marge_DN = 5 % x Prix de vente estimé';



COMMENT ON COLUMN "public"."device_actions_budget"."storage_cost" IS 'Cout_stockage = Cout unitaire de stockage quotidien (0,35) x Diff[Date de Réception – Date du jour]';



COMMENT ON COLUMN "public"."device_actions_budget"."disassembly_cost" IS 'Cout_démontage = Taux horaire alternant (8) x nombre d’heures par jour (7) / nombre de machines jour (5)';



CREATE TABLE IF NOT EXISTS "public"."device_actions_quality" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "action_id" "uuid" NOT NULL,
    "archived" boolean DEFAULT false,
    "grade" character varying,
    "imperfection" boolean DEFAULT false,
    "comments" "text",
    "wholesale" boolean DEFAULT false,
    "nogo_reason" "text"[]
);


ALTER TABLE "public"."device_actions_quality" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_actions_reception" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "action_id" "uuid" NOT NULL,
    "archived" boolean DEFAULT false,
    "grade" character varying NOT NULL,
    "compliance" boolean NOT NULL,
    "prequalif" "text"[],
    "prequalif_comments" "text"
);


ALTER TABLE "public"."device_actions_reception" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_actions_reparation_failures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "reparation_id" "uuid" NOT NULL,
    "micro_failure_id" "uuid",
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."device_actions_reparation_failures" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_actions_reparation_tests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "reparation_id" "uuid" NOT NULL,
    "test_id" "uuid" NOT NULL,
    "type" character varying NOT NULL,
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."device_actions_reparation_tests" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_actions_reparation_tests"."type" IS 'pre,post';



CREATE TABLE IF NOT EXISTS "public"."device_actions_reparations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "action_id" "uuid" NOT NULL,
    "error_code" "text",
    "comments" "text",
    "status" character varying,
    "type" character varying,
    "archived" boolean DEFAULT false,
    "functional_device" boolean DEFAULT false,
    "refill_done" boolean DEFAULT false
);


ALTER TABLE "public"."device_actions_reparations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_actions_reparations"."type" IS 'initial_diagnostic, initial_repair, quality_nc_diagnostic, quality_nc_repair';



CREATE TABLE IF NOT EXISTS "public"."device_actions_sales_lot" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "action_id" "uuid" NOT NULL,
    "archived" boolean DEFAULT false,
    "type" character varying NOT NULL,
    "custom_sale_price" real,
    "status" character varying NOT NULL,
    "sale_lot_id" "uuid" NOT NULL
);


ALTER TABLE "public"."device_actions_sales_lot" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_actions_sales_lot"."type" IS 'lot_addition, lot_removal_manual, lot_update, lot_sale, lot_reactivation, lot_cancellation,price_updatelot_restore';



COMMENT ON COLUMN "public"."device_actions_sales_lot"."custom_sale_price" IS 'if customized. If not, refer to device_budgets';



CREATE TABLE IF NOT EXISTS "public"."device_macro_failures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "device_service_sub_category_id" "uuid",
    "organization_id" "uuid"
);


ALTER TABLE "public"."device_macro_failures" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_micro_failures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "macro_failure_id" "uuid"
);


ALTER TABLE "public"."device_micro_failures" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_ownership_transfer" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "device_id" "uuid" NOT NULL,
    "old_owner" "uuid" NOT NULL,
    "new_owner" "uuid" NOT NULL
);


ALTER TABLE "public"."device_ownership_transfer" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_references" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "model" character varying NOT NULL,
    "brand_id" "uuid",
    "device_service_sub_category_id" "uuid",
    "price_new" double precision,
    "color" "text",
    "year_production" bigint,
    "length" real,
    "width" real,
    "height" real,
    "parcel_size" character varying,
    "spareka_model" character varying,
    "pose_type" character varying,
    "eans" "text"[],
    "internal_refs" "text"[],
    "weight" real,
    "wash_capacity" real,
    "dry_capacity" real,
    "efficiency_class" "jsonb"[],
    "archived" boolean DEFAULT false,
    "other_characteristics" character varying
);


ALTER TABLE "public"."device_references" OWNER TO "postgres";


COMMENT ON COLUMN "public"."device_references"."pose_type" IS '1 : Libre / 2 : Intégrable / 3 : Encastrable (ou Entièrement intégrable) / 4 : Murale';



COMMENT ON COLUMN "public"."device_references"."eans" IS 'barcodes';



COMMENT ON COLUMN "public"."device_references"."efficiency_class" IS '{[type:energie,value:XX],[type:lavage,value:XX],[type:sechage,value:XX],}';



COMMENT ON COLUMN "public"."device_references"."other_characteristics" IS 'Seche-linge : dry_type / Refrig : fd_type (type porte)';



CREATE TABLE IF NOT EXISTS "public"."device_references_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "device_reference_id" "uuid" NOT NULL,
    "model" character varying NOT NULL,
    "brand" "uuid",
    "devices_service_sub_categorie_id" "uuid",
    "price_new" double precision,
    "color" "text",
    "year_production" bigint,
    "length" bigint,
    "width" bigint,
    "height" bigint,
    "parcel_size" character varying,
    "spareka_model" character varying
);


ALTER TABLE "public"."device_references_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_service_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "device_sub_service_id" "uuid",
    "pose_type_options" character varying[]
);


ALTER TABLE "public"."device_service_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."device_service_categories" IS 'Spareka2 = LL rassemble LLT et LLH etc';



COMMENT ON COLUMN "public"."device_service_categories"."pose_type_options" IS 'options de post_type possible pour ce sub_service (pas pour tous)';



CREATE TABLE IF NOT EXISTS "public"."device_service_sub_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "device_service_category_id" "uuid",
    "diag_duration" real,
    "length" real,
    "width" real,
    "height" real,
    "parcel_size" character varying,
    "weight" real,
    "repair_duration" real,
    "tests_reparation" "text"[],
    "youzd_subcategory_id" "uuid",
    "youzd_name" character varying
);


ALTER TABLE "public"."device_service_sub_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."device_service_sub_categories" IS 'Type Doneo : LLT, LLSH etc';



CREATE TABLE IF NOT EXISTS "public"."device_services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL
);


ALTER TABLE "public"."device_services" OWNER TO "postgres";


COMMENT ON TABLE "public"."device_services" IS 'Spareka1 = Electromenager, Multimedia';



CREATE TABLE IF NOT EXISTS "public"."device_sub_services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "device_service_id" "uuid"
);


ALTER TABLE "public"."device_sub_services" OWNER TO "postgres";


COMMENT ON TABLE "public"."device_sub_services" IS 'Service Doneo : froid, lavage, chaud';



CREATE TABLE IF NOT EXISTS "public"."device_tests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "device_service_sub_category_id" "uuid",
    "organization_id" "uuid",
    "display_order" smallint
);


ALTER TABLE "public"."device_tests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "barcode" character varying NOT NULL,
    "device_reference_id" "uuid",
    "status" character varying,
    "archived" boolean DEFAULT false NOT NULL,
    "exclude_youzd" boolean DEFAULT false NOT NULL,
    "imported_youzd" boolean DEFAULT false NOT NULL,
    CONSTRAINT "barcode_length" CHECK (("length"(("barcode")::"text") = 6))
);


ALTER TABLE "public"."devices" OWNER TO "postgres";


COMMENT ON COLUMN "public"."devices"."status" IS 'le status est mis à jour par un triger sur la table device_actions. Can be null when device created, cause the script will determine status. Champ et ici et pas que dans ACTIONS, pour donner accès aux suppliers pour le suivi post-envoi';



CREATE TABLE IF NOT EXISTS "public"."devices_files" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "uuid",
    "device_action_id" "uuid",
    "file_url" "text" NOT NULL,
    "type" character varying NOT NULL,
    "archived" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "device_model_id" "uuid"
);


ALTER TABLE "public"."devices_files" OWNER TO "postgres";


COMMENT ON COLUMN "public"."devices_files"."type" IS 'nameplate, defective_sp_reception, important_imperfection, quality,temperature,aftersales_cleaning,valid_repair,aftersales,aftersales_info,credit_note';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "sender" "text" NOT NULL,
    "recipients" "text"[] NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "link_type" "text" NOT NULL,
    "link_value" "text" NOT NULL,
    "link_value2" "text",
    "read" boolean DEFAULT false
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


COMMENT ON COLUMN "public"."notifications"."link_type" IS 'device,log,deviceRef,spRequestPrice,spRefTodo,spRequest';



CREATE TABLE IF NOT EXISTS "public"."organigram" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text",
    "manager" "text",
    "employee" "text",
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."organigram" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_device_costs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "device_service_sub_category_id" "uuid",
    "type" character varying NOT NULL,
    "value" real
);


ALTER TABLE "public"."organization_device_costs" OWNER TO "postgres";


COMMENT ON TABLE "public"."organization_device_costs" IS 'o	cleaning_cost: IF(service_presta="Froid",2000/(8*22),2000/(10*22)) o	log : 1800/(20*22) o	pallet = IF({Type de produit}="Réfrigérateur AM",4.5,4.5/2) o	film = 15/25 o	consum 2 o	aftersales {Prix de vente estimé}*0.05 o	energy 5';



COMMENT ON COLUMN "public"."organization_device_costs"."type" IS 'fixe ou salePrice ou XX';



CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "name" character varying NOT NULL,
    "type" "text"[] NOT NULL
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organizations"."type" IS 'values must be refurbish,buy,supply';



CREATE TABLE IF NOT EXISTS "public"."sale_purchase_lot_devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text",
    "sale_purchase_lot_id" "uuid",
    "device_id" "uuid",
    "archived" boolean DEFAULT false,
    "restore_failed" boolean DEFAULT false,
    "type" character varying DEFAULT ''::character varying NOT NULL
);


ALTER TABLE "public"."sale_purchase_lot_devices" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sale_purchase_lot_devices"."creator" IS 'just tracking, but not device creator. For creator, refer to OWNERSHIP table';



COMMENT ON COLUMN "public"."sale_purchase_lot_devices"."restore_failed" IS 'for sale_lot, when restored, if device is already in another lot, not redispatched in this lot';



COMMENT ON COLUMN "public"."sale_purchase_lot_devices"."type" IS 'sale,purchase';



CREATE TABLE IF NOT EXISTS "public"."sales_invoice_import" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "device_id" "uuid",
    "sale_price" real,
    "percent_new_price" real
);


ALTER TABLE "public"."sales_invoice_import" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sales_invoice_import"."percent_new_price" IS 'percent of sale_price vs. new_price';



CREATE TABLE IF NOT EXISTS "public"."sales_purchase_lot_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "sales_purchase_lot_id" "uuid" NOT NULL,
    "creator" "text" NOT NULL,
    "status" character varying,
    "type" character varying NOT NULL,
    "device_pricing_mode" character varying,
    "device_pricing_value" real,
    "transport_pricing_mode" character varying,
    "transport_pricing_value" real
);


ALTER TABLE "public"."sales_purchase_lot_actions" OWNER TO "postgres";


COMMENT ON TABLE "public"."sales_purchase_lot_actions" IS 'pricing/transport fields are duplicates comparing to spl, only for history. Actions are not used for another purpose';



COMMENT ON COLUMN "public"."sales_purchase_lot_actions"."status" IS 'sale: sale_lot status // purchase: null for now because not useful';



COMMENT ON COLUMN "public"."sales_purchase_lot_actions"."type" IS 'sale: creation,edit_name_client,devices_edit,status_edit,restore,reactivation // purch:??';



CREATE TABLE IF NOT EXISTS "public"."sales_purchase_lots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "supplier_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "name" character varying NOT NULL,
    "type" character varying,
    "hidden" boolean DEFAULT false,
    "archived" boolean DEFAULT false,
    "device_pricing_mode" character varying,
    "device_pricing_value" real,
    "transport_pricing_mode" character varying,
    "transport_pricing_value" real
);


ALTER TABLE "public"."sales_purchase_lots" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sales_purchase_lots"."type" IS 'CDR,PHU';



COMMENT ON COLUMN "public"."sales_purchase_lots"."device_pricing_mode" IS 'matrix,fixed_price, fixed_pourcentage, service';



COMMENT ON COLUMN "public"."sales_purchase_lots"."device_pricing_value" IS '% or €, depending on device_pricing_mode, if not matrix and not service';



COMMENT ON COLUMN "public"."sales_purchase_lots"."transport_pricing_mode" IS '-	fixed (per device) or shared (total, to be divided by nb of devices in lot) or matrix (check matrix)';



CREATE TABLE IF NOT EXISTS "public"."sales_purchase_pricing_matrix" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "supplier_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "device_reference_sub_category_id" "uuid" NOT NULL,
    "internal_grade" character varying NOT NULL,
    "brand_grade" character varying NOT NULL,
    "const_price" real,
    "const_percent" real,
    "transport_price" real
);


ALTER TABLE "public"."sales_purchase_pricing_matrix" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sparepart_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "sparepart_id" "uuid" NOT NULL,
    "type" character varying NOT NULL,
    "sub_area_storage_id" "uuid",
    "in_stock" boolean DEFAULT true,
    "origin" character varying,
    "origin_device_id" "uuid",
    "archived" boolean DEFAULT false,
    "sparepart_reference_id" "uuid"
);


ALTER TABLE "public"."sparepart_actions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sparepart_actions"."type" IS 'Logistique, Vente , Réparation, Réintegration, Intégration, Autre sortie,Modification,Suppression';



CREATE TABLE IF NOT EXISTS "public"."sparepart_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL
);


ALTER TABLE "public"."sparepart_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."sparepart_categories" IS 'Table créée en anticipation, quand on aurait un niveau au-dessus des Spareka3';



CREATE TABLE IF NOT EXISTS "public"."sparepart_device_references" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "sparepart_reference_id" "uuid",
    "model_id" "uuid",
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."sparepart_device_references" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sparepart_reference_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "sparepart_reference_id" "uuid",
    "price_new" real,
    "reference_supplier" character varying,
    "first_time_origin" character varying,
    "waiting_time_delivery" character varying,
    "source_supplier" character varying,
    "link_product_info" "text",
    "comments" "text",
    "unavailable" boolean DEFAULT false,
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."sparepart_reference_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sparepart_references" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "serial_number" character varying,
    "price_new" real,
    "reference_supplier" character varying,
    "first_time_origin" character varying,
    "waiting_time_delivery" character varying,
    "unavailable" boolean DEFAULT false,
    "archived" boolean DEFAULT false,
    "creator" "text" NOT NULL,
    "sparepart_service_sub_category_id" "uuid" NOT NULL,
    "source_supplier" character varying,
    "link_product_info" "text",
    "comments" "text"
);


ALTER TABLE "public"."sparepart_references" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sparepart_references"."first_time_origin" IS 'request,deee,new,reserve etc';



COMMENT ON COLUMN "public"."sparepart_references"."sparepart_service_sub_category_id" IS 'type sp vs. type device >> schema theorique general des sp';



COMMENT ON COLUMN "public"."sparepart_references"."source_supplier" IS 'where did I find the price?';



CREATE TABLE IF NOT EXISTS "public"."sparepart_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "sparepart_reference_id" "uuid",
    "comments" "text",
    "quantity" bigint,
    "archived" boolean DEFAULT false,
    "device_id" "uuid" NOT NULL,
    "price_new_request" real,
    "sparepart_service_sub_category_id" "uuid" NOT NULL
);


ALTER TABLE "public"."sparepart_requests" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sparepart_requests"."price_new_request" IS 'price_new spécifique de la request, peut être différent de la ref';



CREATE TABLE IF NOT EXISTS "public"."sparepart_requests_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "sparepart_request_id" "uuid",
    "status" character varying NOT NULL,
    "non_order" character varying,
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."sparepart_requests_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sparepart_requests_details" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "sparepart_request_id" "uuid",
    "unavailable" boolean DEFAULT false,
    "price_new_request" real,
    "reference_supplier" "text",
    "source_supplier" character varying,
    "waiting_time_delivery" character varying
);


ALTER TABLE "public"."sparepart_requests_details" OWNER TO "postgres";


COMMENT ON TABLE "public"."sparepart_requests_details" IS 'for spreq data when unknown sp and still don''t have any spref or serialnb so impossible to insert data in spref, but need to save this data to unlock diag';



CREATE TABLE IF NOT EXISTS "public"."sparepart_requests_issues" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "creator" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "type" character varying,
    "conclusion" character varying,
    "sparepart_request_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "archived" boolean DEFAULT false,
    "last_edit" timestamp without time zone DEFAULT "now"() NOT NULL,
    "last_editor" "text"
);


ALTER TABLE "public"."sparepart_requests_issues" OWNER TO "postgres";


COMMENT ON TABLE "public"."sparepart_requests_issues" IS 'for spreq issues. One row per issue. At the beginning, without type/conclusion. Then just update when we have type/conclusion. One spreq can have various issues, always one issue=one row';



CREATE TABLE IF NOT EXISTS "public"."sparepart_requests_sp_stock" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "creator" "text",
    "sparepart_request_id" "uuid" DEFAULT "gen_random_uuid"(),
    "sparepart_id" "uuid" DEFAULT "gen_random_uuid"(),
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."sparepart_requests_sp_stock" OWNER TO "postgres";


COMMENT ON TABLE "public"."sparepart_requests_sp_stock" IS 'Match between sp_stock and sp_requests. If archived, pickup is cancelled. If not, means the sp is used for the given spreq';



ALTER TABLE "public"."sparepart_requests_sp_stock" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."sparepart_requests_sp_stock_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."sparepart_service_sub_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_service_sub_category_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" character varying NOT NULL,
    "sparepart_sub_category_id" "uuid" NOT NULL,
    "nomenclature" boolean DEFAULT true NOT NULL,
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."sparepart_service_sub_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."sparepart_service_sub_categories" IS 'matching device_type et sparepart_type';



COMMENT ON COLUMN "public"."sparepart_service_sub_categories"."nomenclature" IS 'must spref nomenclature be applied or not?';



CREATE TABLE IF NOT EXISTS "public"."sparepart_sub_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "name" character varying NOT NULL,
    "sparepart_category_id" "uuid"
);


ALTER TABLE "public"."sparepart_sub_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."sparepart_sub_categories" IS 'catégories Spareka';



CREATE TABLE IF NOT EXISTS "public"."spareparts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text" NOT NULL,
    "barcode" character varying NOT NULL,
    "sparepart_reference_id" "uuid",
    "archived" boolean DEFAULT false,
    "sparepart_service_sub_category_id" "uuid" NOT NULL,
    "barcode_legacy" character varying,
    CONSTRAINT "barcode_length" CHECK (("length"(("barcode")::"text") = 6))
);


ALTER TABLE "public"."spareparts" OWNER TO "postgres";


COMMENT ON COLUMN "public"."spareparts"."barcode_legacy" IS 'old system barcode, just for archive and research';



CREATE TABLE IF NOT EXISTS "public"."spareparts_files" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sparepart_reference_id" "uuid",
    "sparepart_request_id" "uuid",
    "file_url" "text" NOT NULL,
    "archived" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."spareparts_files" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."spareparts_stock" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sparepart_reference_id" "uuid" NOT NULL,
    "sub_area_storage_id" "uuid",
    "count" bigint
);


ALTER TABLE "public"."spareparts_stock" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sub_areas_storage" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "areas_storage_id" "uuid" NOT NULL,
    "name" character varying NOT NULL,
    "capacity" smallint,
    "display_order" smallint,
    "barcode" character varying
);


ALTER TABLE "public"."sub_areas_storage" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sub_areas_storage"."barcode" IS 'is unique for a given organization. Not the same twice for sp or device. But ok the same between 2 org';



CREATE TABLE IF NOT EXISTS "public"."suppliers" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "name" character varying NOT NULL,
    "group_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "salesman_lot" boolean DEFAULT true NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "archived" boolean DEFAULT false,
    "lot_naming" character varying,
    "preferred_pricing" character varying
);


ALTER TABLE "public"."suppliers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."suppliers"."owner_id" IS 'quelle org_user a ce supplier';



COMMENT ON COLUMN "public"."suppliers"."preferred_pricing" IS 'matrix,manual,service_provision';



CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "organization_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "name" character varying NOT NULL,
    "roles" "public"."user_roles"[],
    "deleted" boolean DEFAULT false NOT NULL,
    "replacer" "text",
    "notif_auth" boolean DEFAULT true,
    "hourly_cost" real
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users_holidays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "creator" "text",
    "user_id" "text",
    "date_start" "date",
    "date_end" "date",
    "archived" boolean DEFAULT false
);


ALTER TABLE "public"."users_holidays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users_invitations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp without time zone,
    "creator_id" "text",
    "organization_id" "uuid",
    "invited_email" "text" NOT NULL,
    "invited_name" "text" NOT NULL,
    "invited_roles" "text"[] NOT NULL
);


ALTER TABLE "public"."users_invitations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."youzd_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" character varying
);


ALTER TABLE "public"."youzd_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."youzd_subcategories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" character varying,
    "youzd_category_id" "uuid" DEFAULT "gen_random_uuid"()
);


ALTER TABLE "public"."youzd_subcategories" OWNER TO "postgres";


ALTER TABLE ONLY "public"."device_actions_aftersales"
    ADD CONSTRAINT "aftersales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."areas_categories"
    ADD CONSTRAINT "areas_categories_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."areas_categories"
    ADD CONSTRAINT "areas_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."areas_storage"
    ADD CONSTRAINT "areas_storage_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."brands"
    ADD CONSTRAINT "brands_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_budget"
    ADD CONSTRAINT "device_actions_budget_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions"
    ADD CONSTRAINT "device_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_reception"
    ADD CONSTRAINT "device_actions_reception_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_reparation_failures"
    ADD CONSTRAINT "device_actions_reparation_failures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_reparation_tests"
    ADD CONSTRAINT "device_actions_reparation_tests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_sales_lot"
    ADD CONSTRAINT "device_actions_sales_lot_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_ownership_transfer"
    ADD CONSTRAINT "device_ownership_transfer_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_service_categories"
    ADD CONSTRAINT "device_service_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."device_service_categories"
    ADD CONSTRAINT "device_service_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_service_sub_categories"
    ADD CONSTRAINT "device_service_sub_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."device_service_sub_categories"
    ADD CONSTRAINT "device_service_sub_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_services"
    ADD CONSTRAINT "device_services_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."device_services"
    ADD CONSTRAINT "device_services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_sub_services"
    ADD CONSTRAINT "device_sub_services_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."device_sub_services"
    ADD CONSTRAINT "device_sub_services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tests"
    ADD CONSTRAINT "device_tests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."devices_files"
    ADD CONSTRAINT "devices_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_references_actions"
    ADD CONSTRAINT "devices_references_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_references"
    ADD CONSTRAINT "devices_references_model_key" UNIQUE ("model");



ALTER TABLE ONLY "public"."device_references"
    ADD CONSTRAINT "devices_references_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_supplier_groups"
    ADD CONSTRAINT "groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_macro_failures"
    ADD CONSTRAINT "macro_failures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_micro_failures"
    ADD CONSTRAINT "micro_failures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organigram"
    ADD CONSTRAINT "organigramme_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_device_costs"
    ADD CONSTRAINT "organization_device_costs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_quality"
    ADD CONSTRAINT "quality_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_actions_reparations"
    ADD CONSTRAINT "reparations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sale_purchase_lot_devices"
    ADD CONSTRAINT "sale_purchase_lot_devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_invoice_import"
    ADD CONSTRAINT "sales_invoice_import_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_purchase_lot_actions"
    ADD CONSTRAINT "sales_purchase_lot_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_purchase_lots"
    ADD CONSTRAINT "sales_purchase_lots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_purchase_pricing_matrix"
    ADD CONSTRAINT "sales_purchase_pricing_matrix_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_actions"
    ADD CONSTRAINT "sparepart_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_categories"
    ADD CONSTRAINT "sparepart_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."sparepart_categories"
    ADD CONSTRAINT "sparepart_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_device_references"
    ADD CONSTRAINT "sparepart_device_references_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_reference_actions"
    ADD CONSTRAINT "sparepart_reference_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_references"
    ADD CONSTRAINT "sparepart_references_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_references"
    ADD CONSTRAINT "sparepart_references_serial_number_key" UNIQUE ("serial_number");



ALTER TABLE ONLY "public"."sparepart_requests_actions"
    ADD CONSTRAINT "sparepart_requests_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_requests_details"
    ADD CONSTRAINT "sparepart_requests_details_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_requests_issues"
    ADD CONSTRAINT "sparepart_requests_issues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_requests"
    ADD CONSTRAINT "sparepart_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_requests_sp_stock"
    ADD CONSTRAINT "sparepart_requests_sp_stock_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_sub_categories"
    ADD CONSTRAINT "sparepart_sub_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sparepart_service_sub_categories"
    ADD CONSTRAINT "sparepart_subcat_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."spareparts_files"
    ADD CONSTRAINT "spareparts_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."spareparts"
    ADD CONSTRAINT "spareparts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."spareparts_stock"
    ADD CONSTRAINT "spareparts_stock_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sub_areas_storage"
    ADD CONSTRAINT "sub_areas_storage_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users_holidays"
    ADD CONSTRAINT "users_holidays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."users_invitations"
    ADD CONSTRAINT "users_invitations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."youzd_categories"
    ADD CONSTRAINT "youzd_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."youzd_subcategories"
    ADD CONSTRAINT "youzd_subcategories_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_devices_model_organization" ON "public"."devices" USING "btree" ("device_reference_id", "archived");



CREATE OR REPLACE TRIGGER "on_update_sale_purchase_lot_devices" AFTER UPDATE ON "public"."sale_purchase_lot_devices" FOR EACH ROW EXECUTE FUNCTION "public"."on_update_sale_purchase_lot_devices"();



CREATE OR REPLACE TRIGGER "tr_update_device_actions_reception" AFTER UPDATE ON "public"."device_references" FOR EACH ROW EXECUTE FUNCTION "public"."update_device_actions_reception"();



ALTER TABLE ONLY "public"."device_actions_aftersales"
    ADD CONSTRAINT "aftersales_action_id_fkey" FOREIGN KEY ("action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."device_actions_aftersales"
    ADD CONSTRAINT "aftersales_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."areas_categories"
    ADD CONSTRAINT "areas_categories_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."areas_storage"
    ADD CONSTRAINT "areas_storage_area_category_id_fkey" FOREIGN KEY ("area_category_id") REFERENCES "public"."areas_categories"("id");



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id");



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."client_supplier_groups"
    ADD CONSTRAINT "client_supplier_groups_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."client_supplier_groups"("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."device_actions_budget"
    ADD CONSTRAINT "device_actions_budget_action_id_fkey" FOREIGN KEY ("action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."device_actions_budget"
    ADD CONSTRAINT "device_actions_budget_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions"
    ADD CONSTRAINT "device_actions_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions"
    ADD CONSTRAINT "device_actions_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."device_actions_reception"
    ADD CONSTRAINT "device_actions_reception_action_id_fkey" FOREIGN KEY ("action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."device_actions_reception"
    ADD CONSTRAINT "device_actions_reception_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions_reparation_failures"
    ADD CONSTRAINT "device_actions_reparation_failures_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions_reparation_failures"
    ADD CONSTRAINT "device_actions_reparation_failures_micro_failure_id_fkey" FOREIGN KEY ("micro_failure_id") REFERENCES "public"."device_micro_failures"("id");



ALTER TABLE ONLY "public"."device_actions_reparation_failures"
    ADD CONSTRAINT "device_actions_reparation_failures_reparation_id_fkey" FOREIGN KEY ("reparation_id") REFERENCES "public"."device_actions_reparations"("id");



ALTER TABLE ONLY "public"."device_actions_reparation_tests"
    ADD CONSTRAINT "device_actions_reparation_tests_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions_reparation_tests"
    ADD CONSTRAINT "device_actions_reparation_tests_reparation_id_fkey" FOREIGN KEY ("reparation_id") REFERENCES "public"."device_actions_reparations"("id");



ALTER TABLE ONLY "public"."device_actions_reparation_tests"
    ADD CONSTRAINT "device_actions_reparation_tests_test_id_fkey" FOREIGN KEY ("test_id") REFERENCES "public"."device_tests"("id");



ALTER TABLE ONLY "public"."device_actions_sales_lot"
    ADD CONSTRAINT "device_actions_sales_lot_action_id_fkey" FOREIGN KEY ("action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."device_actions_sales_lot"
    ADD CONSTRAINT "device_actions_sales_lot_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions_sales_lot"
    ADD CONSTRAINT "device_actions_sales_lot_sale_lot_id_fkey" FOREIGN KEY ("sale_lot_id") REFERENCES "public"."sales_purchase_lots"("id");



ALTER TABLE ONLY "public"."device_actions"
    ADD CONSTRAINT "device_actions_sub_area_storage_id_fkey" FOREIGN KEY ("sub_area_storage_id") REFERENCES "public"."sub_areas_storage"("id");



ALTER TABLE ONLY "public"."device_ownership_transfer"
    ADD CONSTRAINT "device_ownership_transfer_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."device_ownership_transfer"
    ADD CONSTRAINT "device_ownership_transfer_new_owner_fkey" FOREIGN KEY ("new_owner") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."device_ownership_transfer"
    ADD CONSTRAINT "device_ownership_transfer_old_owner_fkey" FOREIGN KEY ("old_owner") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."device_references"
    ADD CONSTRAINT "device_references_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "public"."brands"("id");



ALTER TABLE ONLY "public"."device_references"
    ADD CONSTRAINT "device_references_device_service_sub_category_id_fkey" FOREIGN KEY ("device_service_sub_category_id") REFERENCES "public"."device_service_sub_categories"("id");



ALTER TABLE ONLY "public"."device_service_categories"
    ADD CONSTRAINT "device_service_categories_device_sub_service_id_fkey" FOREIGN KEY ("device_sub_service_id") REFERENCES "public"."device_sub_services"("id");



ALTER TABLE ONLY "public"."device_service_sub_categories"
    ADD CONSTRAINT "device_service_sub_categories_device_service_category_id_fkey" FOREIGN KEY ("device_service_category_id") REFERENCES "public"."device_service_categories"("id");



ALTER TABLE ONLY "public"."device_service_sub_categories"
    ADD CONSTRAINT "device_service_sub_categories_youzd_subcategory_id_fkey" FOREIGN KEY ("youzd_subcategory_id") REFERENCES "public"."youzd_subcategories"("id");



ALTER TABLE ONLY "public"."device_sub_services"
    ADD CONSTRAINT "device_sub_services_device_service_id_fkey" FOREIGN KEY ("device_service_id") REFERENCES "public"."device_services"("id");



ALTER TABLE ONLY "public"."device_tests"
    ADD CONSTRAINT "device_tests_device_service_sub_category_id_fkey" FOREIGN KEY ("device_service_sub_category_id") REFERENCES "public"."device_service_sub_categories"("id");



ALTER TABLE ONLY "public"."device_tests"
    ADD CONSTRAINT "device_tests_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_device_reference_id_fkey" FOREIGN KEY ("device_reference_id") REFERENCES "public"."device_references"("id");



ALTER TABLE ONLY "public"."devices_files"
    ADD CONSTRAINT "devices_files_device_action_id_fkey" FOREIGN KEY ("device_action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."devices_files"
    ADD CONSTRAINT "devices_files_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."devices_files"
    ADD CONSTRAINT "devices_files_device_model_id_fkey" FOREIGN KEY ("device_model_id") REFERENCES "public"."device_references"("id");



ALTER TABLE ONLY "public"."device_references_actions"
    ADD CONSTRAINT "devices_references_actions_brand_fkey" FOREIGN KEY ("brand") REFERENCES "public"."brands"("id");



ALTER TABLE ONLY "public"."device_references_actions"
    ADD CONSTRAINT "devices_references_actions_device_reference_id_fkey" FOREIGN KEY ("device_reference_id") REFERENCES "public"."device_references"("id");



ALTER TABLE ONLY "public"."device_macro_failures"
    ADD CONSTRAINT "macro_failures_device_service_sub_category_id_fkey" FOREIGN KEY ("device_service_sub_category_id") REFERENCES "public"."device_service_sub_categories"("id");



ALTER TABLE ONLY "public"."device_macro_failures"
    ADD CONSTRAINT "macro_failures_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."device_micro_failures"
    ADD CONSTRAINT "micro_failures_macro_failure_id_fkey" FOREIGN KEY ("macro_failure_id") REFERENCES "public"."device_macro_failures"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_sender_fkey" FOREIGN KEY ("sender") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."organigram"
    ADD CONSTRAINT "organigramme_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."organigram"
    ADD CONSTRAINT "organigramme_employee_fkey" FOREIGN KEY ("employee") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."organigram"
    ADD CONSTRAINT "organigramme_manager_fkey" FOREIGN KEY ("manager") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."organization_device_costs"
    ADD CONSTRAINT "organization_device_costs_device_service_sub_category_id_fkey" FOREIGN KEY ("device_service_sub_category_id") REFERENCES "public"."device_service_sub_categories"("id");



ALTER TABLE ONLY "public"."organization_device_costs"
    ADD CONSTRAINT "organization_device_costs_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."device_actions_quality"
    ADD CONSTRAINT "quality_action_id_fkey" FOREIGN KEY ("action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."device_actions_quality"
    ADD CONSTRAINT "quality_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."device_actions_reparations"
    ADD CONSTRAINT "reparations_action_id_fkey" FOREIGN KEY ("action_id") REFERENCES "public"."device_actions"("id");



ALTER TABLE ONLY "public"."device_actions_reparations"
    ADD CONSTRAINT "reparations_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sale_purchase_lot_devices"
    ADD CONSTRAINT "sale_purchase_lot_devices_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sale_purchase_lot_devices"
    ADD CONSTRAINT "sale_purchase_lot_devices_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."sale_purchase_lot_devices"
    ADD CONSTRAINT "sale_purchase_lot_devices_sale_purchase_lot_id_fkey" FOREIGN KEY ("sale_purchase_lot_id") REFERENCES "public"."sales_purchase_lots"("id");



ALTER TABLE ONLY "public"."sales_invoice_import"
    ADD CONSTRAINT "sales_invoice_import_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."sales_purchase_lot_actions"
    ADD CONSTRAINT "sales_purchase_lot_actions_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sales_purchase_lots"
    ADD CONSTRAINT "sales_purchase_lots_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id");



ALTER TABLE ONLY "public"."sales_purchase_lots"
    ADD CONSTRAINT "sales_purchase_lots_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sales_purchase_lots"
    ADD CONSTRAINT "sales_purchase_lots_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."sales_purchase_pricing_matrix"
    ADD CONSTRAINT "sales_purchase_pricing_matrix_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id");



ALTER TABLE ONLY "public"."sales_purchase_pricing_matrix"
    ADD CONSTRAINT "sales_purchase_pricing_matrix_device_reference_sub_categor_fkey" FOREIGN KEY ("device_reference_sub_category_id") REFERENCES "public"."device_references"("id");



ALTER TABLE ONLY "public"."sales_purchase_pricing_matrix"
    ADD CONSTRAINT "sales_purchase_pricing_matrix_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id");



ALTER TABLE ONLY "public"."sparepart_actions"
    ADD CONSTRAINT "sparepart_actions_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_actions"
    ADD CONSTRAINT "sparepart_actions_origin_device_id_fkey" FOREIGN KEY ("origin_device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."sparepart_actions"
    ADD CONSTRAINT "sparepart_actions_sparepart_id_fkey" FOREIGN KEY ("sparepart_id") REFERENCES "public"."spareparts"("id");



ALTER TABLE ONLY "public"."sparepart_actions"
    ADD CONSTRAINT "sparepart_actions_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."sparepart_references"("id");



ALTER TABLE ONLY "public"."sparepart_actions"
    ADD CONSTRAINT "sparepart_actions_sub_area_storage_id_fkey" FOREIGN KEY ("sub_area_storage_id") REFERENCES "public"."sub_areas_storage"("id");



ALTER TABLE ONLY "public"."sparepart_device_references"
    ADD CONSTRAINT "sparepart_device_references_model_id_fkey" FOREIGN KEY ("model_id") REFERENCES "public"."device_references"("id");



ALTER TABLE ONLY "public"."sparepart_device_references"
    ADD CONSTRAINT "sparepart_device_references_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."sparepart_references"("id");



ALTER TABLE ONLY "public"."sparepart_reference_actions"
    ADD CONSTRAINT "sparepart_reference_actions_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_reference_actions"
    ADD CONSTRAINT "sparepart_reference_actions_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."sparepart_references"("id");



ALTER TABLE ONLY "public"."sparepart_references"
    ADD CONSTRAINT "sparepart_references_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_references"
    ADD CONSTRAINT "sparepart_references_sparepart_service_sub_category_id_fkey" FOREIGN KEY ("sparepart_service_sub_category_id") REFERENCES "public"."sparepart_service_sub_categories"("id");



ALTER TABLE ONLY "public"."sparepart_requests_actions"
    ADD CONSTRAINT "sparepart_requests_actions_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_requests_actions"
    ADD CONSTRAINT "sparepart_requests_actions_sparepart_request_id_fkey" FOREIGN KEY ("sparepart_request_id") REFERENCES "public"."sparepart_requests"("id");



ALTER TABLE ONLY "public"."sparepart_requests"
    ADD CONSTRAINT "sparepart_requests_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_requests_details"
    ADD CONSTRAINT "sparepart_requests_details_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_requests_details"
    ADD CONSTRAINT "sparepart_requests_details_sparepart_request_id_fkey" FOREIGN KEY ("sparepart_request_id") REFERENCES "public"."sparepart_requests"("id");



ALTER TABLE ONLY "public"."sparepart_requests_details"
    ADD CONSTRAINT "sparepart_requests_details_sparepart_request_id_fkey1" FOREIGN KEY ("sparepart_request_id") REFERENCES "public"."sparepart_requests"("id");



ALTER TABLE ONLY "public"."sparepart_requests"
    ADD CONSTRAINT "sparepart_requests_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id");



ALTER TABLE ONLY "public"."sparepart_requests_issues"
    ADD CONSTRAINT "sparepart_requests_issues_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_requests_issues"
    ADD CONSTRAINT "sparepart_requests_issues_last_editor_fkey" FOREIGN KEY ("last_editor") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_requests_issues"
    ADD CONSTRAINT "sparepart_requests_issues_sparepart_request_id_fkey" FOREIGN KEY ("sparepart_request_id") REFERENCES "public"."sparepart_requests"("id");



ALTER TABLE ONLY "public"."sparepart_requests_sp_stock"
    ADD CONSTRAINT "sparepart_requests_sp_stock_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sparepart_requests_sp_stock"
    ADD CONSTRAINT "sparepart_requests_sp_stock_sparepart_id_fkey" FOREIGN KEY ("sparepart_id") REFERENCES "public"."spareparts"("id");



ALTER TABLE ONLY "public"."sparepart_requests_sp_stock"
    ADD CONSTRAINT "sparepart_requests_sp_stock_sparepart_request_id_fkey" FOREIGN KEY ("sparepart_request_id") REFERENCES "public"."sparepart_requests"("id");



ALTER TABLE ONLY "public"."sparepart_requests"
    ADD CONSTRAINT "sparepart_requests_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."sparepart_references"("id");



ALTER TABLE ONLY "public"."sparepart_requests"
    ADD CONSTRAINT "sparepart_requests_sparepart_service_sub_category_id_fkey" FOREIGN KEY ("sparepart_service_sub_category_id") REFERENCES "public"."sparepart_service_sub_categories"("id");



ALTER TABLE ONLY "public"."sparepart_service_sub_categories"
    ADD CONSTRAINT "sparepart_service_sub_categor_device_service_sub_category__fkey" FOREIGN KEY ("device_service_sub_category_id") REFERENCES "public"."device_service_sub_categories"("id");



ALTER TABLE ONLY "public"."sparepart_sub_categories"
    ADD CONSTRAINT "sparepart_sub_categories_sparepart_category_id_fkey" FOREIGN KEY ("sparepart_category_id") REFERENCES "public"."sparepart_categories"("id");



ALTER TABLE ONLY "public"."sparepart_service_sub_categories"
    ADD CONSTRAINT "sparepart_subcat_sparepart_sub_category_id_fkey" FOREIGN KEY ("sparepart_sub_category_id") REFERENCES "public"."sparepart_sub_categories"("id");



ALTER TABLE ONLY "public"."spareparts"
    ADD CONSTRAINT "spareparts_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."spareparts_files"
    ADD CONSTRAINT "spareparts_files_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."spareparts"("id");



ALTER TABLE ONLY "public"."spareparts_files"
    ADD CONSTRAINT "spareparts_files_sparepart_request_id_fkey" FOREIGN KEY ("sparepart_request_id") REFERENCES "public"."sparepart_requests"("id");



ALTER TABLE ONLY "public"."spareparts"
    ADD CONSTRAINT "spareparts_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."sparepart_references"("id");



ALTER TABLE ONLY "public"."spareparts"
    ADD CONSTRAINT "spareparts_sparepart_service_sub_category_id_fkey" FOREIGN KEY ("sparepart_service_sub_category_id") REFERENCES "public"."sparepart_service_sub_categories"("id");



ALTER TABLE ONLY "public"."spareparts_stock"
    ADD CONSTRAINT "spareparts_stock_sparepart_reference_id_fkey" FOREIGN KEY ("sparepart_reference_id") REFERENCES "public"."spareparts"("id");



ALTER TABLE ONLY "public"."spareparts_stock"
    ADD CONSTRAINT "spareparts_stock_sub_area_storage_id_fkey" FOREIGN KEY ("sub_area_storage_id") REFERENCES "public"."sub_areas_storage"("id");



ALTER TABLE ONLY "public"."sub_areas_storage"
    ADD CONSTRAINT "sub_areas_storage_areas_storage_id_fkey" FOREIGN KEY ("areas_storage_id") REFERENCES "public"."areas_storage"("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."client_supplier_groups"("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."users_holidays"
    ADD CONSTRAINT "users_holidays_creator_fkey" FOREIGN KEY ("creator") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users_holidays"
    ADD CONSTRAINT "users_holidays_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users_invitations"
    ADD CONSTRAINT "users_invitations_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users_invitations"
    ADD CONSTRAINT "users_invitations_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_replacer_fkey" FOREIGN KEY ("replacer") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."youzd_subcategories"
    ADD CONSTRAINT "youzd_subcategories_youzd_category_id_fkey" FOREIGN KEY ("youzd_category_id") REFERENCES "public"."youzd_categories"("id");



CREATE POLICY "Enable insert for authenticated users only" ON "public"."users" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "all" ON "public"."areas_storage" USING (true);



CREATE POLICY "all" ON "public"."devices" USING (true);



CREATE POLICY "all" ON "public"."organizations" USING (true);



CREATE POLICY "all" ON "public"."sales_purchase_lots" USING (true);



CREATE POLICY "all" ON "public"."sub_areas_storage" USING (true);



ALTER TABLE "public"."areas_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."areas_storage" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."brands" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_contacts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_supplier_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_aftersales" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_budget" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_quality" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_reception" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_reparation_failures" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_reparation_tests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_reparations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_actions_sales_lot" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_macro_failures" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_micro_failures" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_ownership_transfer" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_references" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_references_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_service_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_service_sub_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_services" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_sub_services" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_tests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."devices_files" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organigram" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_device_costs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sale_purchase_lot_devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_invoice_import" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_purchase_lot_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_purchase_lots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_purchase_pricing_matrix" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_device_references" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_reference_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_references" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_requests_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_requests_details" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_requests_issues" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_requests_sp_stock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_service_sub_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sparepart_sub_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."spareparts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."spareparts_files" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."spareparts_stock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sub_areas_storage" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users_holidays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users_invitations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."youzd_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."youzd_subcategories" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."device_budget"("device_id_param" "uuid", "action_id_param" "uuid", "custom_price_param" real) TO "anon";
GRANT ALL ON FUNCTION "public"."device_budget"("device_id_param" "uuid", "action_id_param" "uuid", "custom_price_param" real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."device_budget"("device_id_param" "uuid", "action_id_param" "uuid", "custom_price_param" real) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_action_details"("action_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_action_details"("action_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_action_details"("action_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_area_occupation_rate"("org_id_param" "uuid", "area_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_area_occupation_rate"("org_id_param" "uuid", "area_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_area_occupation_rate"("org_id_param" "uuid", "area_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_areas_filter"("org_id_param" "uuid", "area_cat_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_areas_filter"("org_id_param" "uuid", "area_cat_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_areas_filter"("org_id_param" "uuid", "area_cat_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_brand_details"("model_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_brand_details"("model_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_brand_details"("model_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clients"("organization_id_param" "uuid", "offset_value" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_clients"("organization_id_param" "uuid", "offset_value" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clients"("organization_id_param" "uuid", "offset_value" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_actions"("param_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_actions"("param_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_actions"("param_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_areadata"("device_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_areadata"("device_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_areadata"("device_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_details"("id_param" "uuid", "barcode_param" "text", "organization_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_details"("id_param" "uuid", "barcode_param" "text", "organization_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_details"("id_param" "uuid", "barcode_param" "text", "organization_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_reference_details"("searchterm" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_reference_details"("searchterm" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_reference_details"("searchterm" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_references_raw"("searchterm" "text", "offset_param" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_references_raw"("searchterm" "text", "offset_param" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_references_raw"("searchterm" "text", "offset_param" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_reparation"("deviceid_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_reparation"("deviceid_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_reparation"("deviceid_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_device_sub_service"("subcat_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_device_sub_service"("subcat_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_device_sub_service"("subcat_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_devices_admin"("org_id_param" "uuid", "area_cat_id" "uuid", "area_id" "uuid", "subarea_id" "uuid", "repair_status_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_devices_admin"("org_id_param" "uuid", "area_cat_id" "uuid", "area_id" "uuid", "subarea_id" "uuid", "repair_status_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_devices_admin"("org_id_param" "uuid", "area_cat_id" "uuid", "area_id" "uuid", "subarea_id" "uuid", "repair_status_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_devices_barcode"("barcode_param" "text", "organization_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_devices_barcode"("barcode_param" "text", "organization_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_devices_barcode"("barcode_param" "text", "organization_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_devices_model"("model_param" "uuid", "organization_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_devices_model"("model_param" "uuid", "organization_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_devices_model"("model_param" "uuid", "organization_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_devices_salesearch"("brand_param" "text", "service_sub_category_param" "text", "offset_value" integer, "yearmin" integer, "yearmax" integer, "pricemin" double precision, "pricemax" double precision, "subservice_param" "text", "qualgrade_param" "text", "brandgrade_param" "text", "wholesale_param" boolean, "sort_field" "text", "sort_type" "text", "organization_id_param" "uuid", "barcode_param" "text", "status_param" "text"[], "purchase_lot_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_devices_salesearch"("brand_param" "text", "service_sub_category_param" "text", "offset_value" integer, "yearmin" integer, "yearmax" integer, "pricemin" double precision, "pricemax" double precision, "subservice_param" "text", "qualgrade_param" "text", "brandgrade_param" "text", "wholesale_param" boolean, "sort_field" "text", "sort_type" "text", "organization_id_param" "uuid", "barcode_param" "text", "status_param" "text"[], "purchase_lot_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_devices_salesearch"("brand_param" "text", "service_sub_category_param" "text", "offset_value" integer, "yearmin" integer, "yearmax" integer, "pricemin" double precision, "pricemax" double precision, "subservice_param" "text", "qualgrade_param" "text", "brandgrade_param" "text", "wholesale_param" boolean, "sort_field" "text", "sort_type" "text", "organization_id_param" "uuid", "barcode_param" "text", "status_param" "text"[], "purchase_lot_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_devices_search"("brand_param" "text", "service_sub_category_param" "text", "area_id" "uuid", "offset_value" integer, "sort_field" "text", "organization_id_param" "uuid", "archived_param" boolean, "barcode_param" "text", "status_param" "text", "subarea_id_param" "uuid", "model_param" "text", "purchase_lot_param" "text", "sale_lot_param" "text", "source_param" "text", "aftersales_status_param" "text", "repar_status_param" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_devices_search"("brand_param" "text", "service_sub_category_param" "text", "area_id" "uuid", "offset_value" integer, "sort_field" "text", "organization_id_param" "uuid", "archived_param" boolean, "barcode_param" "text", "status_param" "text", "subarea_id_param" "uuid", "model_param" "text", "purchase_lot_param" "text", "sale_lot_param" "text", "source_param" "text", "aftersales_status_param" "text", "repar_status_param" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_devices_search"("brand_param" "text", "service_sub_category_param" "text", "area_id" "uuid", "offset_value" integer, "sort_field" "text", "organization_id_param" "uuid", "archived_param" boolean, "barcode_param" "text", "status_param" "text", "subarea_id_param" "uuid", "model_param" "text", "purchase_lot_param" "text", "sale_lot_param" "text", "source_param" "text", "aftersales_status_param" "text", "repar_status_param" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_failures"("device_subcat_id" "uuid", "p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_failures"("device_subcat_id" "uuid", "p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_failures"("device_subcat_id" "uuid", "p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_notifs_count"("user_id_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_notifs_count"("user_id_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_notifs_count"("user_id_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_purchlot_devices"("salelot_id_param" "uuid", "files_param" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_purchlot_devices"("salelot_id_param" "uuid", "files_param" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_purchlot_devices"("salelot_id_param" "uuid", "files_param" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sale_purch_lots"("p_organization_id" "uuid", "type_lot" character varying, "hidden_param" boolean, "archived_param" boolean, "offset_param" bigint, "name_lot_param" "text", "supplier_name_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_sale_purch_lots"("p_organization_id" "uuid", "type_lot" character varying, "hidden_param" boolean, "archived_param" boolean, "offset_param" bigint, "name_lot_param" "text", "supplier_name_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sale_purch_lots"("p_organization_id" "uuid", "type_lot" character varying, "hidden_param" boolean, "archived_param" boolean, "offset_param" bigint, "name_lot_param" "text", "supplier_name_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_salelot_devices"("salelot_id_param" "uuid", "files_param" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_salelot_devices"("salelot_id_param" "uuid", "files_param" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_salelot_devices"("salelot_id_param" "uuid", "files_param" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_salelot_devices_other"("salelot_id_param" "uuid", "type_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_salelot_devices_other"("salelot_id_param" "uuid", "type_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_salelot_devices_other"("salelot_id_param" "uuid", "type_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_saleslots_raw"("org_id_param" "uuid", "client_name_param" "text", "status_param" "text", "device_barcode_param" "text", "offset_param" bigint, "spl_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_saleslots_raw"("org_id_param" "uuid", "client_name_param" "text", "status_param" "text", "device_barcode_param" "text", "offset_param" bigint, "spl_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_saleslots_raw"("org_id_param" "uuid", "client_name_param" "text", "status_param" "text", "device_barcode_param" "text", "offset_param" bigint, "spl_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sparepart_reference"("orgid_param" "uuid", "model_id_param" "uuid", "sp_subcat_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_sparepart_reference"("orgid_param" "uuid", "model_id_param" "uuid", "sp_subcat_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sparepart_reference"("orgid_param" "uuid", "model_id_param" "uuid", "sp_subcat_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_spareparts_barcode"("orgid_param" "uuid", "barcode_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_spareparts_barcode"("orgid_param" "uuid", "barcode_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spareparts_barcode"("orgid_param" "uuid", "barcode_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_spareparts_byserial"("ser_nb_param" "text", "org_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_spareparts_byserial"("ser_nb_param" "text", "org_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spareparts_byserial"("ser_nb_param" "text", "org_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_spareparts_deviceid"("deviceid_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_spareparts_deviceid"("deviceid_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spareparts_deviceid"("deviceid_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_spareparts_raw"("org_id_param" "uuid", "offset_param" bigint, "in_stock" boolean, "search_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_spareparts_raw"("org_id_param" "uuid", "offset_param" bigint, "in_stock" boolean, "search_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spareparts_raw"("org_id_param" "uuid", "offset_param" bigint, "in_stock" boolean, "search_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_spref_by_serial"("sn_param" "text", "offset_param" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_spref_by_serial"("sn_param" "text", "offset_param" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spref_by_serial"("sn_param" "text", "offset_param" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_spref_device_files"("spref_id_param" "uuid", "org_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_spref_device_files"("spref_id_param" "uuid", "org_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spref_device_files"("spref_id_param" "uuid", "org_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sprequest_details"("spreq_id_param" "uuid", "device_id_param" "uuid", "model_id_param" "uuid", "subcat_id_param" "uuid", "brand_id_param" "uuid", "spref_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_sprequest_details"("spreq_id_param" "uuid", "device_id_param" "uuid", "model_id_param" "uuid", "subcat_id_param" "uuid", "brand_id_param" "uuid", "spref_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sprequest_details"("spreq_id_param" "uuid", "device_id_param" "uuid", "model_id_param" "uuid", "subcat_id_param" "uuid", "brand_id_param" "uuid", "spref_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sprequests_raw"("deviceid_param" "uuid", "searchterm_param" "text", "status_param" "text", "creator_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_sprequests_raw"("deviceid_param" "uuid", "searchterm_param" "text", "status_param" "text", "creator_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sprequests_raw"("deviceid_param" "uuid", "searchterm_param" "text", "status_param" "text", "creator_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subarea_barcode"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subarea_barcode"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subarea_barcode"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subarea_barcode_available"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subarea_barcode_available"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subarea_barcode_available"("orgid_param" "uuid", "barcode_param" "text", "category_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subareas_filter"("area_id_param" "uuid", "offset_param" integer, "limit_param" integer, "availability_param" boolean, "area_cat_param" "text", "org_id_param" "uuid", "subarea_name_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subareas_filter"("area_id_param" "uuid", "offset_param" integer, "limit_param" integer, "availability_param" boolean, "area_cat_param" "text", "org_id_param" "uuid", "subarea_name_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subareas_filter"("area_id_param" "uuid", "offset_param" integer, "limit_param" integer, "availability_param" boolean, "area_cat_param" "text", "org_id_param" "uuid", "subarea_name_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subareas_generic"("organization_id_param" "uuid", "area_name_param" character varying, "area_type_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subareas_generic"("organization_id_param" "uuid", "area_name_param" character varying, "area_type_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subareas_generic"("organization_id_param" "uuid", "area_name_param" character varying, "area_type_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subcat_sp"("subcat_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subcat_sp"("subcat_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subcat_sp"("subcat_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_subcat_sp_spareka"("subcat_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_subcat_sp_spareka"("subcat_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_subcat_sp_spareka"("subcat_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_users_raw"("organization_id_param" "uuid", "deleted_param" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_users_raw"("organization_id_param" "uuid", "deleted_param" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_users_raw"("organization_id_param" "uuid", "deleted_param" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."on_update_device_actions"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_update_device_actions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_update_device_actions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."on_update_sale_purchase_lot_devices"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_update_sale_purchase_lot_devices"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_update_sale_purchase_lot_devices"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sp_schema_details"("sp_schema_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."sp_schema_details"("sp_schema_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sp_schema_details"("sp_schema_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_device_actions_reception"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_device_actions_reception"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_device_actions_reception"() TO "service_role";


















GRANT ALL ON TABLE "public"."areas_categories" TO "anon";
GRANT ALL ON TABLE "public"."areas_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."areas_categories" TO "service_role";



GRANT ALL ON TABLE "public"."areas_storage" TO "anon";
GRANT ALL ON TABLE "public"."areas_storage" TO "authenticated";
GRANT ALL ON TABLE "public"."areas_storage" TO "service_role";



GRANT ALL ON TABLE "public"."brands" TO "anon";
GRANT ALL ON TABLE "public"."brands" TO "authenticated";
GRANT ALL ON TABLE "public"."brands" TO "service_role";



GRANT ALL ON TABLE "public"."client_contacts" TO "anon";
GRANT ALL ON TABLE "public"."client_contacts" TO "authenticated";
GRANT ALL ON TABLE "public"."client_contacts" TO "service_role";



GRANT ALL ON SEQUENCE "public"."client_contacts_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."client_contacts_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."client_contacts_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."client_supplier_groups" TO "anon";
GRANT ALL ON TABLE "public"."client_supplier_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."client_supplier_groups" TO "service_role";



GRANT ALL ON TABLE "public"."clients" TO "anon";
GRANT ALL ON TABLE "public"."clients" TO "authenticated";
GRANT ALL ON TABLE "public"."clients" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions" TO "anon";
GRANT ALL ON TABLE "public"."device_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_aftersales" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_aftersales" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_aftersales" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_budget" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_budget" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_budget" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_quality" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_quality" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_quality" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_reception" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_reception" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_reception" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_reparation_failures" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_reparation_failures" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_reparation_failures" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_reparation_tests" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_reparation_tests" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_reparation_tests" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_reparations" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_reparations" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_reparations" TO "service_role";



GRANT ALL ON TABLE "public"."device_actions_sales_lot" TO "anon";
GRANT ALL ON TABLE "public"."device_actions_sales_lot" TO "authenticated";
GRANT ALL ON TABLE "public"."device_actions_sales_lot" TO "service_role";



GRANT ALL ON TABLE "public"."device_macro_failures" TO "anon";
GRANT ALL ON TABLE "public"."device_macro_failures" TO "authenticated";
GRANT ALL ON TABLE "public"."device_macro_failures" TO "service_role";



GRANT ALL ON TABLE "public"."device_micro_failures" TO "anon";
GRANT ALL ON TABLE "public"."device_micro_failures" TO "authenticated";
GRANT ALL ON TABLE "public"."device_micro_failures" TO "service_role";



GRANT ALL ON TABLE "public"."device_ownership_transfer" TO "anon";
GRANT ALL ON TABLE "public"."device_ownership_transfer" TO "authenticated";
GRANT ALL ON TABLE "public"."device_ownership_transfer" TO "service_role";



GRANT ALL ON TABLE "public"."device_references" TO "anon";
GRANT ALL ON TABLE "public"."device_references" TO "authenticated";
GRANT ALL ON TABLE "public"."device_references" TO "service_role";



GRANT ALL ON TABLE "public"."device_references_actions" TO "anon";
GRANT ALL ON TABLE "public"."device_references_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."device_references_actions" TO "service_role";



GRANT ALL ON TABLE "public"."device_service_categories" TO "anon";
GRANT ALL ON TABLE "public"."device_service_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."device_service_categories" TO "service_role";



GRANT ALL ON TABLE "public"."device_service_sub_categories" TO "anon";
GRANT ALL ON TABLE "public"."device_service_sub_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."device_service_sub_categories" TO "service_role";



GRANT ALL ON TABLE "public"."device_services" TO "anon";
GRANT ALL ON TABLE "public"."device_services" TO "authenticated";
GRANT ALL ON TABLE "public"."device_services" TO "service_role";



GRANT ALL ON TABLE "public"."device_sub_services" TO "anon";
GRANT ALL ON TABLE "public"."device_sub_services" TO "authenticated";
GRANT ALL ON TABLE "public"."device_sub_services" TO "service_role";



GRANT ALL ON TABLE "public"."device_tests" TO "anon";
GRANT ALL ON TABLE "public"."device_tests" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tests" TO "service_role";



GRANT ALL ON TABLE "public"."devices" TO "anon";
GRANT ALL ON TABLE "public"."devices" TO "authenticated";
GRANT ALL ON TABLE "public"."devices" TO "service_role";



GRANT ALL ON TABLE "public"."devices_files" TO "anon";
GRANT ALL ON TABLE "public"."devices_files" TO "authenticated";
GRANT ALL ON TABLE "public"."devices_files" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."organigram" TO "anon";
GRANT ALL ON TABLE "public"."organigram" TO "authenticated";
GRANT ALL ON TABLE "public"."organigram" TO "service_role";



GRANT ALL ON TABLE "public"."organization_device_costs" TO "anon";
GRANT ALL ON TABLE "public"."organization_device_costs" TO "authenticated";
GRANT ALL ON TABLE "public"."organization_device_costs" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."sale_purchase_lot_devices" TO "anon";
GRANT ALL ON TABLE "public"."sale_purchase_lot_devices" TO "authenticated";
GRANT ALL ON TABLE "public"."sale_purchase_lot_devices" TO "service_role";



GRANT ALL ON TABLE "public"."sales_invoice_import" TO "anon";
GRANT ALL ON TABLE "public"."sales_invoice_import" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_invoice_import" TO "service_role";



GRANT ALL ON TABLE "public"."sales_purchase_lot_actions" TO "anon";
GRANT ALL ON TABLE "public"."sales_purchase_lot_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_purchase_lot_actions" TO "service_role";



GRANT ALL ON TABLE "public"."sales_purchase_lots" TO "anon";
GRANT ALL ON TABLE "public"."sales_purchase_lots" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_purchase_lots" TO "service_role";



GRANT ALL ON TABLE "public"."sales_purchase_pricing_matrix" TO "anon";
GRANT ALL ON TABLE "public"."sales_purchase_pricing_matrix" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_purchase_pricing_matrix" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_actions" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_actions" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_categories" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_categories" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_device_references" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_device_references" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_device_references" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_reference_actions" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_reference_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_reference_actions" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_references" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_references" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_references" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_requests" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_requests" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_requests_actions" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_requests_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_requests_actions" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_requests_details" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_requests_details" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_requests_details" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_requests_issues" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_requests_issues" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_requests_issues" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_requests_sp_stock" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_requests_sp_stock" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_requests_sp_stock" TO "service_role";



GRANT ALL ON SEQUENCE "public"."sparepart_requests_sp_stock_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."sparepart_requests_sp_stock_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."sparepart_requests_sp_stock_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_service_sub_categories" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_service_sub_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_service_sub_categories" TO "service_role";



GRANT ALL ON TABLE "public"."sparepart_sub_categories" TO "anon";
GRANT ALL ON TABLE "public"."sparepart_sub_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."sparepart_sub_categories" TO "service_role";



GRANT ALL ON TABLE "public"."spareparts" TO "anon";
GRANT ALL ON TABLE "public"."spareparts" TO "authenticated";
GRANT ALL ON TABLE "public"."spareparts" TO "service_role";



GRANT ALL ON TABLE "public"."spareparts_files" TO "anon";
GRANT ALL ON TABLE "public"."spareparts_files" TO "authenticated";
GRANT ALL ON TABLE "public"."spareparts_files" TO "service_role";



GRANT ALL ON TABLE "public"."spareparts_stock" TO "anon";
GRANT ALL ON TABLE "public"."spareparts_stock" TO "authenticated";
GRANT ALL ON TABLE "public"."spareparts_stock" TO "service_role";



GRANT ALL ON TABLE "public"."sub_areas_storage" TO "anon";
GRANT ALL ON TABLE "public"."sub_areas_storage" TO "authenticated";
GRANT ALL ON TABLE "public"."sub_areas_storage" TO "service_role";



GRANT ALL ON TABLE "public"."suppliers" TO "anon";
GRANT ALL ON TABLE "public"."suppliers" TO "authenticated";
GRANT ALL ON TABLE "public"."suppliers" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."users_holidays" TO "anon";
GRANT ALL ON TABLE "public"."users_holidays" TO "authenticated";
GRANT ALL ON TABLE "public"."users_holidays" TO "service_role";



GRANT ALL ON TABLE "public"."users_invitations" TO "anon";
GRANT ALL ON TABLE "public"."users_invitations" TO "authenticated";
GRANT ALL ON TABLE "public"."users_invitations" TO "service_role";



GRANT ALL ON TABLE "public"."youzd_categories" TO "anon";
GRANT ALL ON TABLE "public"."youzd_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."youzd_categories" TO "service_role";



GRANT ALL ON TABLE "public"."youzd_subcategories" TO "anon";
GRANT ALL ON TABLE "public"."youzd_subcategories" TO "authenticated";
GRANT ALL ON TABLE "public"."youzd_subcategories" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
