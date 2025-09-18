-- ================================================================
-- CLEANING COST CALCULATION
-- Requirement: "Cout nettoyage" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_cleaning_cost(
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
    
    -- Check for organization-specific constant first
    SELECT odc.value
    INTO v_cost
    FROM organization_device_costs odc
    WHERE odc.organization_id = v_org_id
    AND odc.cost = 'cleaning'
    AND (odc.criteria IS NULL OR 
         (odc.criteria = 'is_cold' AND odc.criteria_value::boolean = v_is_cold));
    
    IF v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    -- Default calculation
    IF v_is_cold THEN
        -- Requirement: "Cout_nettoyage (device_sub_services.name = froid) = 
        -- Taux horaire (12) x nombre d'heure jour (7) x nombre d'opérateurs (2) / nombre d'appareil jour (10)"
        RETURN 12 * 7 * 2 / 10.0;
    ELSE
        -- Requirement: "Cout_nettoyage (device_sub_services.name != froid) = 
        -- Taux horaire (12) x nombre d'heure jour (7) x nombre d'opérateurs (2) / nombre d'appareil jour (16)"
        RETURN 12 * 7 * 2 / 16.0;
    END IF;
END;
$$ LANGUAGE plpgsql;