🚀 Barcode Buddy

Barcode Buddy is a powerful, modern iOS utility designed to bridge the gap between physical products and digital information. Built with SwiftUI and VisionKit, it allows users to scan barcodes and QR codes instantly to retrieve nutrition facts, product details, pricing comparisons, and manage a persistent shopping list.

✨ Key Features

🔍 Advanced Scanning

VisionKit Integration: Leverages Apple's latest DataScannerViewController for high-performance, real-time scanning.

Multi-Format Support: Recognizes UPC-A, UPC-E, EAN-8, EAN-13, QR Codes, and raw URLs.

Simulator Fallback: Includes a DataScannerView fallback to ensure the UI remains functional during development in the Xcode Simulator.

🍎 Product Intelligence

Deep Nutrition Insights: Automatically fetches 100g-based nutrition facts (calories, fats, carbs, proteins, etc.) via the Open Food Facts API.

Global Database Support: Uses UPCitemdb and Barcode Lookup services to identify millions of non-food products.

Quality Scoring: Displays Nutri-Score, NOVA processing groups, and Eco-Scores to help users make healthier choices.

🛒 Shopping & Management

Smart Shopping List: Add scanned items directly to a shopping list with quantity tracking and "checked" status.

Favorites System: Save frequently used products for quick access.

Persistent History: Every scan is saved locally using a robust SQLite implementation, ensuring your data is available offline.

💰 Price Comparison

Instant Lookups: Direct links to compare prices on Amazon, Walmart, Target, and Google Shopping.

📤 Data Portability

CSV Export: Export your entire scan history or just your favorites to a professional CSV file for use in Excel or Google Sheets.

🛠 Tech Stack

UI Framework: SwiftUI

Scanning Engine: VisionKit / AVFoundation

Persistence: SQLite3 (via a custom DatabaseManager wrapper)

Networking: Async/Await with URLSession

APIs: Open Food Facts, UPCitemdb

Design System: Custom theme with animated gradients, glassmorphism, and responsive layouts.

📂 Project Structure

ContentView.swift: The main dashboard and navigation hub.

DatabaseManager.swift: Handles all SQLite operations, table creation, and data persistence.

ProductAPIService.swift: Aggregates data from multiple API providers into a unified EnhancedProduct model.

DesignSystem.swift: Defines the app's visual language, including custom buttons, cards, and animations.

CSVExporter.swift: Logic for generating and sharing CSV data.

ScanHistoryView.swift & FavoritesView.swift: Management interfaces for stored data.

🚀 Getting Started

Prerequisites

Xcode 15.0+

iOS 16.0+ (Device required for camera functionality; Simulator works for UI testing)

Installation

Clone the repository:

git clone [https://github.com/andrewozimek/barcodebuddy.git](https://github.com/andrewozimek/barcodebuddy.git)


Open BarcodeApplicationScanner_AndrewOzimek.xcodeproj in Xcode.

Ensure your signing certificates are configured in the Signing & Capabilities tab.

Build and Run (Cmd + R) on a physical iOS device.

📊 Database Schema

The app uses two main tables:

scanned_items: Stores raw barcode data, fetched nutrition facts, timestamps, and user notes.

shopping_list: Manages items intended for purchase, linked to the scan history for rich metadata.

👨‍💻 Author

Andrew Ozimek Computer Science Student at Quinnipiac University

📜 License

This project is intended for educational and portfolio purposes. Data provided by Open Food Facts is subject to their ODBL license.
