-- Arkline Dictionary: investing terms glossary
-- Admin can add/edit/delete. All authenticated users can read.

CREATE TABLE IF NOT EXISTS public.dictionary (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  term TEXT NOT NULL,
  definition TEXT NOT NULL,
  category TEXT,                    -- "crypto", "macro", "technical", "trading", "risk", "general"
  example TEXT,                     -- optional usage example
  related_terms TEXT[],             -- array of related term names
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  UNIQUE(term)
);

CREATE INDEX IF NOT EXISTS idx_dictionary_term ON dictionary(term);
CREATE INDEX IF NOT EXISTS idx_dictionary_category ON dictionary(category);

ALTER TABLE dictionary ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read
CREATE POLICY "dictionary_read" ON dictionary FOR SELECT TO authenticated USING (true);

-- Only admins can write
CREATE POLICY "dictionary_insert" ON dictionary FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "dictionary_update" ON dictionary FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "dictionary_delete" ON dictionary FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_dictionary_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER dictionary_updated_at
  BEFORE UPDATE ON dictionary
  FOR EACH ROW
  EXECUTE FUNCTION update_dictionary_timestamp();

-- Seed with essential investing terms
INSERT INTO dictionary (term, definition, category, example, related_terms) VALUES
  ('DCA', 'Dollar-Cost Averaging. An investment strategy where you invest a fixed amount at regular intervals, regardless of price. This reduces the impact of volatility on your overall purchase.', 'trading', 'Instead of buying $10,000 of BTC at once, you invest $500 every week for 20 weeks.', ARRAY['Lump Sum', 'Accumulation']),
  ('Bull Market', 'A market condition where prices are rising or expected to rise. Characterized by optimism, investor confidence, and expectations of continued strong results.', 'general', 'Bitcoin entered a bull market after breaking above its previous all-time high.', ARRAY['Bear Market', 'Rally', 'Uptrend']),
  ('Bear Market', 'A market condition where prices fall 20% or more from recent highs. Associated with widespread pessimism and negative sentiment.', 'general', 'The 2022 crypto winter was a bear market — BTC fell from $69K to $15K.', ARRAY['Bull Market', 'Correction', 'Capitulation']),
  ('RSI', 'Relative Strength Index. A momentum indicator (0-100) that measures the speed and magnitude of price changes. Above 70 = overbought, below 30 = oversold.', 'technical', 'BTC''s RSI hit 28, suggesting it was oversold and due for a bounce.', ARRAY['Overbought', 'Oversold', 'Momentum']),
  ('SMA', 'Simple Moving Average. The average price over a specific number of periods. Common SMAs: 21-day (short-term), 50-day (medium), 200-day (long-term trend).', 'technical', 'BTC trading above its 200-day SMA is generally considered bullish.', ARRAY['EMA', 'Golden Cross', 'Death Cross']),
  ('Support', 'A price level where buying pressure historically prevents the price from falling further. Think of it as a floor.', 'technical', 'BTC found support at $68,000 — every time it dropped there, buyers stepped in.', ARRAY['Resistance', 'Fibonacci', 'Breakout']),
  ('Resistance', 'A price level where selling pressure historically prevents the price from rising further. Think of it as a ceiling.', 'technical', 'BTC struggled to break above $75,000 resistance for three weeks.', ARRAY['Support', 'Breakout', 'All-Time High']),
  ('Fibonacci Retracement', 'A technical tool that uses horizontal lines at key ratios (23.6%, 38.2%, 50%, 61.8%, 78.6%) to identify potential support/resistance levels after a price move.', 'technical', 'After rallying from $60K to $80K, BTC pulled back to the 61.8% Fibonacci level at $67,600.', ARRAY['Golden Pocket', 'Support', 'Resistance']),
  ('Golden Pocket', 'The zone between the 61.8% and 78.6% Fibonacci retracement levels. Considered the highest-probability reversal zone in technical analysis.', 'technical', 'The Arkline signal system looks for price entries in the golden pocket zone.', ARRAY['Fibonacci Retracement', 'Support', 'Entry Zone']),
  ('VIX', 'The CBOE Volatility Index, often called the "fear gauge." Measures expected volatility in the S&P 500. High VIX (>30) = fear/uncertainty, Low VIX (<15) = complacency.', 'macro', 'VIX spiked to 35 during the selloff, signaling extreme fear in equity markets.', ARRAY['Volatility', 'Fear & Greed', 'Risk-Off']),
  ('DXY', 'The US Dollar Index. Measures the dollar''s value against a basket of major currencies. A rising DXY is typically negative for risk assets like crypto and stocks.', 'macro', 'DXY fell 2% this month, providing a tailwind for Bitcoin and gold.', ARRAY['USD', 'Liquidity', 'Risk-On']),
  ('Risk-On', 'A market environment where investors are willing to take on more risk. Money flows into growth stocks, crypto, and speculative assets.', 'macro', 'With inflation cooling and the Fed pausing hikes, markets shifted to a risk-on posture.', ARRAY['Risk-Off', 'Bull Market', 'Liquidity']),
  ('Risk-Off', 'A market environment where investors reduce risk exposure. Money flows into safe havens like bonds, gold, and cash.', 'macro', 'Geopolitical tensions triggered a risk-off move — crypto and stocks sold off while gold rallied.', ARRAY['Risk-On', 'Bear Market', 'Safe Haven']),
  ('Liquidity', 'The amount of money available in the financial system. More liquidity generally supports higher asset prices. Central banks control liquidity through monetary policy.', 'macro', 'Global M2 money supply expansion has historically preceded Bitcoin rallies.', ARRAY['M2', 'Fed', 'QE', 'QT']),
  ('Stop Loss', 'A predetermined price level at which you exit a trade to limit losses. Essential for risk management.', 'trading', 'I set my stop loss at $67,500 — if BTC drops there, my position automatically closes.', ARRAY['Take Profit', 'Risk-Reward', 'Position Size']),
  ('Risk-Reward Ratio', 'The ratio of potential profit to potential loss on a trade. A 2:1 R:R means you stand to make $2 for every $1 you risk.', 'trading', 'This setup has a 3:1 risk-reward — the target is $3,000 above entry and the stop is $1,000 below.', ARRAY['Stop Loss', 'Take Profit', 'Position Size']),
  ('Leverage', 'Using borrowed funds to increase position size beyond your capital. 10x leverage means a 1% price move equals a 10% gain or loss on your capital.', 'trading', 'At 10x leverage, a 10% drop in BTC would liquidate your entire position.', ARRAY['Liquidation', 'Margin', 'Position Size']),
  ('Liquidation', 'When a leveraged position is forcibly closed because losses exceed the margin (collateral). The exchange sells your position to cover the borrowed funds.', 'trading', 'BTC''s flash crash caused $500M in liquidations across exchanges.', ARRAY['Leverage', 'Margin Call', 'Stop Loss']),
  ('All-Time High', 'The highest price an asset has ever reached. Often abbreviated as ATH.', 'general', 'Bitcoin hit a new all-time high of $83,000 in April 2026.', ARRAY['Bull Market', 'Resistance', 'Breakout']),
  ('Fear & Greed Index', 'A sentiment indicator (0-100) that measures market emotions. 0 = Extreme Fear, 100 = Extreme Greed. Extreme fear can signal buying opportunities, extreme greed can signal tops.', 'macro', 'Fear & Greed dropped to 12 (Extreme Fear) — historically a contrarian buy signal.', ARRAY['Sentiment', 'Contrarian', 'VIX']),
  ('Altcoin', 'Any cryptocurrency other than Bitcoin. Includes Ethereum, Solana, and thousands of smaller tokens.', 'crypto', 'During alt season, altcoins tend to outperform Bitcoin as risk appetite increases.', ARRAY['Bitcoin Dominance', 'Alt Season', 'Market Cap']),
  ('Market Cap', 'The total value of all coins in circulation. Calculated as: current price × circulating supply. Used to rank and compare cryptocurrencies.', 'crypto', 'Solana''s market cap surpassed $50 billion, making it the 4th largest crypto.', ARRAY['Circulating Supply', 'Fully Diluted Valuation']),
  ('Whale', 'An individual or entity that holds a very large amount of a cryptocurrency. Whale movements can significantly impact prices.', 'crypto', 'A whale moved 10,000 BTC to an exchange — a potential signal of selling pressure.', ARRAY['Accumulation', 'Distribution', 'On-Chain']),
  ('HODL', 'A misspelling of "hold" that became crypto slang for holding an asset long-term regardless of short-term price drops.', 'crypto', 'Despite the 40% crash, HODLers who didn''t sell were profitable within 6 months.', ARRAY['DCA', 'Diamond Hands', 'Long-Term'])
ON CONFLICT (term) DO NOTHING;
