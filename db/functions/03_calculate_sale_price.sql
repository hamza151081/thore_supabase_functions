CREATE OR REPLACE FUNCTION calculate_sale_price(
    p_device_id UUID,
    p_organization_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_sale_price NUMERIC;
    v_price_new NUMERIC;
    v_device_ref_id UUID;
    v_reception_grade VARCHAR;
    v_quality_grade VARCHAR;
    v_brand_grade VARCHAR;
    v_device_year INTEGER;
    v_current_year INTEGER;
    v_count INTEGER;
    v_min_percent NUMERIC;
    v_avg_percent NUMERIC;
BEGIN
    -- Get device reference and price_new
    SELECT dr.id, dr.price_new, b.grade, dr.year_production
    INTO v_device_ref_id, v_price_new, v_brand_grade, v_device_year
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    LEFT JOIN brands b ON b.id = dr.brand_id
    WHERE d.id = p_device_id;
    
    -- Get current device reception grade
    SELECT dar.grade
    INTO v_reception_grade
    FROM device_actions da
    JOIN device_actions_reception dar ON dar.action_id = da.id
    WHERE da.device_id = p_device_id
    AND da.type = 'Réception'
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    -- Get current device quality grade (most recent)
    SELECT daq.grade
    INTO v_quality_grade
    FROM device_actions da
    JOIN device_actions_quality daq ON daq.action_id = da.id
    WHERE da.device_id = p_device_id
    AND da.type = 'Qualité'
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    -- Current year for age calculation
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    
    -- Option 1: 30+ devices with same model and reception grade
    WITH sold_devices AS (
        SELECT d.id, sii.percent_new_price,
               -- Get quality grade for each device
               (SELECT daq.grade 
                FROM device_actions da2 
                JOIN device_actions_quality daq ON daq.action_id = da2.id
                WHERE da2.device_id = d.id 
                AND da2.type = 'Qualité'
                ORDER BY da2.created_at DESC 
                LIMIT 1) as device_quality_grade
        FROM devices d
        JOIN sales_invoice_import sii ON sii.device_id = d.id
        JOIN device_actions da ON da.device_id = d.id
        JOIN users u ON u.id = da.creator
        WHERE d.device_reference_id = v_device_ref_id
        AND da.status = 'Vendu'
        AND u.organization_id = p_organization_id
        AND sii.percent_new_price >= 0.25
    )
    SELECT COUNT(*), MIN(percent_new_price)
    INTO v_count, v_min_percent
    FROM sold_devices
    WHERE device_quality_grade = v_reception_grade;
    
    IF v_count >= 30 AND v_min_percent IS NOT NULL THEN
        v_sale_price := v_price_new * v_min_percent;
        RETURN v_sale_price;
    END IF;
    
    -- Option 2: 30+ devices with same brand and quality grade (last 6 months)
    WITH sold_devices_brand AS (
        SELECT d.id, sii.percent_new_price,
               -- Get quality grade for each device
               (SELECT daq.grade 
                FROM device_actions da2 
                JOIN device_actions_quality daq ON daq.action_id = da2.id
                WHERE da2.device_id = d.id 
                AND da2.type = 'Qualité'
                ORDER BY da2.created_at DESC 
                LIMIT 1) as device_quality_grade
        FROM devices d
        JOIN device_references dr ON dr.id = d.device_reference_id
        JOIN brands b ON b.id = dr.brand_id
        JOIN sales_invoice_import sii ON sii.device_id = d.id
        JOIN device_actions da ON da.device_id = d.id
        JOIN users u ON u.id = da.creator
        WHERE b.grade = v_brand_grade
        AND da.status = 'Vendu'
        AND u.organization_id = p_organization_id
        AND sii.percent_new_price >= 0.25
        AND sii.created_at >= CURRENT_DATE - INTERVAL '6 months'
    )
    SELECT COUNT(*), AVG(percent_new_price)
    INTO v_count, v_avg_percent
    FROM sold_devices_brand
    WHERE device_quality_grade = v_quality_grade;
    
    IF v_count >= 30 AND v_avg_percent IS NOT NULL THEN
        v_sale_price := v_price_new * v_avg_percent;
        RETURN v_sale_price;
    END IF;
    
    -- Option 3: Use pricing matrix
    SELECT v_price_new * sppm.const_percent
    INTO v_sale_price
    FROM sales_purchase_pricing_matrix sppm
    JOIN clients c ON c.id = sppm.client_id
    WHERE sppm.supplier_id = p_organization_id
    AND c.name = 'Generic_reception'
    AND c.owner_id = p_organization_id
    AND sppm.internal_grade = COALESCE(v_quality_grade, v_reception_grade)
    AND sppm.brand_grade = v_brand_grade;
    -- Note: Age criteria might need to be added to sales_purchase_pricing_matrix table
    -- Currently not implemented as it's not in the schema
    
    IF v_sale_price IS NOT NULL THEN
        RETURN v_sale_price;
    END IF;
    
    -- Default fallback - return 0 if no calculation possible
    RETURN 0;
END;
$$ LANGUAGE plpgsql;
