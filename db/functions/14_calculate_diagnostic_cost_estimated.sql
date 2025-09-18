-- ================================================================
-- DIAGNOSTIC COST CALCULATION (ESTIMATED)
-- Requirement: "Cout_diag et Cout_rep" - Section "Résultat par device"
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_diagnostic_cost_estimated(
    p_device_id UUID,
    p_stage VARCHAR DEFAULT 'pre_test' -- 'pre_test' or 'post_test'
)
RETURNS NUMERIC AS $$
DECLARE
    v_cost NUMERIC;
    v_subcat_id UUID;
    v_organization_id UUID;
    v_user_hourly_cost NUMERIC;
    v_avg_duration NUMERIC;
BEGIN
    -- Get device subcategory and organization
    SELECT dr.device_service_sub_category_id, u.organization_id
    INTO v_subcat_id, v_organization_id
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    JOIN device_actions da ON da.device_id = d.id
    JOIN users u ON u.id = da.creator
    WHERE d.id = p_device_id
    LIMIT 1;
    
    IF p_stage = 'pre_test' THEN
        -- Requirement: "Avant mise en test (étape 1)"
        -- "Cout-diag_est = moyenne Cout-diag_reel sur 90 derniers jours ouvrés"
        SELECT AVG(dab.diagnostic_cost)
        INTO v_cost
        FROM device_actions_budget dab
        JOIN device_actions da ON da.id = dab.action_id
        JOIN devices d ON d.id = da.device_id
        JOIN device_references dr ON dr.id = d.device_reference_id
        WHERE dr.device_service_sub_category_id = v_subcat_id
        AND da.creator IN (SELECT id FROM users WHERE organization_id = v_organization_id)
        AND da.created_at >= CURRENT_DATE - INTERVAL '90 days'
        AND EXTRACT(DOW FROM da.created_at) NOT IN (0, 6)
        AND dab.diagnostic_cost IS NOT NULL;
        
    ELSIF p_stage = 'post_test' THEN
        -- Requirement: "Après mise en test (étape 2)"
        -- "Cout-diag_est = Taux horaire collaborateur x temps moyen diag sur 90j"
        
        -- Get user hourly cost
        SELECT u.hourly_cost
        INTO v_user_hourly_cost
        FROM device_actions da
        JOIN users u ON u.id = da.creator
        WHERE da.device_id = p_device_id
        AND da.type = 'Mise en test'
        ORDER BY da.created_at DESC
        LIMIT 1;
        
        -- Get average diagnostic duration
        SELECT dssc.diag_duration
        INTO v_avg_duration
        FROM device_service_sub_categories dssc
        WHERE dssc.id = v_subcat_id;
        
        v_cost := COALESCE(v_user_hourly_cost, 15) * COALESCE(v_avg_duration, 0.5);
    END IF;
    
    RETURN COALESCE(v_cost, 0);
END;
$$ LANGUAGE plpgsql;