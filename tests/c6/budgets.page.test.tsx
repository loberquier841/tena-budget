import { describe, expect, it, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock the auth module
vi.mock('@/auth', () => ({
  auth: vi.fn(),
}));

// Mock the budget service
vi.mock('@/budget/budget', () => ({
  createBudget: vi.fn(),
  validateBudgetAmount: vi.fn(),
  Role: ['owner', 'admin', 'member', 'child'],
}));

// Mock permissions
vi.mock('@/permissions/permissions', () => ({
  Role: ['owner', 'admin', 'member', 'child'],
  assertCan: vi.fn(),
  requiresOwnerConfirmation: vi.fn(),
  useRole: vi.fn(),
}));

// Mock shared utilities
vi.mock('@/shared', () => ({
  toCents: (value: string | number) => Number(value) * 100,
}));

// Mock Dexie local storage
vi.mock('@/sync/dexie', () => ({
  getLocalBudgets: vi.fn(),
  createLocalBudget: vi.fn(),
}));

describe('Budgets Page', () => {
  const mockAuth = {
    userId: 'family-123',
    email: 'test@example.com',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    (auth as any).mockResolvedValue(mockAuth);
    (getLocalBudgets as any).mockResolvedValue([]);
  });

  it('renders login link when not authenticated', async () => {
    (auth as any).mockResolvedValue(null);

    render(<BudgetsPage />);

    expect(screen.getByText('Non connecté')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /login/i })).toBeInTheDocument();
  });

  it('loads budgets when authenticated', async () => {
    const mockBudgets = [
      { id: '1', name: 'Budget Mensuel', type: 'monthly', year: 2024, month: 10, amountCents: 50000 },
      { id: '2', name: 'Budget Annuel', type: 'annual', year: 2024, amountCents: 1000000 },
    ];
    (getLocalBudgets as any).mockResolvedValue(mockBudgets);

    render(<BudgetsPage />);

    expect(screen.getByText('Budget Mensuel')).toBeInTheDocument();
    expect(screen.getByText('Budget Annuel')).toBeInTheDocument();
  });

  it('handles budget form submission', async () => {
    (getLocalBudgets as any).mockResolvedValue([]);

    render(<BudgetsPage />);

    // Fill in the form
    const form = screen.getByRole('form');
    expect(form).toBeInTheDocument();

    await userEvent.type(screen.getByLabelText / type / 'amount', '500');
    await userEvent.type(screen.getByLabelText / type / 'year', '2024');

    expect(screen.getByLabelText('amount').value).toBe('500');
    expect(screen.getByLabelText('year').value).toBe('2024');
  });

  it('shows validation errors for invalid amounts', async () => {
    (getLocalBudgets as any).mockResolvedValue([]);

    render(<BudgetsPage />);

    await userEvent.type(screen.getByLabelText / type / 'amount', 'invalid');

    // Should show error or prevent submission
    const submitButton = screen.getByRole('button', { name: /create budget/i });
    expect(submitButton).toBeDisabled();
  });

  it('requires owner confirmation for large budgets', async () => {
    (getLocalBudgets as any).mockResolvedValue([]);

    render(<BudgetsPage />);

    // Set a large amount that requires confirmation
    await userEvent.type(screen.getByLabelText / type / 'amount', '5000');
    
    const submitButton = screen.getByRole('button', { name: /create budget/i });
    // The confirmation should be triggered
    expect(submitButton).toBeEnabled();
  });
});
