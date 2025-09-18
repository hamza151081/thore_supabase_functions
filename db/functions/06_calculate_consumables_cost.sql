-- ================================================================
-- CONSUMABLES COST CALCULATION
-- Requirement: "Cout_consommableNettoyage" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_consumables_cost(
    p_organization_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_cost NUMERIC;
BEGIN
    -- Get organization constant
    SELECT const_cost_consumables
    INTO v_cost
    FROM organizations
    WHERE id = p_organization_id;
    
    IF v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    -- Default calculation
    -- Requirement: "Cout_consommableNettoyage = Cout_consommableNettoyage unitaire (2)"
    RETURN 2.0;
END;
$$ LANGUAGE plpgsql;