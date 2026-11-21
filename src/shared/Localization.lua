--!strict
-- DE/EN UI strings. Keys are stable identifiers; every key must exist in both languages
-- (enforced by Localization_Test). Values may contain string.format placeholders.
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
		loading = "loading…",
		plotStatus = "Plot: %s",
		plotParkingStatus = "Plot: %s · Parking: %d",
		unavailable = "Unavailable: %s",
		wholesaleQuote = "%s · %s · $%d wholesale",
		ordering = "Ordering…",
		orderAccepted = "Order accepted: $%d",
		truckOnTheWay = "Truck is on the way",
		orderUnavailable = "Order unavailable",
		errorStatus = "Error: %s",
		unloadDelivery = "Unload delivered trees",
		noDeliveryReady = "No delivery ready",
		treesUnloaded = "Trees unloaded into storage",
		placeTree = "Place %s (%d stored)",
		treePlaced = "Tree placed for customers",
		connectionError = "Connection problem, please try again",
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
		loading = "lädt…",
		plotStatus = "Grundstück: %s",
		plotParkingStatus = "Grundstück: %s · Parkplätze: %d",
		unavailable = "Nicht verfügbar: %s",
		wholesaleQuote = "%s · %s · %d $ Einkauf",
		ordering = "Bestelle…",
		orderAccepted = "Bestellung angenommen: %d $",
		truckOnTheWay = "Der Lieferwagen ist unterwegs",
		orderUnavailable = "Bestellung nicht möglich",
		errorStatus = "Fehler: %s",
		unloadDelivery = "Gelieferte Bäume abladen",
		noDeliveryReady = "Keine Lieferung bereit",
		treesUnloaded = "Bäume ins Lager abgeladen",
		placeTree = "%s aufstellen (%d im Lager)",
		treePlaced = "Baum für Kunden aufgestellt",
		connectionError = "Verbindungsproblem, bitte erneut versuchen",
	},
}

function Localization.get(language: string, key: string): string
	local strings = Localization.Strings[language] or Localization.Strings.en
	return strings[key] or Localization.Strings.en[key] or key
end

-- Formats a localized template; a missing or malformed template never errors the UI.
function Localization.format(language: string, key: string, ...: any): string
	local template = Localization.get(language, key)
	local ok, text = pcall(string.format, template, ...)
	return if ok then text else template
end

return Localization
