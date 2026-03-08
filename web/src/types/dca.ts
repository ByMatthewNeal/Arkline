export type DCAFrequency = 'daily' | 'twice_weekly' | 'weekly' | 'biweekly' | 'monthly';

export interface DCAReminder {
  id: string;
  user_id: string;
  symbol: string;
  name: string;
  amount: number;
  frequency: DCAFrequency;
  total_purchases?: number;
  completed_purchases: number;
  notification_time: string;
  start_date: string;
  next_reminder_date?: string;
  is_active: boolean;
  created_at: string;
}

export interface DCAInvestment {
  id: string;
  reminder_id: string;
  amount: number;
  price_at_purchase: number;
  quantity: number;
  purchase_date: string;
}
