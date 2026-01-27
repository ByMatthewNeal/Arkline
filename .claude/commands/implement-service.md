# Arkline Service Implementation Agent

You help complete unimplemented API services in the Arkline codebase. Many services currently throw `AppError.notImplemented`.

## Unimplemented Services

### APIDCAService.swift (46+ methods)
**Location:** `/ArkLine/Data/Services/API/APIDCAService.swift`

All database operations need Supabase integration:
- `fetchReminders()` - Get user's DCA reminders
- `createReminder()` - Create new DCA reminder
- `updateReminder()` - Update existing reminder
- `deleteReminder()` - Remove reminder
- `fetchDCAHistory()` - Get DCA transaction history
- Risk-based DCA methods (lines 83-172)

**Supabase Tables Expected:**
- `dca_reminders` - Stores reminder configurations
- `dca_transactions` - Stores executed DCA purchases

### APIPortfolioService.swift (13 methods)
**Location:** `/ArkLine/Data/Services/API/APIPortfolioService.swift`

Portfolio operations:
- `fetchPortfolios()` - Get user's portfolios
- `createPortfolio()` - Create new portfolio
- `updatePortfolio()` - Update portfolio settings
- `deletePortfolio()` - Remove portfolio
- `addHolding()` - Add asset to portfolio
- `updateHolding()` - Update holding quantity/cost basis
- `removeHolding()` - Remove asset from portfolio
- `fetchTransactions()` - Get transaction history
- `addTransaction()` - Record buy/sell transaction

**Supabase Tables Expected:**
- `portfolios` - Portfolio metadata
- `holdings` - Current holdings per portfolio
- `transactions` - Buy/sell transaction history

### OnboardingViewModel.swift:246
**Feature:** Profile picture upload to Supabase Storage

### SettingsView.swift:799,862
**Features:**
- Passcode change flow
- Sign out from all devices

## Implementation Pattern

Follow the existing service patterns:

```swift
final class APIDCAService: DCAServiceProtocol {
    private let supabase: SupabaseClient

    init() {
        self.supabase = SupabaseManager.shared.client
    }

    func fetchReminders() async throws -> [DCAReminder] {
        guard let userId = try await supabase.auth.session.user.id else {
            throw AppError.unauthorized
        }

        let response: [DCAReminder] = try await supabase
            .from("dca_reminders")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    func createReminder(_ reminder: DCAReminder) async throws -> DCAReminder {
        guard let userId = try await supabase.auth.session.user.id else {
            throw AppError.unauthorized
        }

        var newReminder = reminder
        newReminder.userId = userId

        let response: DCAReminder = try await supabase
            .from("dca_reminders")
            .insert(newReminder)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    // ... more methods
}
```

## Model Requirements

Ensure models conform to `Codable` and match Supabase schema:

```swift
struct DCAReminder: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var assetId: String
    var assetName: String
    var amount: Double
    var frequency: DCAFrequency
    var dayOfWeek: Int?
    var dayOfMonth: Int?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case assetId = "asset_id"
        case assetName = "asset_name"
        case amount
        case frequency
        case dayOfWeek = "day_of_week"
        case dayOfMonth = "day_of_month"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

## Supabase SQL Schema (Reference)

If tables don't exist, suggest this schema:

```sql
-- DCA Reminders
CREATE TABLE dca_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    asset_id TEXT NOT NULL,
    asset_name TEXT NOT NULL,
    amount DECIMAL(18,8) NOT NULL,
    frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'biweekly', 'monthly')),
    day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
    day_of_month INTEGER CHECK (day_of_month BETWEEN 1 AND 31),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Row Level Security
ALTER TABLE dca_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own reminders"
ON dca_reminders FOR ALL
USING (auth.uid() = user_id);
```

## Workflow

1. Ask which service to implement
2. Read the protocol definition to understand required methods
3. Check existing model structures
4. Propose Supabase table schema if needed
5. Implement methods one at a time with user approval
6. Ensure proper error handling and RLS compliance
