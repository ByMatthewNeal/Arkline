import Foundation

// MARK: - Asset Risk Configuration
/// Per-asset configuration for risk level calculation.
/// Each asset has unique parameters based on its history and volatility.
/// Supports both crypto and stock assets.
struct AssetRiskConfig {
    // MARK: - Safe Date Helper

    /// Creates a date from year/month/day components safely
    /// Falls back to distant past if creation fails (should never happen for valid dates)
    private static func safeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day).date
            ?? Date.distantPast
    }

    enum AssetType {
        case crypto
        case stock
    }

    /// Asset identifier (symbol like "BTC", "ETH", "AAPL")
    let assetId: String

    /// CoinGecko API ID (e.g., "bitcoin", "ethereum"). Empty for stocks.
    let geckoId: String

    /// Origin date for logarithmic regression (launch date for crypto, IPO date for stocks)
    let originDate: Date

    /// Deviation bounds for risk normalization (log10 scale)
    /// Negative = undervalued, Positive = overvalued
    let deviationBounds: (low: Double, high: Double)

    /// Data confidence level (1-9) based on available history
    /// Higher = more historical data, more reliable regression
    let confidenceLevel: Int

    /// Display name for the asset
    let displayName: String

    /// Binance trading pair symbol (nil if not listed on Binance)
    let binanceSymbol: String?

    /// Asset type — crypto or stock
    let assetType: AssetType

    /// Coinbase trading pair (e.g., "BTC-USD")
    var coinbasePair: String { "\(assetId)-USD" }

    /// Whether this is a stock asset
    var isStock: Bool { assetType == .stock }

    /// Logo URL for any asset (FMP for stocks, CoinGecko for crypto)
    var logoURL: URL? {
        if isStock {
            return URL(string: "https://financialmodelingprep.com/image-stock/\(assetId).png")
        }
        guard let path = Self.cryptoImagePaths[geckoId] else { return nil }
        return URL(string: "https://assets.coingecko.com/coins/images/\(path)")
    }

    /// CoinGecko image paths keyed by geckoId
    private static let cryptoImagePaths: [String: String] = [
        "bitcoin": "1/large/bitcoin.png",
        "ethereum": "279/large/ethereum.png",
        "solana": "4128/large/solana.png",
        "binancecoin": "825/large/bnb-icon2_2x.png",
        "uniswap": "12504/large/uniswap-logo.png",
        "render-token": "11636/large/rndr.png",
        "sui": "26375/large/sui_asset.jpeg",
        "ondo-finance": "26580/large/ONDO.png",
        "bittensor": "28452/large/ARUsPeNQ_400x400.jpeg",
        "zcash": "486/large/circle-zcash-color.png",
        "ripple": "44/large/xrp-symbol-white-128.png",
        "litecoin": "2/standard/litecoin.png",
        "aave": "12645/standard/AAVE.png",
        "ethena": "36530/standard/ethena.png",
        "jupiter-exchange-solana": "34188/large/jup.png",
        "maple-finance": "14097/standard/photo_2021-09-08_03-20-50.jpg",
        "tron": "1094/large/tron-logo.png",
        "cardano": "975/large/cardano.png",
        "polkadot": "12171/large/polkadot.jpg",
        "near": "10365/large/near.jpg",
        "avalanche-2": "12559/large/Avalanche_Circle_RedWhite_Trans.png",
        "arbitrum": "16547/large/arb.jpg",
        "optimism": "25244/large/Token.png",
        "chainlink": "877/large/Chainlink_Logo_500.png",
        "cosmos": "1481/large/cosmos_hub.png",
        "injective-protocol": "12882/large/Other_200x200.png",
        "sei-network": "28205/large/Sei_Logo_-_Transparent.png",
        "celestia": "31967/large/tia.jpg",
        "fetch-ai": "5681/large/ASI.png",
        "ethereum-classic": "453/large/ethereum-classic-logo.png",
        "bitcoin-cash": "780/large/bitcoin-cash-circle.png",
        "filecoin": "12817/large/filecoin.png",
        "immutable-x": "17233/large/immutableX-symbol-BLK-RGB.png",
        "lido-dao": "13573/large/Lido_DAO.png",
        "maker": "1364/large/Mark_Maker.png",
        "pepe": "29850/large/pepe-token.jpeg",
        "dogecoin": "5/large/dogecoin.png",
        "shiba-inu": "11939/large/shiba.png",
        "hedera-hashgraph": "3688/large/hbar.png",
        "kaspa": "25751/large/kaspa-icon-exchanges.png",
        "algorand": "4380/large/download.png",
    ]

    // MARK: - Crypto Initializer (backward compatible)

    init(assetId: String, geckoId: String, originDate: Date, deviationBounds: (low: Double, high: Double), confidenceLevel: Int, displayName: String, binanceSymbol: String?) {
        self.assetId = assetId
        self.geckoId = geckoId
        self.originDate = originDate
        self.deviationBounds = deviationBounds
        self.confidenceLevel = confidenceLevel
        self.displayName = displayName
        self.binanceSymbol = binanceSymbol
        self.assetType = .crypto
    }

    // MARK: - Stock Initializer

    init(stock symbol: String, originDate: Date, deviationBounds: (low: Double, high: Double), confidenceLevel: Int, displayName: String) {
        self.assetId = symbol
        self.geckoId = ""
        self.originDate = originDate
        self.deviationBounds = deviationBounds
        self.confidenceLevel = confidenceLevel
        self.displayName = displayName
        self.binanceSymbol = nil
        self.assetType = .stock
    }

    // MARK: - Supported Assets

    /// Bitcoin - longest history, most reliable
    static let btc = AssetRiskConfig(
        assetId: "BTC",
        geckoId: "bitcoin",
        originDate: safeDate(year: 2009, month: 1, day: 3),
        deviationBounds: (low: -0.8, high: 0.8),
        confidenceLevel: 9,
        displayName: "Bitcoin",
        binanceSymbol: "BTCUSDT"
    )

    /// Ethereum - second longest, high reliability
    static let eth = AssetRiskConfig(
        assetId: "ETH",
        geckoId: "ethereum",
        originDate: safeDate(year: 2015, month: 7, day: 30),
        deviationBounds: (low: -0.7, high: 0.7),
        confidenceLevel: 8,
        displayName: "Ethereum",
        binanceSymbol: "ETHUSDT"
    )

    /// Solana
    static let sol = AssetRiskConfig(
        assetId: "SOL",
        geckoId: "solana",
        originDate: safeDate(year: 2020, month: 4, day: 10),
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 6,
        displayName: "Solana",
        binanceSymbol: "SOLUSDT"
    )

    /// BNB - Binance coin, multiple cycles of data
    static let bnb = AssetRiskConfig(
        assetId: "BNB",
        geckoId: "binancecoin",
        originDate: safeDate(year: 2017, month: 7, day: 25),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 7,
        displayName: "BNB",
        binanceSymbol: "BNBUSDT"
    )

    /// Uniswap - DeFi governance token
    static let uni = AssetRiskConfig(
        assetId: "UNI",
        geckoId: "uniswap",
        originDate: safeDate(year: 2020, month: 9, day: 17),
        deviationBounds: (low: -0.55, high: 0.55),
        confidenceLevel: 5,
        displayName: "Uniswap",
        binanceSymbol: "UNIUSDT"
    )

    /// Render - GPU rendering network
    static let render = AssetRiskConfig(
        assetId: "RENDER",
        geckoId: "render-token",
        originDate: safeDate(year: 2020, month: 6, day: 10),
        deviationBounds: (low: -0.55, high: 0.55),
        confidenceLevel: 5,
        displayName: "Render",
        binanceSymbol: "RENDERUSDT"
    )

    /// Sui - Move-based L1
    static let sui = AssetRiskConfig(
        assetId: "SUI",
        geckoId: "sui",
        originDate: safeDate(year: 2023, month: 5, day: 3),
        deviationBounds: (low: -0.50, high: 0.50),
        confidenceLevel: 4,
        displayName: "Sui",
        binanceSymbol: "SUIUSDT"
    )

    /// Ondo - RWA tokenization
    static let ondo = AssetRiskConfig(
        assetId: "ONDO",
        geckoId: "ondo-finance",
        originDate: safeDate(year: 2024, month: 1, day: 18),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 3,
        displayName: "Ondo",
        binanceSymbol: "ONDOUSDT"
    )

    /// Bittensor - decentralized AI network
    static let tao = AssetRiskConfig(
        assetId: "TAO",
        geckoId: "bittensor",
        originDate: safeDate(year: 2023, month: 4, day: 20),
        deviationBounds: (low: -0.50, high: 0.50),
        confidenceLevel: 4,
        displayName: "Bittensor",
        binanceSymbol: "TAOUSDT"
    )

    /// Zcash - privacy-focused cryptocurrency
    static let zec = AssetRiskConfig(
        assetId: "ZEC",
        geckoId: "zcash",
        originDate: safeDate(year: 2016, month: 11, day: 15),
        deviationBounds: (low: -0.70, high: 0.70),
        confidenceLevel: 7,
        displayName: "Zcash",
        binanceSymbol: "ZECUSDT"
    )

    /// XRP - cross-border payments
    static let xrp = AssetRiskConfig(
        assetId: "XRP",
        geckoId: "ripple",
        originDate: safeDate(year: 2013, month: 8, day: 4),
        deviationBounds: (low: -0.75, high: 0.75),
        confidenceLevel: 8,
        displayName: "XRP",
        binanceSymbol: "XRPUSDT"
    )

    /// Litecoin - early Bitcoin fork
    static let ltc = AssetRiskConfig(
        assetId: "LTC",
        geckoId: "litecoin",
        originDate: safeDate(year: 2011, month: 11, day: 9),
        deviationBounds: (low: -0.75, high: 0.75),
        confidenceLevel: 8,
        displayName: "Litecoin",
        binanceSymbol: "LTCUSDT"
    )

    /// Aave - DeFi lending protocol
    static let aave = AssetRiskConfig(
        assetId: "AAVE",
        geckoId: "aave",
        originDate: safeDate(year: 2020, month: 10, day: 2),
        deviationBounds: (low: -0.55, high: 0.55),
        confidenceLevel: 5,
        displayName: "Aave",
        binanceSymbol: "AAVEUSDT"
    )

    /// Ethena - synthetic dollar protocol
    static let ena = AssetRiskConfig(
        assetId: "ENA",
        geckoId: "ethena",
        originDate: safeDate(year: 2024, month: 4, day: 2),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 2,
        displayName: "Ethena",
        binanceSymbol: "ENAUSDT"
    )

    /// Jupiter - Solana DEX aggregator
    static let jup = AssetRiskConfig(
        assetId: "JUP",
        geckoId: "jupiter-exchange-solana",
        originDate: safeDate(year: 2024, month: 1, day: 31),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 2,
        displayName: "Jupiter",
        binanceSymbol: "JUPUSDT"
    )

    /// Syrup - Maple Finance lending protocol
    static let syrup = AssetRiskConfig(
        assetId: "SYRUP",
        geckoId: "maple-finance",
        originDate: safeDate(year: 2024, month: 10, day: 15),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 2,
        displayName: "Syrup",
        binanceSymbol: "SYRUPUSDT"
    )

    /// Cardano — proof-of-stake L1
    static let ada = AssetRiskConfig(
        assetId: "ADA",
        geckoId: "cardano",
        originDate: safeDate(year: 2017, month: 10, day: 1),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 7,
        displayName: "Cardano",
        binanceSymbol: "ADAUSDT"
    )

    /// Polkadot — interoperability L0/L1
    static let dot = AssetRiskConfig(
        assetId: "DOT",
        geckoId: "polkadot",
        originDate: safeDate(year: 2020, month: 8, day: 19),
        deviationBounds: (low: -0.90, high: 0.90),
        confidenceLevel: 6,
        displayName: "Polkadot",
        binanceSymbol: "DOTUSDT"
    )

    /// NEAR Protocol — sharded L1
    static let near = AssetRiskConfig(
        assetId: "NEAR",
        geckoId: "near",
        originDate: safeDate(year: 2020, month: 10, day: 13),
        deviationBounds: (low: -0.80, high: 0.80),
        confidenceLevel: 6,
        displayName: "NEAR Protocol",
        binanceSymbol: "NEARUSDT"
    )

    /// Avalanche — high-throughput L1
    static let avax = AssetRiskConfig(
        assetId: "AVAX",
        geckoId: "avalanche-2",
        originDate: safeDate(year: 2020, month: 9, day: 21),
        deviationBounds: (low: -0.85, high: 0.85),
        confidenceLevel: 6,
        displayName: "Avalanche",
        binanceSymbol: "AVAXUSDT"
    )

    /// Arbitrum — Ethereum L2 rollup
    static let arb = AssetRiskConfig(
        assetId: "ARB",
        geckoId: "arbitrum",
        originDate: safeDate(year: 2023, month: 3, day: 23),
        deviationBounds: (low: -0.80, high: 0.80),
        confidenceLevel: 4,
        displayName: "Arbitrum",
        binanceSymbol: "ARBUSDT"
    )

    /// Optimism — Ethereum L2 rollup
    static let op = AssetRiskConfig(
        assetId: "OP",
        geckoId: "optimism",
        originDate: safeDate(year: 2022, month: 6, day: 1),
        deviationBounds: (low: -0.85, high: 0.85),
        confidenceLevel: 5,
        displayName: "Optimism",
        binanceSymbol: "OPUSDT"
    )

    /// Chainlink — oracle network
    static let link = AssetRiskConfig(
        assetId: "LINK",
        geckoId: "chainlink",
        originDate: safeDate(year: 2017, month: 9, day: 20),
        deviationBounds: (low: -0.70, high: 0.70),
        confidenceLevel: 7,
        displayName: "Chainlink",
        binanceSymbol: "LINKUSDT"
    )

    /// Cosmos — interchain ecosystem
    static let atom = AssetRiskConfig(
        assetId: "ATOM",
        geckoId: "cosmos",
        originDate: safeDate(year: 2019, month: 3, day: 14),
        deviationBounds: (low: -0.60, high: 0.60),
        confidenceLevel: 6,
        displayName: "Cosmos",
        binanceSymbol: "ATOMUSDT"
    )

    /// Injective — DeFi-focused L1
    static let inj = AssetRiskConfig(
        assetId: "INJ",
        geckoId: "injective-protocol",
        originDate: safeDate(year: 2020, month: 10, day: 21),
        deviationBounds: (low: -0.85, high: 0.85),
        confidenceLevel: 5,
        displayName: "Injective",
        binanceSymbol: "INJUSDT"
    )

    /// Sei — parallelized L1
    static let sei = AssetRiskConfig(
        assetId: "SEI",
        geckoId: "sei-network",
        originDate: safeDate(year: 2023, month: 8, day: 15),
        deviationBounds: (low: -0.80, high: 0.80),
        confidenceLevel: 4,
        displayName: "Sei",
        binanceSymbol: "SEIUSDT"
    )

    /// Celestia — modular data availability
    static let tia = AssetRiskConfig(
        assetId: "TIA",
        geckoId: "celestia",
        originDate: safeDate(year: 2023, month: 10, day: 31),
        deviationBounds: (low: -0.80, high: 0.80),
        confidenceLevel: 4,
        displayName: "Celestia",
        binanceSymbol: "TIAUSDT"
    )

    /// Fetch.ai — AI agent network
    static let fet = AssetRiskConfig(
        assetId: "FET",
        geckoId: "fetch-ai",
        originDate: safeDate(year: 2019, month: 2, day: 25),
        deviationBounds: (low: -0.60, high: 0.60),
        confidenceLevel: 6,
        displayName: "Fetch.ai",
        binanceSymbol: "FETUSDT"
    )

    /// Ethereum Classic — original Ethereum chain
    static let etc = AssetRiskConfig(
        assetId: "ETC",
        geckoId: "ethereum-classic",
        originDate: safeDate(year: 2016, month: 7, day: 24),
        deviationBounds: (low: -0.70, high: 0.70),
        confidenceLevel: 7,
        displayName: "Ethereum Classic",
        binanceSymbol: "ETCUSDT"
    )

    /// Bitcoin Cash — BTC fork
    static let bch = AssetRiskConfig(
        assetId: "BCH",
        geckoId: "bitcoin-cash",
        originDate: safeDate(year: 2017, month: 8, day: 1),
        deviationBounds: (low: -0.70, high: 0.70),
        confidenceLevel: 7,
        displayName: "Bitcoin Cash",
        binanceSymbol: "BCHUSDT"
    )

    /// Filecoin — decentralized storage
    static let fil = AssetRiskConfig(
        assetId: "FIL",
        geckoId: "filecoin",
        originDate: safeDate(year: 2020, month: 10, day: 15),
        deviationBounds: (low: -0.90, high: 0.90),
        confidenceLevel: 6,
        displayName: "Filecoin",
        binanceSymbol: "FILUSDT"
    )

    /// Immutable — gaming L2
    static let imx = AssetRiskConfig(
        assetId: "IMX",
        geckoId: "immutable-x",
        originDate: safeDate(year: 2021, month: 11, day: 12),
        deviationBounds: (low: -0.90, high: 0.90),
        confidenceLevel: 5,
        displayName: "Immutable",
        binanceSymbol: "IMXUSDT"
    )

    /// Lido DAO — liquid staking
    static let ldo = AssetRiskConfig(
        assetId: "LDO",
        geckoId: "lido-dao",
        originDate: safeDate(year: 2021, month: 1, day: 5),
        deviationBounds: (low: -0.50, high: 0.50),
        confidenceLevel: 5,
        displayName: "Lido DAO",
        binanceSymbol: "LDOUSDT"
    )

    /// Maker — DeFi lending governance
    static let mkr = AssetRiskConfig(
        assetId: "MKR",
        geckoId: "maker",
        originDate: safeDate(year: 2017, month: 1, day: 30),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 7,
        displayName: "Maker",
        binanceSymbol: "MKRUSDT"
    )

    /// Pepe — meme coin
    static let pepe = AssetRiskConfig(
        assetId: "PEPE",
        geckoId: "pepe",
        originDate: safeDate(year: 2023, month: 4, day: 14),
        deviationBounds: (low: -0.50, high: 0.50),
        confidenceLevel: 4,
        displayName: "Pepe",
        binanceSymbol: "PEPEUSDT"
    )

    /// Dogecoin — original meme coin
    static let doge = AssetRiskConfig(
        assetId: "DOGE",
        geckoId: "dogecoin",
        originDate: safeDate(year: 2013, month: 12, day: 6),
        deviationBounds: (low: -0.75, high: 0.75),
        confidenceLevel: 7,
        displayName: "Dogecoin",
        binanceSymbol: "DOGEUSDT"
    )

    /// Shiba Inu — meme coin
    static let shib = AssetRiskConfig(
        assetId: "SHIB",
        geckoId: "shiba-inu",
        originDate: safeDate(year: 2020, month: 8, day: 1),
        deviationBounds: (low: -0.75, high: 0.75),
        confidenceLevel: 6,
        displayName: "Shiba Inu",
        binanceSymbol: "SHIBUSDT"
    )

    /// Hedera — enterprise-grade DLT
    static let hbar = AssetRiskConfig(
        assetId: "HBAR",
        geckoId: "hedera-hashgraph",
        originDate: safeDate(year: 2019, month: 9, day: 16),
        deviationBounds: (low: -0.60, high: 0.60),
        confidenceLevel: 6,
        displayName: "Hedera",
        binanceSymbol: "HBARUSDT"
    )

    /// Kaspa — blockDAG PoW
    static let kas = AssetRiskConfig(
        assetId: "KAS",
        geckoId: "kaspa",
        originDate: safeDate(year: 2022, month: 5, day: 7),
        deviationBounds: (low: -0.50, high: 0.50),
        confidenceLevel: 4,
        displayName: "Kaspa",
        binanceSymbol: "KASUSDT"
    )

    /// Algorand — pure proof-of-stake L1
    static let algo = AssetRiskConfig(
        assetId: "ALGO",
        geckoId: "algorand",
        originDate: safeDate(year: 2019, month: 6, day: 20),
        deviationBounds: (low: -0.60, high: 0.60),
        confidenceLevel: 6,
        displayName: "Algorand",
        binanceSymbol: "ALGOUSDT"
    )

    /// Tron
    static let trx = AssetRiskConfig(
        assetId: "TRX",
        geckoId: "tron",
        originDate: safeDate(year: 2017, month: 9, day: 13),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 7,
        displayName: "Tron",
        binanceSymbol: "TRXUSDT"
    )

    // MARK: - Stock Configs

    /// Apple
    static let aapl = AssetRiskConfig(stock: "AAPL", originDate: safeDate(year: 1980, month: 12, day: 12), deviationBounds: (low: -0.5, high: 0.5), confidenceLevel: 9, displayName: "Apple")

    /// NVIDIA
    static let nvda = AssetRiskConfig(stock: "NVDA", originDate: safeDate(year: 1999, month: 1, day: 22), deviationBounds: (low: -0.6, high: 0.6), confidenceLevel: 8, displayName: "NVIDIA")

    /// Alphabet (Google)
    static let googl = AssetRiskConfig(stock: "GOOGL", originDate: safeDate(year: 2004, month: 8, day: 19), deviationBounds: (low: -0.5, high: 0.5), confidenceLevel: 8, displayName: "Alphabet")

    /// Microsoft
    static let msft = AssetRiskConfig(stock: "MSFT", originDate: safeDate(year: 1986, month: 3, day: 13), deviationBounds: (low: -0.5, high: 0.5), confidenceLevel: 9, displayName: "Microsoft")

    /// Amazon
    static let amzn = AssetRiskConfig(stock: "AMZN", originDate: safeDate(year: 1997, month: 5, day: 15), deviationBounds: (low: -0.55, high: 0.55), confidenceLevel: 9, displayName: "Amazon")

    /// Tesla
    static let tsla = AssetRiskConfig(stock: "TSLA", originDate: safeDate(year: 2010, month: 6, day: 29), deviationBounds: (low: -0.65, high: 0.65), confidenceLevel: 7, displayName: "Tesla")

    /// Meta Platforms
    static let meta = AssetRiskConfig(stock: "META", originDate: safeDate(year: 2012, month: 5, day: 18), deviationBounds: (low: -0.55, high: 0.55), confidenceLevel: 7, displayName: "Meta")

    /// Coinbase
    static let coin = AssetRiskConfig(stock: "COIN", originDate: safeDate(year: 2021, month: 4, day: 14), deviationBounds: (low: -0.65, high: 0.65), confidenceLevel: 4, displayName: "Coinbase")

    /// MicroStrategy
    static let mstr = AssetRiskConfig(stock: "MSTR", originDate: safeDate(year: 1998, month: 6, day: 11), deviationBounds: (low: -0.7, high: 0.7), confidenceLevel: 6, displayName: "MicroStrategy")

    /// S&P 500 ETF
    static let spy = AssetRiskConfig(stock: "SPY", originDate: safeDate(year: 1993, month: 1, day: 29), deviationBounds: (low: -0.4, high: 0.4), confidenceLevel: 9, displayName: "S&P 500")

    /// Nasdaq 100 ETF
    static let qqq = AssetRiskConfig(stock: "QQQ", originDate: safeDate(year: 1999, month: 3, day: 10), deviationBounds: (low: -0.45, high: 0.45), confidenceLevel: 9, displayName: "Nasdaq 100")

    /// Oracle
    static let orcl = AssetRiskConfig(stock: "ORCL", originDate: safeDate(year: 1986, month: 3, day: 12), deviationBounds: (low: -0.5, high: 0.5), confidenceLevel: 9, displayName: "Oracle")

    /// Robinhood
    static let hood = AssetRiskConfig(stock: "HOOD", originDate: safeDate(year: 2021, month: 7, day: 29), deviationBounds: (low: -0.65, high: 0.65), confidenceLevel: 4, displayName: "Robinhood")

    /// AMD
    static let amd = AssetRiskConfig(stock: "AMD", originDate: safeDate(year: 1979, month: 9, day: 27), deviationBounds: (low: -0.6, high: 0.6), confidenceLevel: 9, displayName: "AMD")

    /// Uber
    static let uber = AssetRiskConfig(stock: "UBER", originDate: safeDate(year: 2019, month: 5, day: 10), deviationBounds: (low: -0.55, high: 0.55), confidenceLevel: 6, displayName: "Uber")

    /// Bitmine Immersion Technologies
    static let bmnr = AssetRiskConfig(stock: "BMNR", originDate: safeDate(year: 2021, month: 2, day: 16), deviationBounds: (low: -0.7, high: 0.7), confidenceLevel: 3, displayName: "Bitmine")

    // MARK: - All Configs

    /// All supported crypto assets
    static let cryptoConfigs: [AssetRiskConfig] = [
        // Majors
        .btc, .eth, .sol,
        // L1s
        .bnb, .ada, .dot, .avax, .near, .atom, .sui, .tao, .hbar, .algo, .kas,
        // L2s
        .arb, .op, .imx,
        // DeFi
        .uni, .aave, .mkr, .ldo, .ena, .jup, .syrup,
        // Infra / Oracles / AI
        .link, .render, .fet,
        // Payments / Legacy
        .xrp, .ltc, .zec, .bch, .etc, .trx,
        // RWA / Narratives
        .ondo, .fil, .inj, .sei, .tia,
        // Memes
        .doge, .shib, .pepe,
    ]

    /// All supported stock assets
    static let stockConfigs: [AssetRiskConfig] = [
        .aapl, .nvda, .googl, .msft, .amzn, .tsla, .meta, .coin, .mstr, .spy, .qqq,
        .orcl, .hood, .amd, .uber, .bmnr
    ]

    /// All supported assets (crypto + stocks)
    static let allConfigs: [AssetRiskConfig] = cryptoConfigs + stockConfigs

    /// Dictionary for quick lookup by symbol
    static let bySymbol: [String: AssetRiskConfig] = {
        Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.assetId, $0) })
    }()

    /// Dictionary for quick lookup by CoinGecko ID (crypto only)
    static let byGeckoId: [String: AssetRiskConfig] = {
        Dictionary(uniqueKeysWithValues: cryptoConfigs.map { ($0.geckoId, $0) })
    }()

    // MARK: - Lookup Methods

    /// Get config for a coin symbol (crypto only, backward compatible)
    static func forCoin(_ symbol: String) -> AssetRiskConfig? {
        let config = bySymbol[symbol.uppercased()]
        return config?.assetType == .crypto ? config : nil
    }

    /// Get config for any asset symbol (crypto or stock)
    static func forSymbol(_ symbol: String) -> AssetRiskConfig? {
        bySymbol[symbol.uppercased()]
    }

    /// Get config for a stock symbol
    static func forStock(_ symbol: String) -> AssetRiskConfig? {
        let config = bySymbol[symbol.uppercased()]
        return config?.assetType == .stock ? config : nil
    }

    /// Get config for a CoinGecko ID
    static func forGeckoId(_ id: String) -> AssetRiskConfig? {
        byGeckoId[id.lowercased()]
    }

    /// Convert symbol to CoinGecko ID
    static func geckoId(for symbol: String) -> String? {
        forCoin(symbol)?.geckoId
    }

    /// Check if a coin is supported for risk calculation
    static func isSupported(_ symbol: String) -> Bool {
        bySymbol[symbol.uppercased()] != nil
    }
}

// MARK: - CoinGecko ID Mapping
extension AssetRiskConfig {
    /// Static mapping from symbol to CoinGecko ID (crypto only)
    static let coinGeckoIds: [String: String] = {
        Dictionary(uniqueKeysWithValues: cryptoConfigs.map { ($0.assetId, $0.geckoId) })
    }()
}
