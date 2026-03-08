export type TransactionType = 'buy' | 'sell' | 'transfer_in' | 'transfer_out';

export type EmotionalState =
  | 'confident'
  | 'fearful'
  | 'excited'
  | 'anxious'
  | 'fomo'
  | 'calm'
  | 'uncertain'
  | 'greedy';

export interface Transaction {
  id: string;
  portfolio_id: string;
  holding_id?: string;
  type: TransactionType;
  asset_type: string;
  symbol: string;
  quantity: number;
  price_per_unit: number;
  gas_fee: number;
  total_value: number;
  transaction_date: string;
  notes?: string;
  emotional_state?: EmotionalState;
  created_at: string;
  cost_basis_per_unit?: number;
  realized_profit_loss?: number;
}
