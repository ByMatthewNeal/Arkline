# ArkLine Feature Backlog

## High Priority

### Upgrade to Santiment Paid Tier
**Status:** Desired
**Date Added:** February 2, 2026

**Description:**
Upgrade from Santiment free tier to paid (Max - $249/mo) to get real-time BTC Supply in Profit data instead of 30-day lagged data.

**Benefits:**
- Real-time data (no 30-day lag)
- 2 years of historical data (vs ~11 months on free)
- Better user experience with current values

**Consideration:**
Before upgrading, evaluate if storing received data on backend could reduce costs by building our own historical database over time.

---

### Store Supply in Profit Data on Backend
**Status:** Implemented
**Date Added:** February 2, 2026
**Date Completed:** February 2, 2026
**Priority:** High (do before paying for Santiment)

**Description:**
Store BTC Supply in Profit data on Supabase as we receive it from Santiment. This builds our own historical database over time.

**Benefits:**
- Build historical database for free over time
- Reduce API dependency on Santiment
- Share data across all users (fetch once from Santiment, serve many from Supabase)
- Eventually could remove need for paid Santiment tier
- Data persists even if Santiment changes pricing/availability

**Implementation (Completed):**
1. ✅ Created `supply_in_profit` table enum in `SupabaseClient.swift`
2. ✅ Created `SupplyProfitDTO` model in `SupplyProfitData.swift`
3. ✅ Added database helper functions in `SupabaseDatabase.swift`:
   - `saveSupplyInProfitData()` - stores new data points
   - `getSupplyInProfitData()` - fetches from Supabase
   - `getLatestSupplyInProfitData()` - gets most recent entry
   - `getExistingSupplyInProfitDates()` - checks what dates exist
4. ✅ Modified `APISantimentService.swift` to:
   - Check Supabase first for existing data
   - Fetch only missing dates from Santiment API
   - Store new data points to Supabase automatically
   - Return combined data to the app

**Data Flow:**
```
Request → Check Supabase → Missing dates? → Fetch Santiment → Store to Supabase → Return combined
```

**Schema (create in Supabase dashboard):**
```sql
create table supply_in_profit (
  id uuid primary key default gen_random_uuid(),
  date date unique not null,
  value decimal not null,
  created_at timestamp default now()
);
```

**Note:** You need to create the table in the Supabase dashboard before data will be stored

---

## Medium Priority

*(Add future feature requests here)*

---

## Low Priority

*(Add future feature requests here)*

---

## Completed

### Bitcoin Supply in Profit Widget
**Status:** Implemented
**Date Added:** January 31, 2026
**Date Completed:** February 1, 2026
**Reference:** [Into The Cryptoverse](https://intothecryptoverse.com)

**Implementation:**
- Uses Santiment free GraphQL API (`percent_of_total_supply_in_profit` metric)
- Widget shows current % of BTC supply in profit with color-coded signals
- Detail view includes 90-day historical chart with interactive selection
- Signal interpretation:
  - Below 50%: Buy Zone (green) - historically marks bottoms
  - 50-85%: Normal (blue)
  - 85-97%: Elevated (orange) - late cycle
  - Above 97%: Overheated (red) - potential correction

**Files Created:**
- `Domain/Models/SupplyProfitData.swift`
- `Data/Services/Protocols/SantimentServiceProtocol.swift`
- `Data/Services/API/APISantimentService.swift`
- `Data/Services/Mock/MockSantimentService.swift`
- `Features/Home/Views/SupplyInProfitWidget.swift`

**Data Sources:**
- **Recent data**: Santiment free API (~30-day lag, automatic)
- **Historical data**: Static estimates for cycle context (2012-2025)

**Known Limitations:**
- Santiment free tier has ~30-day data lag
- For real-time data, Santiment Max costs $249/mo
- Widget shows "As of [date]" to be transparent about data freshness

**Future Enhancements:**
- Add BTC price overlay on chart
- Add alerts for extreme readings (below 50% or above 97%)
- Consider Santiment paid tier if real-time data becomes critical
