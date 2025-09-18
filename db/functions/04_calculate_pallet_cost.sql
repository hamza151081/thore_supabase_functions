-- ================================================================
-- PALLET COST CALCULATION
-- Requirement: "Cout_palette" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_pallet_cost(
    p_device_id UUID,
    p_organization_id UUID DEFAULT NULL
)
RETURNS NUMERIC AS $$
DECLARE
    v_is_cold BOOLEAN;
    v_org_id UUID;
    v_cost NUMERIC;
BEGIN
    -- Get organization if not provided
    v_org_id := COALESCE(p_organization_id, (
        SELECT u.organization_id 
        FROM device_actions da 
        JOIN users u ON u.id = da.creator 
        WHERE da.device_id = p_device_id 
        LIMIT 1
    ));
    
    -- Check if device is "froid" type
    SELECT (dss.name = 'froid') 
    INTO v_is_cold
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    JOIN device_service_sub_categories dssc ON dssc.id = dr.device_service_sub_category_id
    JOIN device_service_categories dsc ON dsc.id = dssc.device_service_category_id
    JOIN device_sub_services dss ON dss.id = dsc.device_sub_service_id
    WHERE d.id = p_device_id;
    
    -- Check for organization-specific constant
    SELECT odc.value
    INTO v_cost
    FROM organization_device_costs odc
    WHERE odc.organization_id = v_org_id
    AND odc.cost = 'pallet'
    AND (odc.criteria IS NULL OR 
         (odc.criteria = 'is_cold' AND odc.criteria_value::boolean = v_is_cold));
    
    IF v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    -- Default calculation
    IF v_is_cold THEN
        -- Requirement: "Cout_palette (device_sub_services.name = froid) = 
        -- Cout palette (4,5) / nombre de produits sur palettes (1)"
        RETURN 4.5 / 1.0;
    ELSE
        -- Requirement: "Cout_palette (device_sub_services.name != froid) = 
        -- Cout palette (4,5) / nombre de produits sur palettes (2)"
        RETURN 4.5 / 2.0;
    END IF;
END;
$$ LANGUAGE plpgsql;