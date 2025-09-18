-- ================================================================
-- DISASSEMBLY COST CALCULATION
-- Requirement: "Cout_démontage" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_disassembly_cost(
    p_organization_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_cost NUMERIC;
BEGIN
    -- Get organization constant
    SELECT const_cost_disassembly
    INTO v_cost
    FROM organizations
    WHERE id = p_organization_id;
    
    IF v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    -- Default calculation
    -- Requirement: "Cout_démontage = Taux horaire alternant (8) x nombre d'heures par jour (7) / nombre de machines jour (5)"
    RETURN 8.0 * 7.0 / 5.0;
END;
$$ LANGUAGE plpgsql;