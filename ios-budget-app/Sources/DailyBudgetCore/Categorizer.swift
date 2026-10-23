import Foundation

public enum Categories {
    public static let food = "Food & Dining", groceries = "Groceries", transport = "Transport", shopping = "Shopping"
    public static let bills = "Bills & Recharge", entertainment = "Entertainment", health = "Health", cash = "Cash"
    public static let transfers = "Transfers", cardBill = "Credit Card Bill", other = "Other"
    /// Card bills double count the card purchases already seen.
    public static let excludedByDefault: Set<String> = [cardBill]
    public static let all = [food, groceries, transport, shopping, bills, entertainment, health, cash, transfers, cardBill, other]
}

public enum Categorizer {
    private static let rules: [(String, [String])] = [
        (Categories.cardBill, ["credit card", "cc bill", "cred club", "cred.club", "billdesk card"]),
        (Categories.food, ["swiggy", "zomato", "dominos", "domino", "mcdonald", "kfc", "burger king", "starbucks", "pizza", "cafe", "restaurant", "haldiram", "eatfit", "box8", "behrouz", "dunzo food"]),
        (Categories.groceries, ["blinkit", "zepto", "bigbasket", "instamart", "dmart", "grofers", "jiomart", "reliance fresh", "more retail", "nature basket", "milk", "kirana"]),
        (Categories.transport, ["uber", "ola", "rapido", "irctc", "redbus", "metro", "fuel", "petrol", "indian oil", "iocl", "hpcl", "bpcl", "fastag", "makemytrip", "indigo", "cleartrip", "yatra"]),
        (Categories.shopping, ["amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa", "tatacliq", "decathlon", "lifestyle", "shoppers stop", "croma", "reliance digital"]),
        (Categories.bills, ["airtel", "jio", "vodafone", "vi ", "bsnl", "electricity", "bescom", "tneb", "mseb", "tata power", "adani", "gas", "water", "broadband", "act fibernet", "recharge", "dth", "tata play", "insurance", "lic", "rent"]),
        (Categories.entertainment, ["netflix", "spotify", "hotstar", "prime video", "bookmyshow", "youtube", "sonyliv", "zee5", "pvr", "inox", "gaana", "steam", "playstation"]),
        (Categories.health, ["apollo", "pharmeasy", "1mg", "netmeds", "medplus", "hospital", "clinic", "diagnostic", "lab", "pharmacy", "practo", "cult"]),
    ]

    public static func categorize(_ t: ParsedTxn) -> String {
        if t.method == "ATM" { return Categories.cash }
        let m = (t.merchant ?? "").lowercased()
        for (cat, keys) in rules where keys.contains(where: { m.contains($0) }) { return cat }
        if m.trimmingCharacters(in: .whitespaces).isEmpty || m.allSatisfy({ $0.isNumber || $0 == " " }) { return Categories.transfers }
        return Categories.other
    }
}
