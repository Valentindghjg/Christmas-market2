--!strict
local AnalyticsService = {}

function AnalyticsService.summary(state)
	if type(state) ~= "table" then
		return nil
	end
	local visits = state.customerVisits
	local sales = state.sales
	if type(visits) ~= "number" or type(sales) ~= "number" or visits < 0 then
		return nil
	end
	return {
		visits = visits,
		sales = sales,
		abandonedCustomers = state.abandonedCustomers,
		walkedOutCustomers = state.walkedOutCustomers,
		revenue = state.revenue,
		spent = state.spent,
		conversionRate = visits == 0 and 0 or sales / visits,
		averageSale = sales == 0 and 0 or state.revenue / sales,
	}
end

return AnalyticsService
