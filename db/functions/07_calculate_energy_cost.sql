-- ================================================================
-- ENERGY COST CALCULATION
-- Requirement: "Cout_energie" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_energy_cost(
    p_organization_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_cost NUMERIC;
BEGIN
    -- Get organization constant
    SELECT const_cost_energy
    INTO v_cost
    FROM organizations
    WHERE id = p_organization_id;
    
    IF v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    -- Default calculation
    -- Requirement: "Cout_energie = Cout_energie unitaire (5)"
    RETURN 5.0;
END;
$$ LANGUAGE plpgsql;