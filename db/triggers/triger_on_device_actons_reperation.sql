CREATE TRIGGER on_repair_actions_budget_calc
    AFTER INSERT ON device_actions_reparations
    FOR EACH ROW
    EXECUTE FUNCTION calculate_and_store_budget();