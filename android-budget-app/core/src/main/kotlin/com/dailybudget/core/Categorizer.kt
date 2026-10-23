package com.dailybudget.core

object Categories {
    const val FOOD = "Food & Dining"
    const val GROCERIES = "Groceries"
    const val TRANSPORT = "Transport"
    const val SHOPPING = "Shopping"
    const val BILLS = "Bills & Recharge"
    const val ENTERTAINMENT = "Entertainment"
    const val HEALTH = "Health"
    const val CASH = "Cash"
    const val TRANSFERS = "Transfers"
    const val CARD_BILL = "Credit Card Bill"
    const val OTHER = "Other"

    /** Not real spending: card bills double count the card purchases already seen. */
    val excludedByDefault = setOf(CARD_BILL)
    val all = listOf(FOOD, GROCERIES, TRANSPORT, SHOPPING, BILLS, ENTERTAINMENT, HEALTH, CASH, TRANSFERS, CARD_BILL, OTHER)
}

object Categorizer {
    private val rules: List<Pair<String, List<String>>> = listOf(
        Categories.CARD_BILL to listOf("credit card", "cc bill", "cred club", "cred.club", "billdesk card"),
        Categories.FOOD to listOf("swiggy", "zomato", "dominos", "domino", "mcdonald", "kfc", "burger king",
            "starbucks", "pizza", "cafe", "restaurant", "haldiram", "eatfit", "box8", "behrouz", "dunzo food"),
        Categories.GROCERIES to listOf("blinkit", "zepto", "bigbasket", "instamart", "dmart", "grofers",
            "jiomart", "reliance fresh", "more retail", "nature basket", "milk", "kirana"),
        Categories.TRANSPORT to listOf("uber", "ola", "rapido", "irctc", "redbus", "metro", "fuel", "petrol",
            "indian oil", "iocl", "hpcl", "bpcl", "fastag", "makemytrip", "indigo", "cleartrip", "yatra"),
        Categories.SHOPPING to listOf("amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa", "tatacliq",
            "decathlon", "lifestyle", "shoppers stop", "croma", "reliance digital"),
        Categories.BILLS to listOf("airtel", "jio", "vodafone", "vi ", "bsnl", "electricity", "bescom", "tneb",
            "mseb", "tata power", "adani", "gas", "water", "broadband", "act fibernet", "recharge", "dth",
            "tata play", "insurance", "lic", "rent"),
        Categories.ENTERTAINMENT to listOf("netflix", "spotify", "hotstar", "prime video", "bookmyshow", "youtube",
            "sonyliv", "zee5", "pvr", "inox", "gaana", "steam", "playstation"),
        Categories.HEALTH to listOf("apollo", "pharmeasy", "1mg", "netmeds", "medplus", "hospital", "clinic",
            "diagnostic", "lab", "pharmacy", "practo", "cult"),
    )

    fun categorize(t: ParsedTxn): String {
        if (t.method == "ATM") return Categories.CASH
        val m = (t.merchant ?: "").lowercase()
        for ((cat, keys) in rules) if (keys.any { m.contains(it) }) return cat
        // A merchant that is just digits / a short personal handle is a person-to-person payment.
        if (m.isBlank() || m.all { it.isDigit() || it == ' ' }) return Categories.TRANSFERS
        return Categories.OTHER
    }
}
