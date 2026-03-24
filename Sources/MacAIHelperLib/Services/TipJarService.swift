// TipJarService.swift
// Manages StoreKit 2 consumable in-app purchases for voluntary developer tips.
// Products are loaded from App Store Connect; purchases are finished immediately
// since tips are consumable and do not unlock any features.

import StoreKit

/// Represents the current state of a tip purchase
enum TipPurchaseState: Sendable {
    case idle
    case purchasing
    case success
    case failed(String)
}

/// Provides tip jar functionality using StoreKit 2 consumable products.
@MainActor
@Observable
final class TipJarService {
    /// All product identifiers for tip amounts
    static let productIDs: [String] = [
        "com.castloud.MacAIHelper.tips.1",
        "com.castloud.MacAIHelper.tips.5",
        "com.castloud.MacAIHelper.tips.10",
        "com.castloud.MacAIHelper.tips.30",
        "com.castloud.MacAIHelper.tips.50",
    ]

    /// Loaded StoreKit products, sorted by price ascending
    var products: [Product] = []

    /// Whether products are currently being loaded
    var isLoadingProducts = false

    /// Current purchase state
    var purchaseState: TipPurchaseState = .idle

    /// Transaction listener task — kept alive to finish pending transactions
    @ObservationIgnored
    private var transactionListenerTask: Task<Void, Never>?

    init() {
        Log.tipjar.info("TipJarService initialized")
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Fetches tip products from the App Store.
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        Log.tipjar.info("Loading tip products for IDs: \(Self.productIDs.joined(separator: ", "))")

        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            Log.tipjar.info("StoreKit returned \(storeProducts.count) product(s)")
            for product in storeProducts {
                Log.tipjar.debug("  Product: \(product.id) — \(product.displayName) — \(product.displayPrice) — type: \(product.type.rawValue)")
            }
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            Log.tipjar.error("Failed to load tip products: \(error)")
            Log.tipjar.error("Error type: \(type(of: error)), description: \(error.localizedDescription)")
            products = []
        }
    }

    // MARK: - Purchasing

    /// Initiates a purchase for the given product.
    func purchase(_ product: Product) async {
        Log.tipjar.info("Initiating purchase for product: \(product.id) (\(product.displayPrice))")
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // Consumable — finish immediately
                await transaction.finish()
                Log.tipjar.info("Purchase successful for product: \(product.id)")
                purchaseState = .success

            case .userCancelled:
                Log.tipjar.info("Purchase cancelled by user for product: \(product.id)")
                purchaseState = .idle

            case .pending:
                // Transaction requires approval (e.g., Ask to Buy)
                Log.tipjar.info("Purchase pending approval for product: \(product.id)")
                purchaseState = .idle

            @unknown default:
                Log.tipjar.warning("Unknown purchase result for product: \(product.id)")
                purchaseState = .idle
            }
        } catch {
            Log.tipjar.error("Purchase failed for product \(product.id): \(error)")
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Transaction Verification

    /// Unwraps a verified transaction or throws if verification failed.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Transaction Listener

    /// Listens for unfinished transactions (e.g., interrupted purchases)
    /// and finishes them automatically.
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await MainActor.run {
                        try self.checkVerified(result)
                    }
                    await transaction.finish()
                } catch {
                    Log.tipjar.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
