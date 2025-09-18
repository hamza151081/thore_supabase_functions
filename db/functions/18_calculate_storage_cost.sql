-- ================================================================
-- STORAGE COST CALCULATION
-- Requirement: "Cout_stockage" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_storage_cost(
    p_device_id UUID,
    p_is_estimate BOOLEAN DEFAULT TRUE
)
RETURNS NUMERIC AS $$
DECLARE
    v_storage_cost NUMERIC;
    v_reception_date DATE;
    v_days_stored INTEGER;
    v_avg_days INTEGER;
    v_subcat_id UUID;
    v_organization_id UUID;
    v_daily_cost NUMERIC := 0.35;
BEGIN
    -- Get device subcategory and organization
    SELECT dr.device_service_sub_category_id, u.organization_id
    INTO v_subcat_id, v_organization_id
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    JOIN device_actions da ON da.device_id = d.id
    JOIN users u ON u.id = da.creator
    WHERE d.id = p_device_id
    LIMIT 1;
    
    IF p_is_estimate THEN
        -- Average storage cost
        SELECT AVG(
            CASE 
                WHEN da_sold.created_at IS NOT NULL THEN 
                    EXTRACT(DAY FROM da_sold.created_at - da_rec.created_at)
                WHEN da_deee.created_at IS NOT NULL THEN
                    EXTRACT(DAY FROM da_deee.created_at - da_rec.created_at)
                ELSE 0
            END
        )
        INTO v_avg_days
        FROM devices d
        JOIN device_references dr ON dr.id = d.device_reference_id
        JOIN device_actions da_rec ON da_rec.device_id = d.id AND da_rec.type = 'Réception'
        LEFT JOIN device_actions da_sold ON da_sold.device_id = d.id AND da_sold.status = 'Vendu'
        LEFT JOIN device_actions da_deee ON da_deee.device_id = d.id AND da_deee.status = 'Démontage terminé'
        WHERE dr.device_service_sub_category_id = v_subcat_id
        AND da_rec.creator IN (SELECT id FROM users WHERE organization_id = v_organization_id)
        AND da_rec.created_at >= CURRENT_DATE - INTERVAL '180 days'
        AND EXTRACT(DOW FROM da_rec.created_at) NOT IN (0, 6);
        
        v_storage_cost := COALESCE(v_avg_days, 30) * v_daily_cost;
    ELSE
        -- Actual storage cost
        SELECT da.created_at::DATE
        INTO v_reception_date
        FROM device_actions da
        WHERE da.device_id = p_device_id
        AND da.type = 'Réception'
        ORDER BY da.created_at ASC
        LIMIT 1;
        
        v_days_stored := CURRENT_DATE - v_reception_date;
        v_storage_cost := v_days_stored * v_daily_cost;
        
        -- Get average for comparison
        SELECT AVG(
            CASE 
                WHEN da_sold.created_at IS NOT NULL THEN 
                    EXTRACT(DAY FROM da_sold.created_at - da_rec.created_at)
                WHEN da_deee.created_at IS NOT NULL THEN
                    EXTRACT(DAY FROM da_deee.created_at - da_rec.created_at)
                ELSE 0
            END
        ) * v_daily_cost
        INTO v_avg_days
        FROM devices d
        JOIN device_references dr ON dr.id = d.device_reference_id
        JOIN device_actions da_rec ON da_rec.device_id = d.id AND da_rec.type = 'Réception'
        LEFT JOIN device_actions da_sold ON da_sold.device_id = d.id AND da_sold.status = 'Vendu'
        LEFT JOIN device_actions da_deee ON da_deee.device_id = d.id AND da_deee.status = 'Démontage terminé'
        WHERE dr.device_service_sub_category_id = v_subcat_id
        AND da_rec.creator IN (SELECT id FROM users WHERE organization_id = v_organization_id)
        AND da_rec.created_at >= CURRENT_DATE - INTERVAL '180 days';
        
        v_storage_cost := GREATEST(v_storage_cost, COALESCE(v_avg_days, v_storage_cost));
    END IF;
    
    RETURN COALESCE(v_storage_cost, 0);
END;
$$ LANGUAGE plpgsql;