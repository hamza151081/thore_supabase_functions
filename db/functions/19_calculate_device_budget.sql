-- ================================================================
-- MAIN BUDGET CALCULATION FUNCTION
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_device_budget(
    p_device_id UUID,
    p_stage VARCHAR -- 'pre_test', 'post_test', 'post_diag', 'repair_complete', 'deee'
)
RETURNS TABLE (
    sale_price NUMERIC,
    purchase_price NUMERIC,
    transport_cost NUMERIC,
    cleaning_cost NUMERIC,
    prelog_cost NUMERIC,
    postlog_cost NUMERIC,
    pallet_cost NUMERIC,
    film_cost NUMERIC,
    consumables_cost NUMERIC,
    aftersales_cost NUMERIC,
    energy_cost NUMERIC,
    diagnostic_cost NUMERIC,
    repair_cost NUMERIC,
    margin NUMERIC,
    storage_cost NUMERIC,
    disassembly_cost NUMERIC,
    spareparts_cost NUMERIC,
    residual_budget NUMERIC,
    refurb_probability NUMERIC
) AS $$
DECLARE
    v_organization_id UUID;
    v_sale_price NUMERIC;
    v_refurb_prob NUMERIC;
BEGIN
    -- Get organization
    SELECT u.organization_id
    INTO v_organization_id
    FROM device_actions da
    JOIN users u ON u.id = da.creator
    WHERE da.device_id = p_device_id
    LIMIT 1;
    
    -- Calculate all components using individual functions
    sale_price := calculate_sale_price(p_device_id, v_organization_id);
    purchase_price := calculate_purchase_price(p_device_id);
    transport_cost := calculate_transport_cost(p_device_id);
    cleaning_cost := calculate_cleaning_cost(p_device_id, v_organization_id);
    prelog_cost := calculate_prelog_cost(v_organization_id);
    postlog_cost := calculate_postlog_cost(v_organization_id);
    pallet_cost := calculate_pallet_cost(p_device_id, v_organization_id);
    film_cost := calculate_film_cost(p_device_id, v_organization_id);
    consumables_cost := calculate_consumables_cost(v_organization_id);
    aftersales_cost := calculate_aftersales_cost(sale_price, v_organization_id);
    energy_cost := calculate_energy_cost(v_organization_id);
    disassembly_cost := calculate_disassembly_cost(v_organization_id);
    margin := calculate_margin(sale_price, v_organization_id);
    refurb_probability := calculate_refurb_probability(p_device_id);
    
    -- Stage-specific calculations
    CASE p_stage
        WHEN 'pre_test' THEN
            diagnostic_cost := calculate_diagnostic_cost_estimated(p_device_id, 'pre_test');
            repair_cost := calculate_repair_cost_estimated(p_device_id, 'pre_test');
            spareparts_cost := calculate_spareparts_cost(p_device_id, v_organization_id, TRUE);
            storage_cost := calculate_storage_cost(p_device_id, TRUE);
            
        WHEN 'post_test' THEN
            diagnostic_cost := calculate_diagnostic_cost_estimated(p_device_id, 'post_test');
            repair_cost := calculate_repair_cost_estimated(p_device_id, 'post_test');
            spareparts_cost := calculate_spareparts_cost(p_device_id, v_organization_id, TRUE);
            storage_cost := calculate_storage_cost(p_device_id, TRUE);
            
        WHEN 'post_diag', 'repair_complete' THEN
            -- Get actual costs from budget table
            SELECT dab.diagnostic_cost, dab.repair_cost, dab.storage_cost
            INTO diagnostic_cost, repair_cost, storage_cost
            FROM device_actions_budget dab
            JOIN device_actions da ON da.id = dab.action_id
            WHERE da.device_id = p_device_id
            ORDER BY da.created_at DESC
            LIMIT 1;
            
            spareparts_cost := calculate_spareparts_cost(p_device_id, v_organization_id, FALSE);
            
            IF storage_cost IS NULL THEN
                storage_cost := calculate_storage_cost(p_device_id, FALSE);
            END IF;
            
        WHEN 'deee' THEN
            diagnostic_cost := COALESCE(diagnostic_cost, 0);
            repair_cost := 0;
            spareparts_cost := calculate_spareparts_cost(p_device_id, v_organization_id, FALSE);
            storage_cost := calculate_storage_cost(p_device_id, FALSE);
    END CASE;
    
    -- Calculate residual budget
    IF p_stage = 'deee' THEN
        residual_budget := -(purchase_price + transport_cost + cleaning_cost + 
                           prelog_cost + energy_cost + diagnostic_cost + 
                           storage_cost + disassembly_cost + spareparts_cost);
    ELSE
        residual_budget := (sale_price - (purchase_price + transport_cost + cleaning_cost +
                          prelog_cost + postlog_cost + pallet_cost + film_cost + 
                          consumables_cost + aftersales_cost + energy_cost + 
                          diagnostic_cost + margin + storage_cost + spareparts_cost + 
                          repair_cost)) * refurb_probability
                          - (purchase_price + transport_cost + prelog_cost + 
                          energy_cost + diagnostic_cost + storage_cost + 
                          disassembly_cost + spareparts_cost) * (1 - refurb_probability);
    END IF;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;