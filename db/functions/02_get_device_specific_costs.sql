CREATE OR REPLACE FUNCTION get_device_specific_costs(
    p_device_id UUID,
    p_organization_id UUID
)
RETURNS JSONB AS $
DECLARE
    v_costs JSONB;
    v_subcat_id UUID;
    v_cleaning_cost NUMERIC;
    v_pallet_cost NUMERIC;
    v_film_cost NUMERIC;
BEGIN
    -- Get device service subcategory
    SELECT dr.device_service_sub_category_id
    INTO v_subcat_id
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    WHERE d.id = p_device_id;
    
    -- Get device-specific costs from organization_device_costs
    -- Using same logic as original functions: exact lookup, return 0 if not found
    SELECT 
        COALESCE(cleaning.value, 0) as cleaning,
        COALESCE(pallet.value, 0) as pallet,
        COALESCE(film.value, 0) as film
    INTO v_cleaning_cost, v_pallet_cost, v_film_cost
    FROM (SELECT 1) dummy -- Dummy table for cross join
    LEFT JOIN organization_device_costs cleaning ON (
        cleaning.device_service_sub_category_id = v_subcat_id
        AND cleaning.cost = 'cleaning'
        AND cleaning.organization_id = p_organization_id
    )
    LEFT JOIN organization_device_costs pallet ON (
        pallet.device_service_sub_category_id = v_subcat_id
        AND pallet.cost = 'pallet'
        AND pallet.organization_id = p_organization_id
    )
    LEFT JOIN organization_device_costs film ON (
        film.device_service_sub_category_id = v_subcat_id
        AND film.cost = 'film'
        AND film.organization_id = p_organization_id
    );
    
    -- Build result JSON - simple lookup, no complex logic
    v_costs := jsonb_build_object(
        'cleaning_cost', v_cleaning_cost,
        'pallet_cost', v_pallet_cost,
        'film_cost', v_film_cost,
        'subcategory_id', v_subcat_id
    );
    
    RETURN v_costs;
END;
$ LANGUAGE plpgsql;