-- ================================================================
-- SPARE PARTS COST CALCULATION
-- Requirement: "Cout_pièce" section
-- ================================================================
CREATE OR REPLACE FUNCTION calculate_spareparts_cost(
    p_device_id UUID,
    p_organization_id UUID,
    p_is_estimate BOOLEAN DEFAULT TRUE
)
RETURNS NUMERIC AS $$
DECLARE
    v_cost NUMERIC;
    v_device_ref_id UUID;
    v_subcat_id UUID;
    v_brand_id UUID;
    v_year_production INTEGER;
    v_count INTEGER;
    v_is_doneo BOOLEAN;
BEGIN
    IF NOT p_is_estimate THEN
        -- Actual spare parts cost
        SELECT COALESCE(SUM(spr.price_new_request), 0)
        INTO v_cost
        FROM sparepart_requests spr
        WHERE spr.device_id = p_device_id
        AND spr.archived = false;
        
        RETURN v_cost;
    END IF;
    
    -- Check if organization is Doneo
    v_is_doneo := (p_organization_id = 'bae04415-1ca9-46c2-81c8-11e39ac8ac89'::uuid);
    
    -- Get device information
    SELECT dr.id, dr.device_service_sub_category_id, dr.brand_id, dr.year_production
    INTO v_device_ref_id, v_subcat_id, v_brand_id, v_year_production
    FROM devices d
    JOIN device_references dr ON dr.id = d.device_reference_id
    WHERE d.id = p_device_id;
    
    -- Try to get average for same model
    IF v_is_doneo THEN
        WITH model_avg AS (
            SELECT AVG(total_cost) as avg_cost, COUNT(*) as cnt
            FROM (
                SELECT d.id, COALESCE(SUM(spr.price_new_request), 0) as total_cost
                FROM devices d
                LEFT JOIN sparepart_requests spr ON spr.device_id = d.id 
                    AND spr.archived = false 
                    AND EXISTS (
                        SELECT 1 FROM sparepart_requests_actions sra 
                        WHERE sra.sparepart_request_id = spr.id 
                        AND sra.status = 'Terminée'
                    )
                WHERE d.device_reference_id = v_device_ref_id
                AND EXISTS (
                    SELECT 1 FROM device_actions da
                    WHERE da.device_id = d.id
                    AND da.status IN ('Nettoyage', 'Contrôle qualité', 'Prêt à la vente', 'Vendu')
                )
                GROUP BY d.id
            ) device_costs
        )
        SELECT avg_cost, cnt INTO v_cost, v_count FROM model_avg;
    ELSE
        WITH model_avg AS (
            SELECT AVG(total_cost) as avg_cost, COUNT(*) as cnt
            FROM (
                SELECT d.id, COALESCE(SUM(spref.price_new_request), 0) as total_cost
                FROM devices d
                LEFT JOIN sparepart_requests spr ON spr.device_id = d.id AND spr.archived = false
                LEFT JOIN sparepart_references spref ON spref.id = spr.sparepart_reference_id
                WHERE d.device_reference_id = v_device_ref_id
                AND EXISTS (
                    SELECT 1 FROM sparepart_requests_actions sra 
                    WHERE sra.sparepart_request_id = spr.id 
                    AND sra.status = 'Terminée'
                )
                AND EXISTS (
                    SELECT 1 FROM device_actions da
                    WHERE da.device_id = d.id
                    AND da.status IN ('Nettoyage', 'Contrôle qualité', 'Prêt à la vente', 'Vendu')
                )
                GROUP BY d.id
            ) device_costs
        )
        SELECT avg_cost, cnt INTO v_cost, v_count FROM model_avg;
    END IF;
    
    IF v_count >= 30 AND v_cost IS NOT NULL THEN
        RETURN v_cost;
    END IF;
    
    RETURN COALESCE(v_cost, 0);
END;
$$ LANGUAGE plpgsql;