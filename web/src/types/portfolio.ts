export type TimePeriod = '1H' | '1D' | '1W' | '1M' | 'YTD' | '1Y' | 'ALL';

export interface Portfolio {
  id: string;
  user_id: string;
  name: string;
  is_public: boolean;
  created_at: string;
  holdings?: PortfolioHolding[];
}

export interface PortfolioHolding {
  id: string;
  portfolio_id: string;
  asset_type: string;
  symbol: string;
  name: string;
  quantity: number;
  average_buy_price?: number;
  created_at: string;
  updated_at: string;
  target_percentage?: number;
  // Live data (not in DB)
  current_price?: number;
  price_change_24h?: number;
  price_change_percentage_24h?: number;
  icon_url?: string;
}

export interface PortfolioStatistics {
  total_value: number;
  total_cost: number;
  profit_loss: number;
  profit_loss_percentage: number;
  day_change: number;
  day_change_percentage: number;
}

export interface PortfolioAllocation {
  category: string;
  value: number;
  percentage: number;
  color: string;
  target_percentage?: number;
}

export interface PortfolioHistoryPoint {
  date: string;
  value: number;
}

export interface PerformanceMetrics {
  total_return: number;
  total_return_percentage: number;
  total_invested: number;
  current_value: number;
  number_of_assets: number;
  max_drawdown: number;
  max_drawdown_value: number;
  sharpe_ratio: number;
  volatility: number;
}
