-- ================================================================
-- FILM COST CALCULATION
-- Requirement: "Cout_film" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_film_cost(
    p_device_id UUID,
    p_organization_id UUID DEFAULT NULL
)
RETURNS NUMERIC AS $$
DECLARE
    v_is_cold BOOLEAN;
    v_org_id UUID;
    v_base_cost NUMERIC;
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
    SELECT (dss.name = 'Froid') 
    INTO v_is_cold
    FROM devices d 
    JOIN device_references dr ON dr.id = d.device_reference_id
    JOIN device_service_sub_categories dssc ON dssc.id = dr.device_service_sub_category_id
    JOIN device_service_categories dsc ON dsc.id = dssc.device_service_category_id
    JOIN device_sub_services dss ON dss.id = dsc.device_sub_service_id
    WHERE d.id = p_device_id;
    
    -- Get organization constant
    SELECT const_cost_film
    INTO v_base_cost
    FROM organizations
    WHERE id = v_org_id;
    
    IF v_base_cost IS NULL THEN
        v_base_cost := 0.6; -- Default value
    END IF;
    
    -- Apply multiplier for cold devices
    IF v_is_cold THEN
        -- Requirement: "Cout_film (device_sub_services.name = froid) = Coût_film unitaire (0,6) x 2"
        RETURN v_base_cost * 2;
    ELSE
        -- Requirement: "Cout_film (device_sub_services.name != froid) = Coût_film unitaire (0,6)"
        RETURN v_base_cost;
    END IF;
END;
$$ LANGUAGE plpgsql;