'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import { createReminder, updateReminder, deleteReminder, logInvestment, type DCAReminderInput } from '@/lib/api/dca-mutations';
import type { DCAReminder } from '@/types';

function useInvalidate() {
  const qc = useQueryClient();
  const { authUser } = useAuth();
  return () => qc.invalidateQueries({ queryKey: ['dca-reminders-all', authUser?.id ?? 'demo'] });
}

export function useCreateReminder() {
  const invalidate = useInvalidate();
  const { authUser } = useAuth();
  return useMutation({
    mutationFn: (input: DCAReminderInput) => createReminder(authUser!.id, input),
    onSuccess: invalidate,
  });
}

export function useUpdateReminder() {
  const invalidate = useInvalidate();
  return useMutation({
    mutationFn: ({ id, patch }: { id: string; patch: Partial<DCAReminderInput> & { is_active?: boolean } }) => updateReminder(id, patch),
    onSuccess: invalidate,
  });
}

export function useDeleteReminder() {
  const invalidate = useInvalidate();
  return useMutation({ mutationFn: (id: string) => deleteReminder(id), onSuccess: invalidate });
}

export function useLogInvestment() {
  const invalidate = useInvalidate();
  return useMutation({ mutationFn: (reminder: DCAReminder) => logInvestment(reminder), onSuccess: invalidate });
}
