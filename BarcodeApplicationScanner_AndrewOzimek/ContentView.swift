//This is the User Interface. It displays the "Scan Item" button and handles the logic for showing the scanner sheet.


import SwiftUI
struct ContentView: View {
    @State private var resultText = "Scan a product to begin"
    @State private var showingScanner = false
    @State private var selectedItem: ScannedItem? = nil
    @State private var showingShoppingList = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        // Hero Section
                        VStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.accent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, AppTheme.Spacing.xl)
                            
                            Text("Barcode Scanner")
                                .font(AppTheme.Typography.largeTitle)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text(resultText)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, AppTheme.Spacing.lg)
                        
                        // Main Action Card
                        VStack(spacing: AppTheme.Spacing.lg) {
                            Button(action: { showingScanner = true }) {
                                HStack {
                                    Image(systemName: "viewfinder")
                                        .font(.title2)
                                    Text("Scan Barcode")
                                        .font(AppTheme.Typography.title3)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.lg)
                            }
                            .buttonStyle(PrimaryButtonStyle(isLarge: true))
                            
                            // Shopping List Action
                            Button(action: { showingShoppingList = true }) {
                                HStack {
                                    Image(systemName: "cart.fill")
                                        .font(.title2)
                                    Text("Shopping List")
                                        .font(AppTheme.Typography.title3)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.lg)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(AppTheme.Spacing.lg)
                        .cardStyle()
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        
                        // Stats Card
                        StatsCard()
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        
                        Spacer(minLength: AppTheme.Spacing.xxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListView()
            }
        }
        .sheet(isPresented: $showingScanner) {
            ZStack {
#if os(iOS)
    if #available(iOS 16.0, *) {
        #if targetEnvironment(simulator)
        // Use fallback in Simulator (VisionKit not available)
        DataScannerView(scannedCode: $resultText)
        #else
        // Use the real scanner on device
        LegacyDataScannerView(scannedCode: $resultText)
        #endif
    } else {
        // Fallback UI for older iOS versions
        DataScannerView(scannedCode: $resultText)
    }
#else
    // Non-iOS platforms
    DataScannerView(scannedCode: $resultText)
#endif
                // Viewfinder overlay
                viewfinderOverlay
            }
            .onAppear {
                // Reset the last result so onChange fires for the next scan
                resultText = "Scan a product to begin"
            }
        }
        .onChange(of: resultText) { old, newValue in
            // Ignore the initial placeholder
            guard newValue != "Scan a product to begin" else { return }
            
            print("📱 Scan detected: \(newValue)")
            
            // Build a richer model from the scanned string
            let item = ScannedItem.from(scanned: newValue)
            
            print("📦 Item created - Type: \(item.kind.rawValue), Title: \(item.title)")
            
            // Save non-UPC items immediately (UPC items are saved after fetching product info)
            if item.kind != .upc {
                let itemId = DatabaseManager.shared.insertScannedItem(item: item, product: nil)
                print("💾 Non-UPC item saved with ID: \(itemId ?? -1)")
            }
            
            // Dismiss scanner first
            showingScanner = false
            print("✅ Scanner closed")
            
            // Set the selected item - this will automatically trigger the sheet
            // Using a small delay to ensure scanner is fully dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                selectedItem = item
                print("🔍 Showing details for: \(item.title)")
            }
        }
        .sheet(item: $selectedItem) { item in
            ScannedDetailsView(item: item)
        }
    }
    
    private var viewfinderOverlay: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.65
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8, 8]))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                .blendMode(.overlay)
                .position(x: geo.size.width/2, y: geo.size.height/2)
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}
// Lightweight model describing what was scanned
struct ScannedItem: Identifiable {
    let id = UUID()
    let raw: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let actionableURL: URL?

    // Open Food Facts fields (if available)
    var offProduct: OFFProduct? = nil

    enum Kind: String {
        case url = "URL"
        case upc = "UPC/EAN"
        case qr = "QR Code"
        case text = "Text"
    }

    static func from(scanned: String) -> ScannedItem {
        // URL detection
        if let url = URL(string: scanned), url.scheme != nil {
            return ScannedItem(
                raw: scanned,
                kind: .url,
                title: url.host ?? "Link",
                subtitle: url.absoluteString,
                actionableURL: url,
                offProduct: nil
            )
        }
        // Numeric-only barcode heuristic (UPC/EAN)
        let digitsOnly = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNumeric = !digitsOnly.isEmpty && digitsOnly.allSatisfy({ $0.isNumber })
        if isNumeric {
            let query = digitsOnly.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? digitsOnly
            let url = URL(string: "https://www.google.com/search?q=UPC+" + query)
            return ScannedItem(
                raw: scanned,
                kind: .upc,
                title: "Barcode: \(digitsOnly)",
                subtitle: "Tap to look up product details",
                actionableURL: url,
                offProduct: nil
            )
        }
        // Basic QR vs Text classification
        let kind: Kind = scanned.count > 20 ? .qr : .text
        return ScannedItem(
            raw: scanned,
            kind: kind,
            title: scanned,
            subtitle: nil,
            actionableURL: nil,
            offProduct: nil
        )
    }
}

// MARK: - Open Food Facts minimal models & client
nonisolated struct OFFResponse: Decodable {
    let status: Int?
    let product: OFFProduct?
}

nonisolated struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    
    // Extended fields for more product information
    let ingredientsText: String?
    let allergens: String?
    let allergensTags: [String]?
    let nutriscoreGrade: String?
    let novaGroup: Int?
    let ecoscoreGrade: String?
    let imageUrl: String?
    let servingSize: String?
    let categories: String?
    let categoriesTags: [String]?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case ingredientsText = "ingredients_text"
        case allergens
        case allergensTags = "allergens_tags"
        case nutriscoreGrade = "nutriscore_grade"
        case novaGroup = "nova_group"
        case ecoscoreGrade = "ecoscore_grade"
        case imageUrl = "image_url"
        case servingSize = "serving_size"
        case categories
        case categoriesTags = "categories_tags"
    }
}

nonisolated struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let proteins100g: Double?
    let salt100g: Double?
    let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
    }
}

actor OpenFoodFactsClient {
    func fetchProduct(for barcode: String) async throws -> OFFProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("BarcodeScannerApp/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let res = try decoder.decode(OFFResponse.self, from: data)
        return res.product
    }
}

// A simple details sheet presenting richer info and actions
struct ScannedDetailsView: View {
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var enhancedProduct: EnhancedProduct? = nil
    @State private var savedItemId: Int64? = nil
    @State private var isAddedToShoppingList = false

    let item: ScannedItem
    @Environment(\.openURL) private var openURL
    private let client = OpenFoodFactsClient()
    private let productService = ProductLookupService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    
                    // Product Image - show prominently at top
                    productImageSection

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    if isLoading {
                        ProgressView("Fetching nutrition facts…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let message = errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    // Display enhanced product information if available
                    if let enhanced = enhancedProduct {
                        enhancedProductSection(enhanced)
                    }
                    
                    if let product = item.offProduct ?? cachedProduct {
                        nutritionSection(for: product)
                    }
                    
                    if item.kind == .upc {
                        priceEstimatesSection()
                    }
                    
                    // Add to Shopping List Button
                    Button {
                        addToShoppingList()
                    } label: {
                        HStack {
                            Image(systemName: isAddedToShoppingList ? "checkmark.circle.fill" : "cart.fill.badge.plus")
                            Text(isAddedToShoppingList ? "Added to Shopping List!" : "Add to Shopping List")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .disabled(isAddedToShoppingList)

                    if let url = item.actionableURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open in Browser", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal)
                    }

                    GroupBox("Raw Value") {
                        Text(item.raw)
                            .font(.footnote)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                print("🔍 ScannedDetailsView appeared for: \(item.title)")
                print("   - Barcode: \(item.raw)")
                print("   - Type: \(item.kind.rawValue)")
            }
            .task {
                await maybeFetchOFF()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName(for: item.kind))
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.title2)
                        .bold()
                    Text(item.kind.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Show warning if product code doesn't match scanned barcode
            if let product = cachedProduct, 
               let productCode = product.code,
               productCode.trimmingCharacters(in: .whitespacesAndNewlines) != item.raw.trimmingCharacters(in: .whitespacesAndNewlines) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Product info may not match this barcode")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        if let product = item.offProduct ?? cachedProduct, let name = product.productName, !name.isEmpty {
            if let brand = product.brands, !brand.isEmpty {
                return "\(name) — \(brand)"
            }
            return name
        }
        return item.title
    }

    private func maybeFetchOFF() async {
        guard item.kind == .upc else { return }
        // Extract digits from the barcode
        let barcode = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !barcode.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        // Save item to database IMMEDIATELY
        await MainActor.run {
            if savedItemId == nil {
                if let itemId = DatabaseManager.shared.insertScannedItem(item: item, product: nil) {
                    savedItemId = itemId
                    print("✅ Item saved immediately with ID: \(itemId)")
                }
            }
        }
        
        // Use the enhanced product lookup service that queries multiple databases
        let enhanced = await productService.lookupProduct(barcode: barcode)
        self.enhancedProduct = enhanced
        
        // Also try the original OFF API for backward compatibility
        do {
            if let product = try await client.fetchProduct(for: barcode) {
                // Validate that the product code matches what we scanned
                let barcodeMatches = product.code?.trimmingCharacters(in: .whitespacesAndNewlines) == barcode
                
                if barcodeMatches || product.code == nil {
                    // Cache the product for display
                    self.cachedProduct = product
                    
                    // Update existing item with product info
                    await MainActor.run {
                        if let itemId = savedItemId {
                            _ = DatabaseManager.shared.updateScannedItemWithProduct(id: itemId, product: product)
                        }
                    }
                } else {
                    // Product code doesn't match - wrong product returned
                    errorMessage = "Product found but barcode mismatch. Showing barcode only."
                    print("⚠️ Barcode mismatch: Scanned '\(barcode)' but got product with code '\(product.code ?? "nil")'")
                    // Item already saved, no need to do anything
                }
            } else if enhanced.dataSources.isEmpty {
                errorMessage = "No product found in any database."
                // Item already saved, no need to update with empty data
            } else {
                // We have data from other sources, update if we have cached product
                if let product = cachedProduct {
                    await MainActor.run {
                        if let itemId = savedItemId {
                            _ = DatabaseManager.shared.updateScannedItemWithProduct(id: itemId, product: product)
                        }
                    }
                }
            }
        } catch {
            if enhanced.dataSources.isEmpty {
                errorMessage = "Failed to fetch product info from all sources."
            }
            // Item already saved, update if we have cached product
            if let product = cachedProduct {
                await MainActor.run {
                    if let itemId = savedItemId {
                        _ = DatabaseManager.shared.updateScannedItemWithProduct(id: itemId, product: product)
                    }
                }
            }
        }
        isLoading = false
    }

    // Local cache state for the fetched product
    @State private var cachedProduct: OFFProduct? = nil
    
    // MARK: - Shopping List Management
    private func addToShoppingList() {
        let productName = cachedProduct?.productName ?? enhancedProduct?.productName ?? item.title
        let brand = cachedProduct?.brands ?? enhancedProduct?.brand
        let imageUrl = cachedProduct?.imageUrl ?? enhancedProduct?.imageURL?.absoluteString
        
        if let _ = DatabaseManager.shared.addToShoppingList(
            productName: productName,
            brand: brand,
            barcode: item.raw,
            imageUrl: imageUrl,
            scannedItemId: savedItemId
        ) {
            // Show success feedback
            print("✅ Added to shopping list: \(productName)")
            
            // Update state to show success
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAddedToShoppingList = true
            }
            
            #if os(iOS)
            // Haptic feedback on iOS
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            
            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
            
            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isAddedToShoppingList = false
                }
            }
        }
    }

    // MARK: - Product Image Section
    @ViewBuilder
    private var productImageSection: some View {
        // Get image URL from either Open Food Facts or Enhanced Product
        let imageURL: URL? = {
            if let offImageUrl = cachedProduct?.imageUrl, !offImageUrl.isEmpty {
                return URL(string: offImageUrl)
            } else if let enhancedImageURL = enhancedProduct?.imageURL {
                return enhancedImageURL
            }
            return nil
        }()
        
        if let imageURL = imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                case .failure:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - Enhanced Product Information Section
    @ViewBuilder
    private func enhancedProductSection(_ enhanced: EnhancedProduct) -> some View {
        // Show data sources
        if !enhanced.dataSources.isEmpty {
            GroupBox("Data Sources") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(enhanced.dataSources, id: \.self) { source in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(source)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
        // Product details from multiple databases
        if enhanced.category != nil || enhanced.description != nil || enhanced.manufacturer != nil {
            GroupBox("Product Details") {
                VStack(alignment: .leading, spacing: 8) {
                    if let category = enhanced.category {
                        detailRow(label: "Category", value: category)
                    }
                    if let manufacturer = enhanced.manufacturer {
                        detailRow(label: "Manufacturer", value: manufacturer)
                    }
                    if let description = enhanced.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
        // Quality scores (if available from Open Food Facts)
        if let product = cachedProduct {
            if product.nutriscoreGrade != nil || product.novaGroup != nil || product.ecoscoreGrade != nil {
                GroupBox("Quality Scores") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let nutriScore = product.nutriscoreGrade {
                            HStack {
                                Text("Nutri-Score:")
                                    .font(.subheadline)
                                Spacer()
                                Text(nutriScore.uppercased())
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(nutriScoreColor(nutriScore))
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                        }
                        if let nova = product.novaGroup {
                            HStack {
                                Text("NOVA Group:")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(nova)")
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(novaGroupColor(nova))
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                            Text("Processing level: \(novaGroupDescription(nova))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let ecoScore = product.ecoscoreGrade {
                            HStack {
                                Text("Eco-Score:")
                                    .font(.subheadline)
                                Spacer()
                                Text(ecoScore.uppercased())
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(ecoScoreColor(ecoScore))
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        
        // Ingredients and allergens
        if let product = cachedProduct {
            if product.ingredientsText != nil || product.allergens != nil {
                GroupBox("Ingredients & Allergens") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let ingredients = product.ingredientsText {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ingredients")
                                    .font(.subheadline)
                                    .bold()
                                Text(ingredients)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let allergens = product.allergens, !allergens.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allergens")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(.red)
                                Text(allergens)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
        }
    }
    
    private func nutriScoreColor(_ grade: String) -> Color {
        switch grade.lowercased() {
        case "a": return .green
        case "b": return Color(red: 0.5, green: 0.8, blue: 0.2)
        case "c": return .yellow
        case "d": return .orange
        case "e": return .red
        default: return .gray
        }
    }
    
    private func novaGroupColor(_ group: Int) -> Color {
        switch group {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        default: return .gray
        }
    }
    
    private func novaGroupDescription(_ group: Int) -> String {
        switch group {
        case 1: return "Unprocessed or minimally processed"
        case 2: return "Processed culinary ingredients"
        case 3: return "Processed foods"
        case 4: return "Ultra-processed foods"
        default: return "Unknown"
        }
    }
    
    private func ecoScoreColor(_ grade: String) -> Color {
        switch grade.lowercased() {
        case "a": return .green
        case "b": return Color(red: 0.5, green: 0.8, blue: 0.2)
        case "c": return .yellow
        case "d": return .orange
        case "e": return .red
        default: return .gray
        }
    }

    private func nutritionSection(for product: OFFProduct) -> some View {
        GroupBox("Nutrition Facts (per 100g)") {
            VStack(alignment: .leading, spacing: 8) {
                if let name = product.productName, !name.isEmpty {
                    Text(name).bold()
                }
                if let brand = product.brands, !brand.isEmpty {
                    Text("Brand: \(brand)")
                }
                if let n = product.nutriments {
                    nutrientRow(label: "Energy", value: n.energyKcal100g, unit: "kcal")
                    nutrientRow(label: "Fat", value: n.fat100g, unit: "g")
                    nutrientRow(label: "Saturated Fat", value: n.saturatedFat100g, unit: "g")
                    nutrientRow(label: "Carbohydrates", value: n.carbohydrates100g, unit: "g")
                    nutrientRow(label: "Sugars", value: n.sugars100g, unit: "g")
                    nutrientRow(label: "Fiber", value: n.fiber100g, unit: "g")
                    nutrientRow(label: "Protein", value: n.proteins100g, unit: "g")
                    // Prefer salt if available, otherwise show sodium (converted to salt ~ *2.5) or raw sodium
                    if let salt = n.salt100g {
                        nutrientRow(label: "Salt", value: salt, unit: "g")
                    } else if let sodium = n.sodium100g {
                        nutrientRow(label: "Sodium", value: sodium, unit: "g")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            // No additional action needed here, cachedProduct drives display
        }
    }
    
    // MARK: - Price estimates
    @State private var priceInfo: [PriceInfo] = []
    @State private var isLoadingPrices = false
    private let priceService = PriceLookupService()

    @ViewBuilder
    private func priceEstimatesSection() -> some View {
        GroupBox("Where to Buy & Prices") {
            VStack(alignment: .leading, spacing: 12) {
                if isLoadingPrices {
                    ProgressView("Finding retailers…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if priceInfo.isEmpty {
                    Text("No pricing information available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(priceInfo) { info in
                        if let url = info.url {
                            Link(destination: url) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: retailerIcon(info.retailer))
                                            .foregroundStyle(.blue)
                                            .frame(width: 24)
                                        
                                        Text(info.retailer)
                                            .font(.headline)
                                        
                                        Spacer()
                                        
                                        Text(info.priceDisplay)
                                            .font(.headline)
                                            .foregroundStyle(.blue)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if let availability = info.availability {
                                        Text(availability)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            
                            if info.id != priceInfo.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .task {
                await loadPriceInfo()
            }
        }
    }
    
    private func retailerIcon(_ retailer: String) -> String {
        switch retailer.lowercased() {
        case let r where r.contains("amazon"):
            return "shippingbox.fill"
        case let r where r.contains("walmart"):
            return "cart.fill"
        case let r where r.contains("target"):
            return "target"
        case let r where r.contains("google"):
            return "magnifyingglass"
        default:
            return "storefront.fill"
        }
    }

    private func loadPriceInfo() async {
        guard priceInfo.isEmpty, !isLoadingPrices, item.kind == .upc else { return }
        isLoadingPrices = true
        defer { isLoadingPrices = false }
        
        let barcode = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Wait a moment for product data to load if it's still loading
        if cachedProduct == nil && enhancedProduct == nil && isLoading {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
        
        // Get product name and brand from cached product or enhanced product
        let productName = cachedProduct?.productName ?? enhancedProduct?.productName
        let brand = cachedProduct?.brands ?? enhancedProduct?.brand
        
        // Use the price lookup service
        let prices = await priceService.lookupPrices(barcode: barcode, productName: productName, brand: brand)
        
        await MainActor.run {
            self.priceInfo = prices
        }
    }
    
    @ViewBuilder
    private func whereToBuySection() -> some View {
        GroupBox("Where to Buy") {
            VStack(alignment: .leading, spacing: 8) {
                if let google = whereToBuyGoogleURL() {
                    Link(destination: google) {
                        Label("Search on Google Shopping", systemImage: "cart")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let amazon = whereToBuyAmazonURL() {
                    Link(destination: amazon) {
                        Label("Search on Amazon", systemImage: "shippingbox")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func whereToBuyGoogleURL() -> URL? {
        switch item.kind {
        case .upc:
            let q = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let encoded = ("UPC " + q).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.google.com/search?tbm=shop&q=" + encoded)
        case .qr, .text:
            let q = item.title
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.google.com/search?tbm=shop&q=" + encoded)
        case .url:
            return nil
        }
    }

    private func whereToBuyAmazonURL() -> URL? {
        switch item.kind {
        case .upc:
            let q = item.raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.amazon.com/s?k=" + encoded)
        case .qr, .text:
            let q = item.title
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            return URL(string: "https://www.amazon.com/s?k=" + encoded)
        case .url:
            return nil
        }
    }

    private func nutrientRow(label: String, value: Double?, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.map { String(format: "%.1f %@", $0, unit) } ?? "–")
                .foregroundStyle(.secondary)
        }
    }

    private func iconName(for kind: ScannedItem.Kind) -> String {
        switch kind {
        case .url: return "link"
        case .upc: return "barcode"
        case .qr: return "qrcode"
        case .text: return "doc.text"
        }
    }
}

// MARK: - Modern UI Components

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                Text(title)
                    .font(AppTheme.Typography.footnote)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .cardStyle(backgroundColor: AppTheme.Colors.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatsCard: View {
    @State private var shoppingListItems = 0
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Your Shopping List")
                .font(AppTheme.Typography.title3)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: AppTheme.Spacing.md) {
                StatItem(
                    icon: "cart.fill",
                    value: "\(shoppingListItems)",
                    label: "Items To Buy",
                    color: AppTheme.Colors.success
                )
            }
        }
        .padding(AppTheme.Spacing.lg)
        .cardStyle()
        .onAppear {
            loadStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStats"))) { _ in
            loadStats()
        }
    }
    
    private func loadStats() {
        let shoppingList = DatabaseManager.shared.getShoppingList()
        shoppingListItems = shoppingList.filter { !$0.isChecked }.count
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(AppTheme.Typography.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.md)
    }
}

