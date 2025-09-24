
-- ================================================================
-- COMBINED ORGANIZATION COSTS FUNCTION - OPTIMIZED
-- Returns all organization-level constants in a single JSON object
-- Replaces: calculate_prelog_cost, calculate_postlog_cost, 
--          calculate_consumables_cost, calculate_energy_cost, calculate_disassembly_cost
-- ================================================================
CREATE OR REPLACE FUNCTION get_organization_costs(
    p_organization_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_costs JSONB;
BEGIN
    -- Get all organization constants in a single query
    SELECT jsonb_build_object(
        'prelog_cost', COALESCE(const_cost_log_pre, 0),
        'postlog_cost', COALESCE(const_cost_log_post, 0),
        'consumables_cost', COALESCE(const_cost_consumables, 0),
        'energy_cost', COALESCE(const_cost_energy, 0),
        'disassembly_cost', COALESCE(const_cost_disassembly, 0),
        'aftersales_rate', COALESCE(const_cost_aftersales_rate, 0.07),
        'margin_rate', COALESCE(const_cost_margin_rate, 0.05)
       
    )
    INTO v_costs
    FROM organizations
    WHERE id = p_organization_id;
    
    -- Return default values if organization not found
    IF v_costs IS NULL THEN
        v_costs := jsonb_build_object(
            'prelog_cost', 0,
            'postlog_cost', 0,
            'consumables_cost', 0,
            'energy_cost', 0,
            'disassembly_cost', 0,
            'aftersales_rate', 0.07,
            'margin_rate', 0.05,
            'film_cost', 0.6
        );
    END IF;
    
    RETURN v_costs;
END;
$$ LANGUAGE plpgsql;