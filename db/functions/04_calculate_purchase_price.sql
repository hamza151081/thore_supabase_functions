CREATE OR REPLACE FUNCTION calculate_purchase_price(
    p_device_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_purchase_price NUMERIC;
    v_pricing_mode VARCHAR;
    v_pricing_value NUMERIC;
    v_supplier_id UUID;
    v_reception_grade VARCHAR;
    v_brand_grade VARCHAR;
    v_price_new NUMERIC;
    v_device_owner_org UUID;
    v_const_price NUMERIC;
    v_const_percent NUMERIC;
BEGIN
    -- Priority 1: Check for custom purchase price first (highest priority)
    SELECT purchase_price_custom
    INTO v_purchase_price
    FROM device_actions_budget dab
    JOIN device_actions da ON da.id = dab.action_id
    WHERE da.device_id = p_device_id
    AND dab.purchase_price_custom IS NOT NULL
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    IF v_purchase_price IS NOT NULL THEN
        RETURN v_purchase_price;
    END IF;
    
    -- Get purchase lot information
    SELECT spl.device_pricing_mode, spl.device_pricing_value, spl.supplier_id
    INTO v_pricing_mode, v_pricing_value, v_supplier_id
    FROM sale_purchase_lot_devices spld
    JOIN sales_purchase_lots spl ON spl.id = spld.sale_purchase_lot_id
    WHERE spld.device_id = p_device_id
    AND spld.archived = false
    ORDER BY spld.created_at DESC
    LIMIT 1;
    
    -- Get device reference price and brand
    SELECT dr.price_new, b.grade
    INTO v_price_new, v_brand_grade
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    LEFT JOIN brands b ON b.id = dr.brand_id
    WHERE d.id = p_device_id;
    
    -- Get device owner organization
    SELECT u.organization_id
    INTO v_device_owner_org
    FROM device_actions da
    JOIN users u ON u.id = da.creator
    WHERE da.device_id = p_device_id
    LIMIT 1;
    
    -- Get reception grade
    SELECT dar.grade
    INTO v_reception_grade
    FROM device_actions da
    JOIN device_actions_reception dar ON dar.action_id = da.id
    WHERE da.device_id = p_device_id
    AND da.type = 'Réception'
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    -- Calculate based on pricing mode (priority order 2-5)
    CASE v_pricing_mode
        WHEN 'matrix' THEN
            -- Priority 2: Matrix pricing
            SELECT sppm.const_price, sppm.const_percent
            INTO v_const_price, v_const_percent
            FROM sales_purchase_pricing_matrix sppm
            WHERE sppm.supplier_id = v_supplier_id
            AND sppm.client_id = v_device_owner_org
            AND sppm.internal_grade = v_reception_grade
            AND sppm.brand_grade = v_brand_grade;
            
            -- If const_price is not null, use it; otherwise use const_percent
            IF v_const_price IS NOT NULL THEN
                v_purchase_price := v_const_price;
            ELSIF v_const_percent IS NOT NULL THEN
                v_purchase_price := v_const_percent * v_price_new;
            END IF;
            
        WHEN 'fixed_price' THEN
            -- Priority 3: Fixed price
            v_purchase_price := v_pricing_value;
            
        WHEN 'fixed_percent' THEN
            -- Priority 4: Fixed percent
            v_purchase_price := v_pricing_value * v_price_new;
            
        WHEN 'service' THEN
            -- Priority 5: Service (zero cost)
            v_purchase_price := 0;
            
        ELSE
            v_purchase_price := 0;
    END CASE;
    
    RETURN COALESCE(v_purchase_price, 0);
END;
$$ LANGUAGE plpgsql;