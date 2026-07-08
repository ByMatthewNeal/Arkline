'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { recordTransaction, deleteTransaction, deleteHoldingsBySymbol, updateHoldingTarget, createPortfolio, type RecordTxInput } from '@/lib/api/portfolio-mutations';
import { useAuth } from './use-auth';

export function useRecordTransaction(portfolioId: string | undefined) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: Omit<RecordTxInput, 'portfolioId'>) => recordTransaction({ ...input, portfolioId: portfolioId! }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings', portfolioId] });
      qc.invalidateQueries({ queryKey: ['transactions', portfolioId] });
    },
  });
}

export function useDeleteTransaction(portfolioId: string | undefined) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ txId, symbol }: { txId: string; symbol: string }) =>
      deleteTransaction(portfolioId!, txId, symbol),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings', portfolioId] });
      qc.invalidateQueries({ queryKey: ['transactions', portfolioId] });
    },
  });
}

export function useDeleteHolding(portfolioId: string | undefined) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (symbol: string) => deleteHoldingsBySymbol(portfolioId!, symbol),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings', portfolioId] });
    },
  });
}

export function useUpdateHoldingTarget(portfolioId: string | undefined) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ holdingId, target }: { holdingId: string; target: number | null }) => updateHoldingTarget(holdingId, target),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['holdings', portfolioId] });
    },
  });
}

export function useCreatePortfolio() {
  const qc = useQueryClient();
  const { authUser } = useAuth();
  return useMutation({
    mutationFn: (name: string) => createPortfolio(authUser!.id, name),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['portfolios', authUser?.id] });
    },
  });
}
