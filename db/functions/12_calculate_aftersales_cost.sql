-- ================================================================
-- AFTERSALES COST CALCULATION
-- Requirement: "Cout_SAV" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_aftersales_cost(
    p_sale_price NUMERIC,
    p_organization_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_rate NUMERIC;
BEGIN
    -- Get organization rate
    SELECT const_cost_aftersales
    INTO v_rate
    FROM organizations
    WHERE id = p_organization_id;
    
    IF v_rate IS NULL THEN
        v_rate := 0.07; -- Default 7%
    END IF;
    
    -- Requirement: "Cout_SAV = 7% x Prix de vente estimé"
    RETURN v_rate * p_sale_price;
END;
$$ LANGUAGE plpgsql;