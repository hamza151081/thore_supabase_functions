-- ================================================================
-- STORAGE COST CALCULATION FUNCTION
-- Requirement: "Cout_stockage" section
-- Documentation: Estimated vs Real storage cost based on stage
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_storage_cost(
    p_device_id UUID,
    p_organization_id UUID,
    p_subcat_id UUID,
    p_stage VARCHAR -- 'pre_test' or 'real'
)
RETURNS NUMERIC AS $
DECLARE
    v_storage_cost_estimated NUMERIC;
    v_storage_cost_real NUMERIC;
    v_const_cost_storage NUMERIC;
    v_reception_date TIMESTAMP;
    v_days_stored NUMERIC;
BEGIN
    -- Get storage cost constant from organizations (daily rate)
    SELECT const_cost_storage
    INTO v_const_cost_storage
    FROM organizations
    WHERE id = p_organization_id;
    
    -- Calculate estimated storage cost
    SELECT AVG(storage_days) * v_const_cost_storage
        INTO v_storage_cost_estimated
        FROM (
            SELECT 
                EXTRACT(DAY FROM 
                    CASE 
                        WHEN da_sold.created_at IS NOT NULL THEN da_sold.created_at
                        WHEN da_deee.created_at IS NOT NULL THEN da_deee.created_at
                        ELSE CURRENT_TIMESTAMP
                    END - da_rec.created_at
                ) as storage_days
            FROM devices d
            JOIN device_references dr ON dr.id = d.device_reference_id
            JOIN device_actions da_rec ON da_rec.device_id = d.id AND da_rec.type = 'Réception'
            JOIN users u ON u.id = da_rec.creator
            LEFT JOIN device_actions da_sold ON da_sold.device_id = d.id AND da_sold.status = 'Vendu'
            LEFT JOIN device_actions da_deee ON da_deee.device_id = d.id AND da_deee.status = 'Démontage terminé'
            WHERE dr.device_service_sub_category_id = p_subcat_id
            AND u.organization_id = p_organization_id
            AND da_rec.created_at >= CURRENT_DATE - INTERVAL '180 days'
            AND EXTRACT(DOW FROM da_rec.created_at) BETWEEN 1 AND 5 -- Working days only
            AND (da_sold.created_at IS NOT NULL OR da_deee.created_at IS NOT NULL)
        ) avg_storage;


    IF p_stage = 'pre_test' THEN
        -- Cout_stockage estimé
        -- Average over last 180 working days for same subcategory and organization
        
        RETURN COALESCE(v_storage_cost_estimated, 0);
        
    ELSE -- p_stage = 'real'
        -- Cout_stockage réel
        -- Get reception date
        SELECT da.created_at
        INTO v_reception_date
        FROM device_actions da
        WHERE da.device_id = p_device_id
        AND da.type = 'Réception'
        ORDER BY da.created_at ASC
        LIMIT 1;
        
        -- Calculate days from reception to now
        v_days_stored := EXTRACT(DAY FROM CURRENT_TIMESTAMP - v_reception_date);
        
        -- Calculate real storage cost
        v_storage_cost_real := v_days_stored * v_const_cost_storage;
        
        -- Compare with estimated average and use the higher value
        -- "si le réel dépasse la moyenne, alors appliquer réel"
        
        -- Use real if it exceeds average, otherwise use average
        IF v_storage_cost_real > COALESCE(v_storage_cost_estimated, 0) THEN
            RETURN v_storage_cost_real;
        ELSE
            RETURN COALESCE(v_storage_cost_estimated, v_storage_cost_real);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;