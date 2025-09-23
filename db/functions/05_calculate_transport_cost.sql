CREATE OR REPLACE FUNCTION calculate_transport_cost(
    p_device_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_transport_cost NUMERIC;
    v_pricing_mode VARCHAR;
    v_pricing_value NUMERIC;
    v_device_count INTEGER;
    v_lot_id UUID;
    v_supplier_id UUID;
    v_reception_grade VARCHAR;
    v_brand_grade VARCHAR;
    v_device_owner_org UUID;
BEGIN
    -- Get purchase lot transport information
    SELECT spl.transport_pricing_mode, spl.transport_pricing_value, spl.id, spl.supplier_id
    INTO v_pricing_mode, v_pricing_value, v_lot_id, v_supplier_id
    FROM sale_purchase_lot_devices spld
    JOIN sales_purchase_lots spl ON spl.id = spld.sale_purchase_lot_id
    WHERE spld.device_id = p_device_id
    AND spld.archived = false
    ORDER BY spld.created_at DESC
    LIMIT 1;
    
    -- Get device owner organization
    SELECT u.organization_id
    INTO v_device_owner_org
    FROM device_actions da
    JOIN users u ON u.id = da.creator
    WHERE da.device_id = p_device_id
    LIMIT 1;
    
    -- Get reception grade and brand grade
    SELECT dar.grade, b.grade
    INTO v_reception_grade, v_brand_grade
    FROM device_actions da
    JOIN device_actions_reception dar ON dar.action_id = da.id
    JOIN devices d ON d.id = da.device_id
    JOIN device_references dr ON dr.id = d.device_reference_id
    LEFT JOIN brands b ON b.id = dr.brand_id
    WHERE da.device_id = p_device_id
    AND da.type = 'Réception'
    ORDER BY da.created_at DESC
    LIMIT 1;
    
    -- Calculate based on transport pricing mode
    CASE v_pricing_mode
        WHEN 'fixed' THEN
            -- Fixed transport cost per device
            v_transport_cost := v_pricing_value;
            
        WHEN 'shared' THEN
            -- Shared transport cost divided by number of devices in lot
            SELECT COUNT(*)
            INTO v_device_count
            FROM sale_purchase_lot_devices
            WHERE sale_purchase_lot_id = v_lot_id
            AND archived = false;
            
            v_transport_cost := v_pricing_value / NULLIF(v_device_count, 0);
            
        WHEN 'matrix' THEN
            -- Matrix pricing using transport_price
            SELECT sppm.transport_price
            INTO v_transport_cost
            FROM sales_purchase_pricing_matrix sppm
            WHERE sppm.supplier_id = v_supplier_id
            AND sppm.client_id = v_device_owner_org
            AND sppm.internal_grade = v_reception_grade
            AND sppm.brand_grade = v_brand_grade;
            
        ELSE
            v_transport_cost := 0;
    END CASE;
    
    RETURN COALESCE(v_transport_cost, 0);
END;
$$ LANGUAGE plpgsql;