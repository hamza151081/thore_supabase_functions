CREATE OR REPLACE FUNCTION calculate_and_store_budget()
RETURNS TRIGGER AS $$
DECLARE
    -- Budget calculation variables
    v_org_costs JSONB;
    v_device_costs JSONB;
    v_organization_id UUID;
    v_device_id UUID;
    v_stage VARCHAR;
    v_price_new NUMERIC;
    
    -- Cost components
    v_sale_price NUMERIC;
    v_purchase_price NUMERIC;
    v_transport_cost NUMERIC;
    v_cleaning_cost NUMERIC;
    v_prelog_cost NUMERIC;
    v_postlog_cost NUMERIC;
    v_pallet_cost NUMERIC;
    v_film_cost NUMERIC;
    v_consumables_cost NUMERIC;
    v_aftersales_cost NUMERIC;
    v_energy_cost NUMERIC;
    v_diagnostic_cost NUMERIC;
    v_repair_cost NUMERIC;
    v_margin NUMERIC;
    v_storage_cost NUMERIC;
    v_disassembly_cost NUMERIC;
    v_spareparts_cost NUMERIC;
    
    -- Final result
    v_budget_residual NUMERIC;
    v_added_value NUMERIC;
    v_refurb_probability NUMERIC;
    v_result_value NUMERIC;
    v_max_loss NUMERIC;
BEGIN
    -- Determine stage and extract context based on trigger source
    IF TG_TABLE_NAME = 'device_actions' THEN
        v_device_id := NEW.device_id;
        SELECT organization_id INTO v_organization_id FROM users WHERE id = NEW.creator;
        
        -- Handle all cases based on type and status
        IF NEW.type = 'Réception' THEN
            -- Check if price_new exists (per documentation requirement)
            SELECT dr.price_new
            INTO v_price_new
            FROM devices d
            JOIN device_references dr ON dr.id = d.device_reference_id
            WHERE d.id = NEW.device_id;
            
            -- Skip if no price_new
            IF v_price_new IS NULL OR v_price_new <= 0 THEN
                RETURN NEW;
            END IF;
            
            v_stage := 'pre_test';
            
        ELSIF NEW.type = 'Mise en test' THEN
            v_stage := 'post_test';
            
        ELSIF NEW.status = 'En cours de réparation' THEN
            v_stage := 'post_diag';
            
        ELSIF NEW.status = 'Terminé' THEN  
            v_stage := 'repaired';
            
        ELSIF NEW.status = 'Abandon - démontage' THEN
            v_stage := 'deee';
            
        ELSIF NEW.status = 'Vendu' THEN
            v_stage := 'final_repaired';
            
        ELSIF NEW.status = 'Démontage terminé' THEN
            v_stage := 'final_deee';
            
        ELSE
            RETURN NEW; -- Not a relevant type or status
        END IF;
    ELSE
        RETURN NEW; -- Unknown trigger context
    END IF;
    
    -- Get all costs using optimized functions
    v_org_costs := get_organization_costs(v_organization_id);
    v_device_costs := get_device_specific_costs(v_device_id, v_organization_id);
    
    -- Calculate primary costs
    v_sale_price := calculate_sale_price(v_device_id, v_organization_id);
    v_purchase_price := calculate_purchase_price(v_device_id);
    v_transport_cost := calculate_transport_cost(v_device_id);
    
    -- Extract costs from JSON
    v_prelog_cost := (v_org_costs->>'prelog_cost')::numeric;
    v_postlog_cost := (v_org_costs->>'postlog_cost')::numeric;
    v_consumables_cost := (v_org_costs->>'consumables_cost')::numeric;
    v_energy_cost := (v_org_costs->>'energy_cost')::numeric;
    v_disassembly_cost := (v_org_costs->>'disassembly_cost')::numeric;
    
    v_cleaning_cost := (v_device_costs->>'cleaning_cost')::numeric;
    v_pallet_cost := (v_device_costs->>'pallet_cost')::numeric;
    v_film_cost := (v_device_costs->>'film_cost')::numeric;
    
    -- Calculate dependent costs
    v_aftersales_cost := v_sale_price * (v_org_costs->>'aftersales_rate')::numeric;
    v_margin := v_sale_price * (v_org_costs->>'margin_rate')::numeric;
    
    -- Stage-specific calculations
    CASE v_stage
        WHEN 'pre_test' THEN
            -- Estimate from 90-day averages
            SELECT AVG(dab.diagnostic_cost), AVG(dab.repair_cost)
            INTO v_diagnostic_cost, v_repair_cost
            FROM device_actions_budget dab
            JOIN device_actions da ON da.id = dab.action_id
            JOIN devices d ON d.id = da.device_id
            JOIN device_references dr ON dr.id = d.device_reference_id
            JOIN users u ON u.id = da.creator
            WHERE dr.device_service_sub_category_id = (
                SELECT dr2.device_service_sub_category_id 
                FROM devices d2 JOIN device_references dr2 ON dr2.id = d2.device_reference_id 
                WHERE d2.id = v_device_id
            )
            AND u.organization_id = v_organization_id
            AND da.created_at >= CURRENT_DATE - INTERVAL '90 days'
            AND EXTRACT(DOW FROM da.created_at) BETWEEN 1 AND 5;
            
            v_diagnostic_cost := COALESCE(v_diagnostic_cost, 0);
            v_repair_cost := COALESCE(v_repair_cost, 0);
            v_spareparts_cost := 0;
            v_storage_cost := 0;
            
        WHEN 'post_test' THEN
            -- User-specific diagnostic cost
            SELECT u.hourly_cost * COALESCE(dssc.diag_duration, 0.5)
            INTO v_diagnostic_cost
            FROM device_actions da
            JOIN users u ON u.id = da.creator
            JOIN devices d ON d.id = da.device_id
            JOIN device_references dr ON dr.id = d.device_reference_id
            JOIN device_service_sub_categories dssc ON dssc.id = dr.device_service_sub_category_id
            WHERE da.device_id = v_device_id AND da.type = 'Mise en test'
            ORDER BY da.created_at DESC LIMIT 1;
            
            v_diagnostic_cost := COALESCE(v_diagnostic_cost, 7.5);
            v_repair_cost := COALESCE(v_diagnostic_cost * 3, 22.5); -- Estimate
            v_spareparts_cost := 0;
            v_storage_cost := 0;
            
        WHEN 'post_diag', 'repaired', 'deee' THEN
            -- Real costs from budget table and spare parts
            SELECT dab.diagnostic_cost, dab.repair_cost, dab.storage_cost
            INTO v_diagnostic_cost, v_repair_cost, v_storage_cost
            FROM device_actions_budget dab
            JOIN device_actions da ON da.id = dab.action_id
            WHERE da.device_id = v_device_id
            ORDER BY da.created_at DESC LIMIT 1;
            
            SELECT COALESCE(SUM(spr.price_new_request), 0)
            INTO v_spareparts_cost
            FROM sparepart_requests spr
            WHERE spr.device_id = v_device_id AND spr.archived = false;
            
            v_diagnostic_cost := COALESCE(v_diagnostic_cost, 0);
            v_repair_cost := COALESCE(v_repair_cost, 0);
            v_storage_cost := COALESCE(v_storage_cost, 0);
            
            IF v_stage = 'deee' THEN
                v_repair_cost := 0; -- No repair for DEEE
            END IF;
            
        WHEN 'final_repaired', 'final_deee' THEN
            -- Final calculations with actual storage
            SELECT dab.diagnostic_cost, dab.repair_cost
            INTO v_diagnostic_cost, v_repair_cost
            FROM device_actions_budget dab
            JOIN device_actions da ON da.id = dab.action_id
            WHERE da.device_id = v_device_id
            ORDER BY da.created_at DESC LIMIT 1;
            
            SELECT COALESCE(SUM(spr.price_new_request), 0)
            INTO v_spareparts_cost
            FROM sparepart_requests spr
            WHERE spr.device_id = v_device_id AND spr.archived = false;
            
            -- Calculate actual storage time
            IF v_stage = 'final_repaired' THEN
                SELECT EXTRACT(DAY FROM NEW.last_edit - da_rec.created_at) * 0.35
                INTO v_storage_cost
                FROM device_actions da_rec
                WHERE da_rec.device_id = v_device_id AND da_rec.type = 'Réception'
                ORDER BY da_rec.created_at ASC LIMIT 1;
            ELSE
                v_repair_cost := 0; -- No repair for DEEE
                SELECT EXTRACT(DAY FROM NEW.last_edit - da_rec.created_at) * 0.35
                INTO v_storage_cost
                FROM device_actions da_rec
                WHERE da_rec.device_id = v_device_id AND da_rec.type = 'Réception'
                ORDER BY da_rec.created_at ASC LIMIT 1;
            END IF;
            
            v_diagnostic_cost := COALESCE(v_diagnostic_cost, 0);
            v_repair_cost := COALESCE(v_repair_cost, 0);
            v_storage_cost := COALESCE(v_storage_cost, 0);
    END CASE;
    
    -- Calculate refurbishment probability for budget stages
    IF v_stage IN ('pre_test', 'post_test', 'post_diag') THEN
        v_refurb_probability := calculate_refurb_probability(v_device_id);
    ELSE
        v_refurb_probability := CASE WHEN v_stage IN ('repaired', 'final_repaired') THEN 1.0 ELSE 0.0 END;
    END IF;
    
    -- Calculate final result based on stage
    IF v_stage IN ('pre_test', 'post_test', 'post_diag') THEN
        -- NEW Budget résiduel formula: [saleprice - all_costs1] * P(recond) - all_costs2 * (1-P(recond))
        v_budget_residual := (
            v_sale_price - (
                v_purchase_price + v_transport_cost + v_cleaning_cost + 
                v_prelog_cost + v_postlog_cost + v_pallet_cost + v_film_cost + 
                v_consumables_cost + v_aftersales_cost + v_energy_cost + 
                v_diagnostic_cost + v_margin + v_storage_cost + v_spareparts_cost + v_repair_cost
            )
        ) * v_refurb_probability - (
            v_purchase_price + v_transport_cost + v_prelog_cost + v_energy_cost + 
            v_diagnostic_cost + v_storage_cost + v_disassembly_cost + v_spareparts_cost
        ) * (1 - v_refurb_probability);
        
        v_result_value := v_budget_residual;
        
    ELSIF v_stage IN ('repaired', 'final_repaired') THEN
        -- Valeur ajoutée réparée
        v_added_value := v_sale_price - (
            v_purchase_price + v_transport_cost + v_cleaning_cost + 
            v_prelog_cost + v_postlog_cost + v_pallet_cost + v_film_cost + 
            v_consumables_cost + v_aftersales_cost + v_energy_cost + 
            v_diagnostic_cost + v_margin + v_storage_cost + v_spareparts_cost + v_repair_cost
        );
        
        v_result_value := v_added_value;
        
    ELSIF v_stage IN ('deee', 'final_deee') THEN
        -- Valeur ajoutée DEEE (negative)
        v_added_value := -(
            v_purchase_price + v_transport_cost + v_cleaning_cost + 
            v_prelog_cost + v_energy_cost + v_diagnostic_cost + 
            v_storage_cost + v_disassembly_cost + v_spareparts_cost
        );
        
        v_result_value := v_added_value;
    END IF;
    
    -- Calculate max_loss using the specific formula
    -- max_loss = -(Achat_prix + Achat_transport + Cout_diag)
    v_max_loss := -(v_purchase_price + v_transport_cost + v_diagnostic_cost);
    
    -- Store results in device_actions_budget
    IF TG_TABLE_NAME = 'device_actions_reparations' THEN
        -- Use the related device_actions.id
        INSERT INTO device_actions_budget (
            creator, action_id, 
            sale_price, purchase_price, transport_cost, cleaning_cost,
            prelog_cost, postlog_cost, pallet_cost, film_cost,
            consumables_cost, aftersales_cost, energy_cost, 
            diagnostic_cost, repair_cost, margin, storage_cost, 
            disassembly_cost, spareparts_cost, max_loss, prediag_addedvalue
        ) VALUES (
            (SELECT creator FROM device_actions WHERE id = NEW.action_id),
            NEW.action_id,
            v_sale_price, v_purchase_price, v_transport_cost, v_cleaning_cost,
            v_prelog_cost, v_postlog_cost, v_pallet_cost, v_film_cost,
            v_consumables_cost, v_aftersales_cost, v_energy_cost,
            v_diagnostic_cost, v_repair_cost, v_margin, v_storage_cost,
            v_disassembly_cost, v_spareparts_cost, v_max_loss, v_result_value
        );
    ELSE
        -- Use NEW.id directly for device_actions
        INSERT INTO device_actions_budget (
            creator, action_id, 
            sale_price, purchase_price, transport_cost, cleaning_cost,
            prelog_cost, postlog_cost, pallet_cost, film_cost,
            consumables_cost, aftersales_cost, energy_cost, 
            diagnostic_cost, repair_cost, margin, storage_cost, 
            disassembly_cost, spareparts_cost, max_loss, prediag_addedvalue
        ) VALUES (
            NEW.creator, NEW.id,
            v_sale_price, v_purchase_price, v_transport_cost, v_cleaning_cost,
            v_prelog_cost, v_postlog_cost, v_pallet_cost, v_film_cost,
            v_consumables_cost, v_aftersales_cost, v_energy_cost,
            v_diagnostic_cost, v_repair_cost, v_margin, v_storage_cost,
            v_disassembly_cost, v_spareparts_cost, v_max_loss, v_result_value
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
