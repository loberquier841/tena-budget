
'use client';
import { useState } from 'react';

// Composant graphiques avec Recharts en prod - ici version légère sans dépendance pour démo
// Valeurs internes centimes Int, conversion euros affichage seulement

export function CategoryChart({ data }: { data: { name: string; totalCents: number; color: string }[] }) {
  const total = data.reduce((s, d) => s + d.totalCents, 0);
  return (
    <div>
      {data.map(d => {
        const percent = total ? Math.floor((d.totalCents * 100) / total) : 0;
        return (
          <div key={d.name} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <div style={{ width: 12, height: 12, background: d.color, borderRadius: 2 }}></div>
            <span style={{ flex: 1 }}>{d.name}</span>
            <span style={{ fontSize: 12 }}>{(d.totalCents/100).toFixed(2)}€ ({percent}%)</span>
            <div style={{ width: 60, height: 8, background: '#e5e7eb', borderRadius: 4 }}>
              <div style={{ width: `${percent}%`, height: '100%', background: d.color, borderRadius: 4 }}></div>
            </div>
          </div>
        );
      })}
      <p style={{ fontSize: 11, color: '#888' }}>Total: {total}c Int = {(total/100).toFixed(2)}€ affichage</p>
    </div>
  );
}

export function MonthlyChart({ data }: { data: { month: string; totalCents: number }[] }) {
  const max = Math.max(...data.map(d => d.totalCents));
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, height: 120 }}>
      {data.map(d => (
        <div key={d.month} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ width: '100%', background: '#7C3AED', height: `${(d.totalCents/max)*100}%`, minHeight: 10, borderRadius: '4px 4px 0 0' }}></div>
          <span style={{ fontSize: 10 }}>{d.month}</span>
        </div>
      ))}
    </div>
  );
}
