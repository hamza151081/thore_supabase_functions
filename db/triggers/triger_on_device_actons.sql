CREATE TRIGGER on_device_actions_budget_calc
    AFTER INSERT OR UPDATE ON device_actions
    FOR EACH ROW
    EXECUTE FUNCTION calculate_and_store_budget();