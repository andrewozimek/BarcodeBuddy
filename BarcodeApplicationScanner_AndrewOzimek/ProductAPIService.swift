import Foundation

// MARK: - Enhanced Product Model with Multiple Database Support

struct EnhancedProduct {
    // Basic product info
    let barcode: String
    let productName: String?
    let brand: String?
    let category: String?
    let imageURL: URL?
    
    // Nutrition from Open Food Facts
    let offNutrition: OFFNutriments?
    
    // Additional food details
    let ingredients: String?
    let allergens: [String]?
    let servingSize: String?
    let servingsPerContainer: String?
    
    // UPC Database info
    let description: String?
    let manufacturer: String?
    
    // Quality scores
    let nutriScore: String?  // A-E rating from Open Food Facts
    let novaGroup: Int?      // 1-4 (food processing level)
    
    // Source tracking
    let dataSources: [String]
}

// MARK: - UPC Database API Client (UPCitemdb.com - Free tier available)

nonisolated struct UPCDatabaseResponse: Decodable {
    let code: String?
    let total: Int?
    let items: [UPCItem]?
}

nonisolated struct UPCItem: Decodable {
    let ean: String?
    let title: String?
    let description: String?
    let brand: String?
    let category: String?
    let images: [String]?
}

actor UPCDatabaseClient {
    // Free tier - no API key required for basic lookups
    func fetchProduct(for barcode: String) async throws -> UPCItem? {
        let urlString = "https://api.upcitemdb.com/prod/trial/lookup?upc=\(barcode)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(UPCDatabaseResponse.self, from: data)
        return result.items?.first
    }
}

// MARK: - Barcode Lookup API Client (Alternative/Fallback)

nonisolated struct BarcodeLookupResponse: Decodable {
    let products: [BarcodeLookupProduct]?
}

nonisolated struct BarcodeLookupProduct: Decodable {
    let barcode_number: String?
    let product_name: String?
    let title: String?
    let brand: String?
    let manufacturer: String?
    let category: String?
    let description: String?
    let images: [String]?
}

actor BarcodeLookupClient {
    // Note: This API requires an API key - users would need to sign up at barcodelookup.com
    // Keeping it here for when they want to add their own key
    private let apiKey: String?
    
    init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
    
    func fetchProduct(for barcode: String) async throws -> BarcodeLookupProduct? {
        guard let apiKey = apiKey else { return nil }
        
        let urlString = "https://api.barcodelookup.com/v3/products?barcode=\(barcode)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(BarcodeLookupResponse.self, from: data)
        return result.products?.first
    }
}

// MARK: - Unified Product Lookup Service

actor ProductLookupService {
    private let offClient = OpenFoodFactsClient()
    private let upcClient = UPCDatabaseClient()
    private let barcodeLookupClient: BarcodeLookupClient
    
    init(barcodeLookupAPIKey: String? = nil) {
        self.barcodeLookupClient = BarcodeLookupClient(apiKey: barcodeLookupAPIKey)
    }
    
    // Query all available databases and combine results
    func lookupProduct(barcode: String) async -> EnhancedProduct {
        var dataSources: [String] = []
        
        // Try Open Food Facts first (best for food products)
        let offProduct = try? await offClient.fetchProduct(for: barcode)
        if offProduct != nil {
            dataSources.append("Open Food Facts")
        }
        
        // Try UPC Database (free, good general coverage)
        let upcProduct = try? await upcClient.fetchProduct(for: barcode)
        if upcProduct != nil {
            dataSources.append("UPC Database")
        }
        
        // Try Barcode Lookup (if API key is available)
        let blProduct = try? await barcodeLookupClient.fetchProduct(for: barcode)
        if blProduct != nil {
            dataSources.append("Barcode Lookup")
        }
        
        // Combine all data sources - prefer more complete/reliable sources
        let productName = offProduct?.productName 
                       ?? upcProduct?.title 
                       ?? blProduct?.product_name 
                       ?? blProduct?.title
        
        let brand = offProduct?.brands 
                 ?? upcProduct?.brand 
                 ?? blProduct?.brand
        
        let category = upcProduct?.category 
                    ?? blProduct?.category
        
        let description = upcProduct?.description 
                       ?? blProduct?.description
        
        let manufacturer = blProduct?.manufacturer
        
        let imageURL: URL? = {
            if let urlString = upcProduct?.images?.first ?? blProduct?.images?.first {
                return URL(string: urlString)
            }
            return nil
        }()
        
        // Extract enhanced Open Food Facts data
        let ingredients = extractIngredients(from: offProduct)
        let allergens = extractAllergens(from: offProduct)
        let nutriScore = extractNutriScore(from: offProduct)
        let novaGroup = extractNovaGroup(from: offProduct)
        
        return EnhancedProduct(
            barcode: barcode,
            productName: productName,
            brand: brand,
            category: category,
            imageURL: imageURL,
            offNutrition: offProduct?.nutriments,
            ingredients: ingredients,
            allergens: allergens,
            servingSize: nil,  // Could be extracted from OFF if available
            servingsPerContainer: nil,
            description: description,
            manufacturer: manufacturer,
            nutriScore: nutriScore,
            novaGroup: novaGroup,
            dataSources: dataSources
        )
    }
    
    private func extractIngredients(from product: OFFProduct?) -> String? {
        // Open Food Facts can provide ingredients - would need to extend OFFProduct model
        // For now, returning nil - can be added when extending the OFF model
        return nil
    }
    
    private func extractAllergens(from product: OFFProduct?) -> [String]? {
        // Open Food Facts provides allergen info - would need to extend OFFProduct model
        return nil
    }
    
    private func extractNutriScore(from product: OFFProduct?) -> String? {
        // Open Food Facts provides Nutri-Score (A-E rating)
        // Would need to extend OFFProduct model to include this field
        return nil
    }
    
    private func extractNovaGroup(from product: OFFProduct?) -> Int? {
        // Open Food Facts provides NOVA group (1-4 food processing classification)
        // Would need to extend OFFProduct model to include this field
        return nil
    }
}

// MARK: - Extended Open Food Facts Models (for additional data)

// Extended OFFProduct to include more fields available from the API
extension OFFProduct {
    // These fields are available from Open Food Facts API but not currently in our model
    // Uncomment and add to OFFProduct struct when needed:
    
    // let ingredients_text: String?
    // let allergens: String?
    // let allergens_tags: [String]?
    // let nutriscore_grade: String?
    // let nova_group: Int?
    // let ecoscore_grade: String?
    // let image_url: String?
    // let serving_size: String?
    // let categories: String?
    // let categories_tags: [String]?
}
