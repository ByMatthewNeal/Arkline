import Foundation

// MARK: - Transaction Model
struct Transaction: Codable, Identifiable, Equatable {
    let id: UUID
    let portfolioId: UUID
    var holdingId: UUID?
    var type: TransactionType
    var assetType: String
    var symbol: String
    var quantity: Double
    var pricePerUnit: Double
    var gasFee: Double
    var totalValue: Double
    var transactionDate: Date
    var notes: String?
    var emotionalState: EmotionalState?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case portfolioId = "portfolio_id"
        case holdingId = "holding_id"
        case type
        case assetType = "asset_type"
        case symbol
        case quantity
        case pricePerUnit = "price_per_unit"
        case gasFee = "gas_fee"
        case totalValue = "total_value"
        case transactionDate = "transaction_date"
        case notes
        case emotionalState = "emotional_state"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        portfolioId: UUID,
        holdingId: UUID? = nil,
        type: TransactionType,
        assetType: String,
        symbol: String,
        quantity: Double,
        pricePerUnit: Double,
        gasFee: Double = 0,
        transactionDate: Date = Date(),
        notes: String? = nil,
        emotionalState: EmotionalState? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.holdingId = holdingId
        self.type = type
        self.assetType = assetType
        self.symbol = symbol
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.gasFee = gasFee
        self.totalValue = (quantity * pricePerUnit) + gasFee
        self.transactionDate = transactionDate
        self.notes = notes
        self.emotionalState = emotionalState
        self.createdAt = createdAt
    }
}

// MARK: - Emotional State
enum EmotionalState: String, Codable, CaseIterable {
    case confident
    case fearful
    case excited
    case anxious
    case fomo
    case calm
    case uncertain
    case greedy

    var displayName: String {
        switch self {
        case .confident: return "Confident"
        case .fearful: return "Fearful"
        case .excited: return "Excited"
        case .anxious: return "Anxious"
        case .fomo: return "FOMO"
        case .calm: return "Calm"
        case .uncertain: return "Uncertain"
        case .greedy: return "Greedy"
        }
    }

    var icon: String {
        switch self {
        case .confident: return "checkmark.shield.fill"
        case .fearful: return "exclamationmark.triangle.fill"
        case .excited: return "bolt.fill"
        case .anxious: return "waveform.path"
        case .fomo: return "clock.badge.exclamationmark.fill"
        case .calm: return "leaf.fill"
        case .uncertain: return "questionmark.circle.fill"
        case .greedy: return "arrow.up.right.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .confident: return "34C759" // Green
        case .fearful: return "FF3B30" // Red
        case .excited: return "FF9500" // Orange
        case .anxious: return "FF6B6B" // Light red
        case .fomo: return "AF52DE" // Purple
        case .calm: return "5AC8FA" // Light blue
        case .uncertain: return "8E8E93" // Gray
        case .greedy: return "FFD60A" // Yellow
        }
    }
}

// MARK: - Transaction Type
enum TransactionType: String, Codable, CaseIterable {
    case buy
    case sell
    case transferIn = "transfer_in"
    case transferOut = "transfer_out"

    var displayName: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        case .transferIn: return "Transfer In"
        case .transferOut: return "Transfer Out"
        }
    }

    var icon: String {
        switch self {
        case .buy: return "arrow.down.circle.fill"
        case .sell: return "arrow.up.circle.fill"
        case .transferIn: return "arrow.right.circle.fill"
        case .transferOut: return "arrow.left.circle.fill"
        }
    }

    var isIncoming: Bool {
        self == .buy || self == .transferIn
    }
}

// MARK: - Transaction Extensions
extension Transaction {
    var formattedTotal: String {
        totalValue.asCurrency
    }

    var formattedPrice: String {
        pricePerUnit.asCryptoPrice
    }

    var formattedQuantity: String {
        quantity.asQuantity
    }

    var formattedDate: String {
        transactionDate.displayDateTime
    }

    var signedQuantity: Double {
        type.isIncoming ? quantity : -quantity
    }
}

// MARK: - Create Transaction Request
struct CreateTransactionRequest: Encodable {
    let portfolioId: UUID
    let holdingId: UUID?
    let type: String
    let assetType: String
    let symbol: String
    let quantity: Double
    let pricePerUnit: Double
    let gasFee: Double
    let totalValue: Double
    let transactionDate: Date
    let notes: String?
    let emotionalState: String?

    enum CodingKeys: String, CodingKey {
        case portfolioId = "portfolio_id"
        case holdingId = "holding_id"
        case type
        case assetType = "asset_type"
        case symbol
        case quantity
        case pricePerUnit = "price_per_unit"
        case gasFee = "gas_fee"
        case totalValue = "total_value"
        case transactionDate = "transaction_date"
        case notes
        case emotionalState = "emotional_state"
    }
}

// MARK: - Transaction Summary
struct TransactionSummary {
    let totalBought: Double
    let totalSold: Double
    let totalTransfersIn: Double
    let totalTransfersOut: Double
    let totalFees: Double
    let transactionCount: Int

    var netFlow: Double {
        totalBought + totalTransfersIn - totalSold - totalTransfersOut
    }
}
