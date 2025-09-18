-- ================================================================
-- POST-LOGISTICS COST CALCULATION
-- Requirement: "Cout_log_post" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_postlog_cost(
    p_organization_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_cost NUMERIC;
BEGIN
    -- Get organization constant
    SELECT const_cost_log_post
    INTO v_cost
    FROM organizations
    WHERE id = p_organization_id;
    
    IF v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    -- Default calculation
    -- Requirement: "Cout_log_post = Taux horaire (13,5) x nombre de temps appareil (0,8)"
    RETURN 13.5 * 0.8;
END;
$$ LANGUAGE plpgsql;