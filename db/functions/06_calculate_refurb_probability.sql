CREATE OR REPLACE FUNCTION calculate_refurb_probability(
    p_device_id UUID
)
RETURNS NUMERIC AS $
DECLARE
    v_probability NUMERIC;
    v_brand_id UUID;
    v_subcat_id UUID;
    v_refurb_count INTEGER;
    v_deee_count INTEGER;
    v_total_count INTEGER;
BEGIN
    -- Get device brand and subcategory
    SELECT dr.brand_id, dr.device_service_sub_category_id
    INTO v_brand_id, v_subcat_id
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    WHERE d.id = p_device_id;
    
    -- Try brand + subcategory first (30+ devices needed)
    SELECT 
        COUNT(CASE WHEN dar_term.id IS NOT NULL THEN 1 END) as refurb,
        COUNT(CASE WHEN da_last.status = 'Démontage terminé' THEN 1 END) as deee
    INTO v_refurb_count, v_deee_count
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    LEFT JOIN LATERAL (
        SELECT dar.id
        FROM device_actions da
        JOIN device_actions_reparations dar ON dar.action_id = da.id
        WHERE da.device_id = d.id
        AND dar.status = 'Terminé'
        LIMIT 1
    ) dar_term ON true
    LEFT JOIN LATERAL (
        SELECT da.status
        FROM device_actions da
        WHERE da.device_id = d.id
        ORDER BY da.created_at DESC
        LIMIT 1
    ) da_last ON true
    WHERE dr.brand_id = v_brand_id
    AND dr.device_service_sub_category_id = v_subcat_id;
    
    v_total_count := v_refurb_count + v_deee_count;
    
    IF v_total_count >= 30 THEN
        v_probability := v_refurb_count::NUMERIC / NULLIF(v_total_count, 0);
        RETURN COALESCE(v_probability, 0.5);
    END IF;
    
    -- Fallback to subcategory only
    SELECT 
        COUNT(CASE WHEN dar_term.id IS NOT NULL THEN 1 END) as refurb,
        COUNT(CASE WHEN da_last.status = 'Démontage terminé' THEN 1 END) as deee
    INTO v_refurb_count, v_deee_count
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    LEFT JOIN LATERAL (
        SELECT dar.id
        FROM device_actions da
        JOIN device_actions_reparations dar ON dar.action_id = da.id
        WHERE da.device_id = d.id
        AND dar.status = 'Terminé'
        LIMIT 1
    ) dar_term ON true
    LEFT JOIN LATERAL (
        SELECT da.status
        FROM device_actions da
        WHERE da.device_id = d.id
        ORDER BY da.created_at DESC
        LIMIT 1
    ) da_last ON true
    WHERE dr.device_service_sub_category_id = v_subcat_id;
    
    v_total_count := v_refurb_count + v_deee_count;
    
    IF v_total_count > 0 THEN
        v_probability := v_refurb_count::NUMERIC / v_total_count;
        RETURN COALESCE(v_probability, 0.5);
    END IF;
    
    RETURN 0.5; -- Default 50% if no data
END;
$ LANGUAGE plpgsql;