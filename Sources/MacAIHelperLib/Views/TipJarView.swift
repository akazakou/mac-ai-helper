// TipJarView.swift
// Presents a window with voluntary tip options for supporting the developer.
// Uses StoreKit 2 consumable products loaded via TipJarService.

import StoreKit
import SwiftUI

/// Tip jar window content with description text and purchase buttons.
struct TipJarView: View {
    @State private var tipJarService = TipJarService()

    /// Called when the user taps the Close button
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header icon
            Image(systemName: "heart.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 48))
                .foregroundStyle(.pink)

            Text("Tip Developer")
                .font(.title2.bold())

            // Description text
            Text("""
            If you enjoy using this app and would like to support its continued \
            development, you can leave a voluntary tip.
            Tips are optional and do not unlock any features or change the \
            functionality of the app.
            """)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Tip buttons
            tipButtonsSection

            Divider()

            // Status message
            statusView

            // Close button
            Button("Close") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 380)
        .task {
            await tipJarService.loadProducts()
        }
    }

    // MARK: - Tip Buttons

    @ViewBuilder
    private var tipButtonsSection: some View {
        if tipJarService.isLoadingProducts {
            ProgressView("Loading prices…")
                .frame(height: 44)
        } else if tipJarService.products.isEmpty {
            Text("Tip options are currently unavailable.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(height: 44)
        } else {
            HStack(spacing: 12) {
                ForEach(tipJarService.products, id: \.id) { product in
                    Button {
                        Task {
                            await tipJarService.purchase(product)
                        }
                    } label: {
                        Text(product.displayPrice)
                            .font(.headline)
                            .frame(minWidth: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isPurchasing)
                }
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        switch tipJarService.purchaseState {
        case .idle:
            EmptyView()

        case .purchasing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Processing…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .success:
            Label("Thank you for your support! ❤️", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    /// Whether a purchase is currently in progress
    private var isPurchasing: Bool {
        if case .purchasing = tipJarService.purchaseState { return true }
        return false
    }
}
