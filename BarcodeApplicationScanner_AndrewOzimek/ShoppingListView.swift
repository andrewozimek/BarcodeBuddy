import SwiftUI

struct ShoppingListView: View {
    @State private var shoppingItems: [ShoppingListItem] = []
    @State private var showingAddItem = false
    @Environment(\.dismiss) private var dismiss
    
    var uncheckedItems: [ShoppingListItem] {
        shoppingItems.filter { !$0.isChecked }
    }
    
    var checkedItems: [ShoppingListItem] {
        shoppingItems.filter { $0.isChecked }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if shoppingItems.isEmpty {
                    EmptyStateView(
                        icon: "cart",
                        title: "Shopping List Empty",
                        message: "Scan products and add them to your shopping list",
                        actionTitle: "Close",
                        action: { dismiss() }
                    )
                } else {
                    List {
                        if !uncheckedItems.isEmpty {
                            Section {
                                ForEach(uncheckedItems) { item in
                                    ShoppingListRow(item: item, onToggle: {
                                        toggleItem(item)
                                    }, onDelete: {
                                        deleteItem(item)
                                    }, onQuantityChange: { newQuantity in
                                        updateQuantity(item, quantity: newQuantity)
                                    })
                                }
                            } header: {
                                Text("To Buy (\(uncheckedItems.count))")
                                    .font(AppTheme.Typography.headline)
                            }
                        }
                        
                        if !checkedItems.isEmpty {
                            Section {
                                ForEach(checkedItems) { item in
                                    ShoppingListRow(item: item, onToggle: {
                                        toggleItem(item)
                                    }, onDelete: {
                                        deleteItem(item)
                                    }, onQuantityChange: { newQuantity in
                                        updateQuantity(item, quantity: newQuantity)
                                    })
                                }
                            } header: {
                                HStack {
                                    Text("Completed (\(checkedItems.count))")
                                        .font(AppTheme.Typography.headline)
                                    Spacer()
                                    Button("Clear All") {
                                        clearCompleted()
                                    }
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.error)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !shoppingItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                clearCompleted()
                            } label: {
                                Label("Clear Completed", systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                clearAll()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                loadItems()
            }
        }
    }
    
    private func loadItems() {
        shoppingItems = DatabaseManager.shared.getShoppingList()
    }
    
    private func toggleItem(_ item: ShoppingListItem) {
        if DatabaseManager.shared.toggleShoppingItemChecked(id: item.id) {
            withAnimation {
                loadItems()
            }
            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
        }
    }
    
    private func deleteItem(_ item: ShoppingListItem) {
        if DatabaseManager.shared.deleteShoppingItem(id: item.id) {
            withAnimation {
                shoppingItems.removeAll { $0.id == item.id }
            }
            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
        }
    }
    
    private func updateQuantity(_ item: ShoppingListItem, quantity: Int) {
        if DatabaseManager.shared.updateShoppingItemQuantity(id: item.id, quantity: quantity) {
            loadItems()
        }
    }
    
    private func clearCompleted() {
        withAnimation {
            for item in checkedItems {
                _ = DatabaseManager.shared.deleteShoppingItem(id: item.id)
            }
            loadItems()
        }
        // Notify other views to refresh
        NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
    }
    
    private func clearAll() {
        withAnimation {
            for item in shoppingItems {
                _ = DatabaseManager.shared.deleteShoppingItem(id: item.id)
            }
            shoppingItems = []
        }
        // Notify other views to refresh
        NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
    }
}

struct ShoppingListRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onQuantityChange: (Int) -> Void
    
    @State private var showingQuantityPicker = false
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isChecked ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Product Image
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                    case .failure, .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .strikethrough(item.isChecked)
                    .opacity(item.isChecked ? 0.6 : 1.0)
                
                if let brand = item.brand {
                    Text(brand)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Quantity Badge
            Button(action: { showingQuantityPicker = true }) {
                Text("×\(item.quantity)")
                    .font(AppTheme.Typography.footnote)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(AppTheme.CornerRadius.pill)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Select Quantity", isPresented: $showingQuantityPicker) {
            ForEach(1..<11) { quantity in
                Button("\(quantity)") {
                    onQuantityChange(quantity)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var placeholderImage: some View {
        Image(systemName: "bag")
            .font(.title2)
            .foregroundColor(AppTheme.Colors.textSecondary)
            .frame(width: 50, height: 50)
            .background(AppTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
    }
}
