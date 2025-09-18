-- ================================================================
-- SALE PRICE CALCULATION
-- Requirement: "Calcul de la valeur de vente potentielle du produit [Prix de vente estimé]"
-- ================================================================
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
    v_count INTEGER;
BEGIN
    -- Get device reference and price_new
    SELECT dr.id, dr.price_new, b.grade
    INTO v_device_ref_id, v_price_new, v_brand_grade
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    LEFT JOIN brands b ON b.id = dr.brand_id
    WHERE d.id = p_device_id;
    
    -- Get reception grade
    SELECT dar.grade
    INTO v_reception_grade
    FROM device_actions da
    JOIN device_actions_reception dar ON dar.action_id = da.id
    WHERE da.device_id = p_device_id
    AND da.type = 'Réception'
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    -- Get quality grade
    SELECT daq.grade
    INTO v_quality_grade
    FROM device_actions da
    JOIN device_actions_quality daq ON daq.action_id = da.id
    WHERE da.device_id = p_device_id
    AND da.type = 'Qualité'
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    -- Option 1: 30+ devices with same model and quality grade
    SELECT COUNT(*), MIN(sii.sale_price)
    INTO v_count, v_sale_price
    FROM devices d
    JOIN sales_invoice_import sii ON sii.device_id = d.id
    JOIN device_actions da ON da.device_id = d.id
    JOIN device_actions_quality daq ON daq.action_id = da.id
    WHERE d.device_reference_id = v_device_ref_id
    AND daq.grade = COALESCE(v_quality_grade, v_reception_grade)
    AND da.status = 'Vendu'
    AND da.creator IN (SELECT id FROM users WHERE organization_id = p_organization_id);
    
    IF v_count >= 30 AND v_sale_price IS NOT NULL THEN
        RETURN GREATEST(v_sale_price, v_price_new * 0.2);
    END IF;
    
    -- Option 2: 30+ devices with same brand and quality grade
    SELECT COUNT(*), AVG(sii.percent_new_price)
    INTO v_count, v_sale_price
    FROM devices d
    JOIN device_references dr2 ON dr2.id = d.device_reference_id
    JOIN brands b ON b.id = dr2.brand_id
    JOIN sales_invoice_import sii ON sii.device_id = d.id
    JOIN device_actions da ON da.device_id = d.id
    JOIN device_actions_quality daq ON daq.action_id = da.id
    WHERE b.grade = v_brand_grade
    AND daq.grade = COALESCE(v_quality_grade, v_reception_grade)
    AND da.status = 'Vendu'
    AND da.creator IN (SELECT id FROM users WHERE organization_id = p_organization_id);
    
    IF v_count >= 30 AND v_sale_price IS NOT NULL THEN
        v_sale_price := v_price_new * v_sale_price;
        RETURN GREATEST(v_sale_price, v_price_new * 0.2);
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
    
    IF v_sale_price IS NOT NULL THEN
        RETURN GREATEST(v_sale_price, v_price_new * 0.2);
    END IF;
    
    -- Default fallback
    RETURN v_price_new * 0.2;
END;
$$ LANGUAGE plpgsql;