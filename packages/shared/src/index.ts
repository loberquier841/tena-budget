
export const APP_NAME = 'TENΛ Budget';
export const APP_VERSION = '1.1.0-fondations';

export const ROLES = ['owner', 'admin', 'member', 'child'] as const;
export type Role = typeof ROLES[number];

export const TRANSACTION_SOURCES = ['manual', 'import', 'bank'] as const;

// Montants en centimes pour éviter float
export const toCents = (euros: number) => Math.round(euros * 100);
export const fromCents = (cents: number) => cents / 100;

// 6 couches immuables import
export type MigrationLayer = 'file_original' | 'data_analyzed' | 'data_recognized' | 'data_ambiguous' | 'data_validated' | 'data_final';

export type ImportStatus = 'draft' | 'analyzing' | 'awaiting_validation' | 'imported' | 'failed';

// Validation Zod de base
import { z } from 'zod';
export const MoneyCentsSchema = z.number().int();
export const DateFRSchma = z.string().regex(/^\d{2}\/\d{2}\/\d{4}$/);
