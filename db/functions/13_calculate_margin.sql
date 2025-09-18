-- ================================================================
-- MARGIN CALCULATION
-- Requirement: "Marge_DN" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_margin(
    p_sale_price NUMERIC,
    p_organization_id UUID DEFAULT NULL
)
RETURNS NUMERIC AS $$
DECLARE
    v_rate NUMERIC := 0.05; -- Default 5%
BEGIN
    -- Could check for organization-specific margin rate here
    -- For now using fixed 5%
    
    -- Requirement: "Marge_DN = 5% x Prix de vente estimé"
    RETURN v_rate * p_sale_price;
END;
$$ LANGUAGE plpgsql;