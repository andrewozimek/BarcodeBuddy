import SwiftUI

// View for displaying scan history from the database
struct ScanHistoryView: View {
    @State private var savedItems: [SavedScannedItem] = []
    @State private var selectedItem: SavedScannedItem? = nil
    @State private var showingDetails = false
    @State private var searchText = ""
    @State private var showingFavoritesOnly = false
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL? = nil
    
    var filteredItems: [SavedScannedItem] {
        var items = savedItems
        
        // Filter by favorites if toggled
        if showingFavoritesOnly {
            items = items.filter { $0.isFavorite }
        }
        
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
                if savedItems.isEmpty {
                    emptyStateView
                } else if filteredItems.isEmpty {
                    // Show message when filter results in no items
                    VStack(spacing: 20) {
                        Image(systemName: showingFavoritesOnly ? "star.slash" : "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text(showingFavoritesOnly ? "No Favorites Yet" : "No Results")
                            .font(.title2)
                            .bold()
                        
                        Text(showingFavoritesOnly ? "Swipe right on items to add them to favorites" : "Try a different search term")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if showingFavoritesOnly {
                            Button {
                                showingFavoritesOnly = false
                            } label: {
                                Text("Show All Items")
                                    .font(.headline)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            HistoryItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedItem = item
                                    showingDetails = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        toggleFavorite(item)
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: item.isFavorite ? "star.slash.fill" : "star.fill"
                                        )
                                    }
                                    .tint(item.isFavorite ? .gray : .yellow)
                                }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search scans")
                }
            }
            .navigationTitle("Scan History")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        withAnimation {
                            showingFavoritesOnly.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showingFavoritesOnly ? "star.fill" : "star")
                                .foregroundStyle(showingFavoritesOnly ? .yellow : .gray)
                            
                            let favoriteCount = savedItems.filter { $0.isFavorite }.count
                            if favoriteCount > 0 {
                                Text("\(favoriteCount)")
                                    .font(.caption2)
                                    .foregroundStyle(showingFavoritesOnly ? .yellow : .gray)
                            }
                        }
                    }
                }
                
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
                            let path = DatabaseManager.shared.getDatabasePath()
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(path, forType: .string)
                            #else
                            UIPasteboard.general.string = path
                            #endif
                            print("📋 Database path copied to clipboard:")
                            print(path)
                        } label: {
                            Label("Copy Database Path", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            let path = DatabaseManager.shared.getDatabasePath()
                            print("\n" + String(repeating: "=", count: 60))
                            print("📂 DATABASE FILE LOCATION")
                            print(String(repeating: "=", count: 60))
                            print(path)
                            print(String(repeating: "=", count: 60) + "\n")
                        } label: {
                            Label("Print Database Path", systemImage: "printer")
                        }
                        
                        Divider()
                        
                        Button {
                            let items = DatabaseManager.shared.getAllScannedItems()
                            print("\n" + String(repeating: "=", count: 60))
                            print("📊 DATABASE STATISTICS")
                            print(String(repeating: "=", count: 60))
                            print("Total items: \(items.count)")
                            print("Favorites: \(items.filter { $0.isFavorite }.count)")
                            print("UPC/Barcodes: \(items.filter { $0.kind == .upc }.count)")
                            print("QR Codes: \(items.filter { $0.kind == .qr }.count)")
                            print("URLs: \(items.filter { $0.kind == .url }.count)")
                            print("Text: \(items.filter { $0.kind == .text }.count)")
                            print(String(repeating: "=", count: 60) + "\n")
                        } label: {
                            Label("Show Database Stats", systemImage: "chart.bar")
                        }
                        
                        Divider()
                        
                        Button {
                            exportAllToCSV()
                        } label: {
                            Label("Export All to CSV", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            exportFavoritesToCSV()
                        } label: {
                            Label("Export Favorites to CSV", systemImage: "star.square.on.square")
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
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Scans Yet")
                .font(.title2)
                .bold()
            
            Text("Scan items to see them appear here")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadItems() {
        let items = DatabaseManager.shared.getAllScannedItems()
        savedItems = items
        print("🔄 ScanHistoryView loaded \(items.count) items from database")
    }
    
    private func deleteItem(_ item: SavedScannedItem) {
        withAnimation {
            if DatabaseManager.shared.deleteItem(id: item.id) {
                savedItems.removeAll { $0.id == item.id }
            }
        }
    }
    
    private func toggleFavorite(_ item: SavedScannedItem) {
        if DatabaseManager.shared.toggleFavorite(id: item.id) {
            loadItems()
        }
    }
    
    // MARK: - CSV Export Functions
    private func exportAllToCSV() {
        let csvContent = CSVExporter.exportToCSV(items: savedItems)
        let filename = "BarcodeScanHistory_\(Date().timeIntervalSince1970).csv"
        
        if let fileURL = CSVExporter.saveCSVToFile(csvContent: csvContent, filename: filename) {
            exportFileURL = fileURL
            showingShareSheet = true
        }
    }
    
    private func exportFavoritesToCSV() {
        let csvContent = CSVExporter.exportFavoritesToCSV(items: savedItems)
        let filename = "Favorites_\(Date().timeIntervalSince1970).csv"
        
        if let fileURL = CSVExporter.saveCSVToFile(csvContent: csvContent, filename: filename) {
            exportFileURL = fileURL
            showingShareSheet = true
        }
    }
}

// Share Sheet for iOS/macOS
struct ShareSheet: View {
    let fileURL: URL
    
    var body: some View {
        #if os(iOS)
        ShareSheetiOS(fileURL: fileURL)
        #elseif os(macOS)
        ShareSheetMac(fileURL: fileURL)
        #endif
    }
}

#if os(iOS)
struct ShareSheetiOS: UIViewControllerRepresentable {
    let fileURL: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}
#endif

#if os(macOS)
struct ShareSheetMac: View {
    let fileURL: URL
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("CSV File Created!")
                .font(.title2)
                .bold()
            
            Text("File saved to:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(fileURL.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    NSWorkspace.shared.open(fileURL)
                } label: {
                    Label("Open File", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(width: 500, height: 350)
    }
}
#endif

// Row view for each history item
struct HistoryItemRow: View {
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
                            .foregroundStyle(.blue)
                            .frame(width: 50, height: 50)
                    @unknown default:
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 50, height: 50)
                    }
                }
            } else {
                // Icon based on item kind when no image
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
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
