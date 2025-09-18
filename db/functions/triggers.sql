-- ================================================================
-- TRIGGER FUNCTIONS
-- ================================================================

-- Trigger for device reception
CREATE OR REPLACE FUNCTION trigger_calculate_budget_on_reception()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.type = 'Réception' THEN
        INSERT INTO device_actions_budget (
            creator, action_id, sale_price, purchase_price, transport_cost,
            cleaning_cost, prelog_cost, postlog_cost, pallet_cost, film_cost,
            consumables_cost, aftersales_cost, energy_cost, diagnostic_cost,
            repair_cost, margin, storage_cost, disassembly_cost
        )
        SELECT 
            NEW.creator, NEW.id, 
            b.sale_price, b.purchase_price, b.transport_cost,
            b.cleaning_cost, b.prelog_cost, b.postlog_cost, b.pallet_cost, 
            b.film_cost, b.consumables_cost, b.aftersales_cost, b.energy_cost,
            b.diagnostic_cost, b.repair_cost, b.margin, b.storage_cost, 
            b.disassembly_cost
        FROM calculate_device_budget(NEW.device_id, 'pre_test') b;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_device_reception
AFTER INSERT ON device_actions
FOR EACH ROW
WHEN (NEW.type = 'Réception')
EXECUTE FUNCTION trigger_calculate_budget_on_reception();

-- Trigger for mise en test
CREATE OR REPLACE FUNCTION trigger_calculate_budget_on_test()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.type = 'Mise en test' THEN
        INSERT INTO device_actions_budget (
            creator, action_id, sale_price, purchase_price, transport_cost,
            cleaning_cost, prelog_cost, postlog_cost, pallet_cost, film_cost,
            consumables_cost, aftersales_cost, energy_cost, diagnostic_cost,
            repair_cost, margin, storage_cost, disassembly_cost
        )
        SELECT 
            NEW.creator, NEW.id,
            b.sale_price, b.purchase_price, b.transport_cost,
            b.cleaning_cost, b.prelog_cost, b.postlog_cost, b.pallet_cost, 
            b.film_cost, b.consumables_cost, b.aftersales_cost, b.energy_cost,
            b.diagnostic_cost, b.repair_cost, b.margin, b.storage_cost, 
            b.disassembly_cost
        FROM calculate_device_budget(NEW.device_id, 'post_test') b;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_device_test
AFTER INSERT ON device_actions
FOR EACH ROW
WHEN (NEW.type = 'Mise en test')
EXECUTE FUNCTION trigger_calculate_budget_on_test();

-- Trigger for repair stages
CREATE OR REPLACE FUNCTION trigger_calculate_budget_on_repair()
RETURNS TRIGGER AS $$
DECLARE
    v_action_id UUID;
    v_stage VARCHAR;
BEGIN
    SELECT action_id INTO v_action_id FROM device_actions_reparations WHERE id = NEW.id;
    
    CASE NEW.status
        WHEN 'En cours de réparation' THEN
            v_stage := 'post_diag';
        WHEN 'Terminé' THEN
            v_stage := 'repair_complete';
        WHEN 'Abandon - démontage' THEN
            v_stage := 'deee';
        ELSE
            RETURN NEW;
    END CASE;
    
    UPDATE device_actions_budget dab
    SET (sale_price, purchase_price, transport_cost, cleaning_cost, prelog_cost,
         postlog_cost, pallet_cost, film_cost, consumables_cost, aftersales_cost,
         energy_cost, diagnostic_cost, repair_cost, margin, storage_cost, disassembly_cost) =
        (SELECT b.sale_price, b.purchase_price, b.transport_cost, b.cleaning_cost,
                b.prelog_cost, b.postlog_cost, b.pallet_cost, b.film_cost,
                b.consumables_cost, b.aftersales_cost, b.energy_cost, b.diagnostic_cost,
                b.repair_cost, b.margin, b.storage_cost, b.disassembly_cost
         FROM calculate_device_budget(
             (SELECT device_id FROM device_actions WHERE id = v_action_id),
             v_stage
         ) b)
    WHERE dab.action_id = v_action_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_repair_status_change
AFTER INSERT ON device_actions_reparations
FOR EACH ROW
EXECUTE FUNCTION trigger_calculate_budget_on_repair();