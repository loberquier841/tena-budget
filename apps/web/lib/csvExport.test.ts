import { beforeEach, describe, expect, it, vi } from 'vitest';

const stores = vi.hoisted(() => ({ getLocalBudgets: vi.fn(), getLocalTransactions: vi.fn() }));
vi.mock('@tena/core/sync/dexie', () => stores);

import { exportLocalBudgetsCsv, exportLocalTransactionsCsv } from './csvExport';

describe('exports CSV locaux', () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it('exporte les transactions locales en centimes et protège les libellés de formules', async () => {
    stores.getLocalTransactions.mockResolvedValue([{
      id: 'tx-1', familyId: 'local', bookingDate: new Date('2026-10-23T00:00:00.000Z'),
      label: '=HYPERLINK("https://example.invalid")', amountCents: -1250,
      source: 'manual', categoryId: 'food', personId: undefined,
    }]);

    const csv = await exportLocalTransactionsCsv('local');
    expect(stores.getLocalTransactions).toHaveBeenCalledWith('local');
    expect(csv).toContain('"-1250";"-12.5"');
    expect(csv).toContain(`'=HYPERLINK(""https://example.invalid"")`);
  });

  it('exporte les périodes et montants de budget sans données distantes', async () => {
    stores.getLocalBudgets.mockResolvedValue([{
      id: 'budget-1', year: 2026, month: 10, categoryId: 'food', personId: undefined, amountCents: 45000,
    }]);

    const csv = await exportLocalBudgetsCsv('local');
    expect(stores.getLocalBudgets).toHaveBeenCalledWith('local');
    expect(csv).toContain('"2026";"10";"food"');
    expect(csv).toContain('"45000";"450"');
  });
});
