import Foundation

// MARK: - Price Information Models

struct PriceInfo: Identifiable {
    let id = UUID()
    let retailer: String
    let price: Double?
    let currency: String
    let priceDisplay: String
    let url: URL?
    let availability: String?
    let shipping: String?
}

// MARK: - Free Price Lookup Service

actor PriceLookupService {
    
    // Get price estimates using free methods
    func lookupPrices(barcode: String, productName: String?, brand: String? = nil) async -> [PriceInfo] {
        var prices: [PriceInfo] = []
        
        // Create search query - prefer product name if available, otherwise format barcode properly
        let searchQuery: String
        if let name = productName, !name.isEmpty {
            // Use product name and brand if available
            if let brand = brand, !brand.isEmpty {
                searchQuery = "\(brand) \(name)"
            } else {
                searchQuery = name
            }
        } else {
            // Format barcode for better search results
            searchQuery = "\(barcode)"
        }
        
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? barcode
        let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? barcode
        
        // Determine availability message based on whether we have product info
        let hasProductInfo = productName != nil && !productName!.isEmpty
        let availabilityMessage = hasProductInfo ? "Compare prices" : "Search by barcode"
        
        // Google Shopping link (user can tap to see prices)
        if let googleURL = URL(string: "https://www.google.com/search?tbm=shop&q=\(encodedQuery)") {
            prices.append(PriceInfo(
                retailer: "Google Shopping",
                price: nil,
                currency: "USD",
                priceDisplay: "Compare prices",
                url: googleURL,
                availability: "Multiple retailers",
                shipping: nil
            ))
        }
        
        // Amazon search link
        if let amazonURL = URL(string: "https://www.amazon.com/s?k=\(encodedQuery)") {
            prices.append(PriceInfo(
                retailer: "Amazon",
                price: nil,
                currency: "USD",
                priceDisplay: "Search Amazon",
                url: amazonURL,
                availability: availabilityMessage,
                shipping: nil
            ))
        }
        
        // Walmart search link
        if let walmartURL = URL(string: "https://www.walmart.com/search?q=\(encodedQuery)") {
            prices.append(PriceInfo(
                retailer: "Walmart",
                price: nil,
                currency: "USD",
                priceDisplay: "Search Walmart",
                url: walmartURL,
                availability: availabilityMessage,
                shipping: nil
            ))
        }
        
        // Target search link
        if let targetURL = URL(string: "https://www.target.com/s?searchTerm=\(encodedQuery)") {
            prices.append(PriceInfo(
                retailer: "Target",
                price: nil,
                currency: "USD",
                priceDisplay: "Search Target",
                url: targetURL,
                availability: availabilityMessage,
                shipping: nil
            ))
        }
        
        // Try to get actual price from Open Food Facts if it's a food product
        if let offPrice = await fetchOpenFoodFactsPrice(barcode: barcode) {
            prices.insert(offPrice, at: 0)
        }
        
        return prices
    }
    
    // Open Food Facts sometimes has price data
    private func fetchOpenFoodFactsPrice(barcode: String) async -> PriceInfo? {
        // Note: Open Food Facts doesn't consistently have price data,
        // but when available it's in the product data
        // This is a placeholder for potential price extraction
        return nil
    }
}

// MARK: - Enhanced Price Service with Open Product Data

actor EnhancedPriceService {
    
    // Use Open Product Data API (free, community-driven price database)
    func lookupProductPrices(barcode: String) async -> [PriceInfo] {
        var prices: [PriceInfo] = []
        
        // Try Open Product Data
        if let opdPrices = try? await fetchOpenProductData(barcode: barcode) {
            prices.append(contentsOf: opdPrices)
        }
        
        // Fallback to search links if no prices found
        if prices.isEmpty {
            prices = await PriceLookupService().lookupPrices(barcode: barcode, productName: nil)
        }
        
        return prices
    }
    
    private func fetchOpenProductData(barcode: String) async throws -> [PriceInfo] {
        // Open Product Data is a community project - implementation would go here
        // For now, returning empty to avoid API calls to non-existent service
        return []
    }
}

// MARK: - Price Comparison Helper

struct PriceComparison {
    let lowestPrice: PriceInfo?
    let highestPrice: PriceInfo?
    let averagePrice: Double?
    let priceRange: String?
    
    static func compare(prices: [PriceInfo]) -> PriceComparison {
        let pricesWithValues = prices.compactMap { info -> (PriceInfo, Double)? in
            guard let price = info.price else { return nil }
            return (info, price)
        }
        
        guard !pricesWithValues.isEmpty else {
            return PriceComparison(lowestPrice: nil, highestPrice: nil, averagePrice: nil, priceRange: nil)
        }
        
        let sortedPrices = pricesWithValues.sorted { $0.1 < $1.1 }
        let lowest = sortedPrices.first?.0
        let highest = sortedPrices.last?.0
        
        let sum = pricesWithValues.reduce(0.0) { $0 + $1.1 }
        let average = sum / Double(pricesWithValues.count)
        
        let range: String?
        if let low = sortedPrices.first?.1, let high = sortedPrices.last?.1 {
            range = String(format: "$%.2f - $%.2f", low, high)
        } else {
            range = nil
        }
        
        return PriceComparison(
            lowestPrice: lowest,
            highestPrice: highest,
            averagePrice: average,
            priceRange: range
        )
    }
}
