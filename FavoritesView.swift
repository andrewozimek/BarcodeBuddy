import SwiftUI

// View for displaying favorite items from the database
struct FavoritesView: View {
    @State private var savedItems: [SavedScannedItem] = []
    @State private var selectedItem: SavedScannedItem? = nil
    @State private var showingDetails = false
    @State private var searchText = ""
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL? = nil
    
    var filteredItems: [SavedScannedItem] {
        var items = savedItems.filter { $0.isFavorite }
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.rawValue.localizedCaseInsensitiveContains(searchText) ||
                (item.productName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if savedItems.filter({ $0.isFavorite }).isEmpty {
                    emptyStateView
                } else if filteredItems.isEmpty {
                    // Show message when filter results in no items
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text("No Results")
                            .font(.title2)
                            .bold()
                        
                        Text("Try a different search term")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            FavoriteItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedItem = item
                                    showingDetails = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        unfavoriteItem(item)
                                    } label: {
                                        Label("Unfavorite", systemImage: "star.slash")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        addToShoppingList(item)
                                    } label: {
                                        Label("Add to Cart", systemImage: "cart.fill.badge.plus")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search favorites")
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        loadItems()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button {
                            exportFavoritesToCSV()
                        } label: {
                            Label("Export to CSV", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button {
                            let favoriteCount = savedItems.filter { $0.isFavorite }.count
                            print("\n" + String(repeating: "=", count: 60))
                            print("⭐ FAVORITES STATISTICS")
                            print(String(repeating: "=", count: 60))
                            print("Total favorites: \(favoriteCount)")
                            print(String(repeating: "=", count: 60) + "\n")
                        } label: {
                            Label("Show Stats", systemImage: "chart.bar")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadItems()
            }
            .sheet(isPresented: $showingDetails) {
                if let item = selectedItem {
                    ScannedDetailsView(item: item.toScannedItem())
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let fileURL = exportFileURL {
                    ShareSheet(fileURL: fileURL)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Favorites Yet")
                .font(.title2)
                .bold()
            
            Text("Tap the star icon on scanned items to add them to favorites")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadItems() {
        savedItems = DatabaseManager.shared.getAllScannedItems()
        print("🔄 FavoritesView loaded \(savedItems.filter { $0.isFavorite }.count) favorites")
    }
    
    private func unfavoriteItem(_ item: SavedScannedItem) {
        withAnimation {
            if DatabaseManager.shared.toggleFavorite(id: item.id) {
                loadItems()
                // Notify other views to refresh
                NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
            }
        }
    }
    
    private func addToShoppingList(_ item: SavedScannedItem) {
        let productName = item.productName ?? item.title
        let brand = item.brand
        let imageUrl = item.imageUrl
        
        if let _ = DatabaseManager.shared.addToShoppingList(
            productName: productName,
            brand: brand,
            barcode: item.rawValue,
            imageUrl: imageUrl,
            scannedItemId: item.id
        ) {
            print("✅ Added to shopping list: \(productName)")
            
            #if os(iOS)
            // Haptic feedback on iOS
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            
            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
        }
    }
    
    // MARK: - CSV Export Functions
    private func exportFavoritesToCSV() {
        let csvContent = CSVExporter.exportFavoritesToCSV(items: savedItems)
        let filename = "Favorites_\(Date().timeIntervalSince1970).csv"
        
        if let fileURL = CSVExporter.saveCSVToFile(csvContent: csvContent, filename: filename) {
            exportFileURL = fileURL
            showingShareSheet = true
        }
    }
}

// Row view for each favorite item
struct FavoriteItemRow: View {
    let item: SavedScannedItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image or icon
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        // Fall back to icon if image fails
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .frame(width: 50, height: 50)
                    @unknown default:
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .frame(width: 50, height: 50)
                    }
                }
            } else {
                // Icon based on item kind when no image
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                
                if let subtitle = displaySubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(formatDate(item.timestamp))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch item.kind {
        case .url: return "link"
        case .upc: return "barcode"
        case .qr: return "qrcode"
        case .text: return "doc.text"
        }
    }
    
    private var displayTitle: String {
        if let productName = item.productName, !productName.isEmpty {
            return productName
        }
        return item.title
    }
    
    private var displaySubtitle: String? {
        if let brand = item.brand, !brand.isEmpty {
            return brand
        }
        return item.subtitle
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
