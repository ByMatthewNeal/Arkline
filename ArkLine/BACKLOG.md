# ArkLine Feature Backlog

## High Priority

### Bitcoin Supply in Profit/Loss Chart
**Status:** Research Complete
**Date Added:** January 31, 2026
**Reference:** [Into The Cryptoverse](https://intothecryptoverse.com)

**Description:**
Chart showing the percentage of Bitcoin supply in profit vs loss, overlaid with BTC price. This is a powerful on-chain indicator where:
- At ATH: 100% supply in profit
- Lines converging (~50%): Historically signals cycle bottoms (buy signal)
- 50D SMA > 97% in profit: Overheated, pullback likely
- 40-50% in profit: Bear market bottom zone

**Data Requirements:**
- On-chain UTXO data showing at what price each Bitcoin last moved
- Requires specialized blockchain analytics

**Potential Data Sources:**
| Provider | Has Metric? | Free API? | Cost |
|----------|-------------|-----------|------|
| Coin Metrics | Yes | Maybe (Community tier) | Free to try |
| Glassnode | Yes | No | ~$800+/mo Professional |
| CryptoQuant | Yes | No | $799/mo Premium |

**Next Steps:**
1. Test Coin Metrics Community API to see if `SplyActPctProfit` metric is available
2. If not available free, consider if worth premium subscription
3. Alternative: Build proxy using other on-chain indicators

---

## Medium Priority

*(Add future feature requests here)*

---

## Low Priority

*(Add future feature requests here)*

---

## Completed

*(Move completed features here)*
