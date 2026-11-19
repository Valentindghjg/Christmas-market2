--!strict
local Localization = {}
Localization.Strings = {
	en = {
		cash = "Cash",
		reputation = "Reputation",
		lotStatus = "Lot status",
		supplier = "Tree Supplier",
		catalog = "Catalog",
		pricing = "Pricing",
		employees = "Employees",
		land = "Land",
		analytics = "Analytics",
		layout = "Layout",
		decorate = "Decorate",
		quests = "Quests",
		placeOrder = "Place order",
		insufficientFunds = "Not enough cash",
	},
	de = {
		cash = "Geld",
		reputation = "Ruf",
		lotStatus = "Grundstücksstatus",
		supplier = "Baumlieferant",
		catalog = "Katalog",
		pricing = "Preise",
		employees = "Mitarbeiter",
		land = "Grundstück",
		analytics = "Statistiken",
		layout = "Layout",
		decorate = "Dekorieren",
		quests = "Aufgaben",
		placeOrder = "Bestellung aufgeben",
		insufficientFunds = "Nicht genug Geld",
	},
}
function Localization.get(language: string, key: string): string
	local strings = Localization.Strings[language] or Localization.Strings.en
	return strings[key] or Localization.Strings.en[key] or key
end
return Localization
