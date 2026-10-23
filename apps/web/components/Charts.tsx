'use client';

// Graphiques réutilisables par le tableau de bord et la page de présentation.
// Les montants restent en centimes entiers jusqu'à leur éventuel affichage.
export function CategoryChart({ data }: { data: { name: string; totalCents: number; color: string }[] }) {
  const total = data.reduce((sum, item) => sum + item.totalCents, 0);

  return (
    <div>
      {data.map((item) => {
        const percent = total ? Math.floor((item.totalCents * 100) / total) : 0;
        return (
          <div key={item.name} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <span aria-hidden="true" style={{ width: 12, height: 12, flex: '0 0 12px', background: item.color, borderRadius: 3 }} />
            <span style={{ flex: 1 }}>{item.name}</span>
            <span style={{ fontSize: 12 }}>{(item.totalCents / 100).toFixed(2)}€ ({percent}%)</span>
            <span
              role="img"
              aria-label={`${percent}% du total pour ${item.name}`}
              style={{ width: 60, height: 8, background: '#272832', borderRadius: 4, overflow: 'hidden' }}
            >
              <span style={{ display: 'block', width: `${percent}%`, height: '100%', background: item.color, borderRadius: 4 }} />
            </span>
          </div>
        );
      })}
      <p style={{ fontSize: 11, color: '#a7a8b2' }}>
        Total : {(total / 100).toFixed(2)}€
      </p>
    </div>
  );
}

export function MonthlyChart({ data }: { data: { month: string; totalCents: number }[] }) {
  const max = Math.max(0, ...data.map((item) => item.totalCents));

  return (
    <div
      role="img"
      aria-label="Évolution mensuelle des dépenses"
      style={{
        display: 'flex',
        alignItems: 'flex-end',
        gap: 10,
        height: 132,
        padding: '12px 4px 0',
        background: 'repeating-linear-gradient(to bottom, transparent 0 27px, #ffffff0d 28px)',
        borderBottom: '1px solid #ffffff20',
      }}
    >
      {data.map((item) => {
        const height = max > 0 ? Math.max((item.totalCents / max) * 100, 6) : 6;
        return (
          <div
            key={item.month}
            style={{ flex: 1, alignSelf: 'stretch', display: 'grid', gridTemplateRows: '1fr auto', justifyItems: 'center', gap: 7 }}
          >
            <span
              aria-hidden="true"
              style={{ alignSelf: 'end', width: '100%', height: `${height}%`, minHeight: 6, background: 'linear-gradient(180deg, #e8cc6a, #8a7434)', borderRadius: '5px 5px 2px 2px' }}
            />
            <span aria-hidden="true" style={{ color: '#a7a8b2', fontSize: 9 }}>{item.month}</span>
          </div>
        );
      })}
    </div>
  );
}
