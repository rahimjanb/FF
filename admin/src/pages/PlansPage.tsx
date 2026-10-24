import { useState, type FormEvent } from 'react'
import { api } from '../api/client'
import type { MembershipPlan, MembershipPlanType } from '../api/types'
import { Badge, Button, DataState, ErrorBanner, Field, Modal, PageHeader } from '../components/ui'
import { fmtMoney, planTypeLabel } from '../lib/format'
import { errorMessage, fieldErrors, useAsync } from '../lib/useAsync'

export function PlansPage() {
  const { data, error, loading, reload } = useAsync(() => api<MembershipPlan[]>('/api/admin/membership-plans'), [])
  const [editing, setEditing] = useState<MembershipPlan | 'new' | null>(null)

  return (
    <>
      <PageHeader title="Планы абонементов" actions={<Button onClick={() => setEditing('new')}>+ Новый план</Button>} />
      <DataState loading={loading} error={error} empty={!!data && data.length === 0} onRetry={reload}>
        <table className="table">
          <thead><tr><th>Название</th><th>Тип</th><th>Срок</th><th>Посещений</th><th>Цена</th><th>Статус</th><th /></tr></thead>
          <tbody>
            {data?.map(p => (
              <tr key={p.id}>
                <td>{p.name}{p.description && <div className="muted small">{p.description}</div>}</td>
                <td>{planTypeLabel[p.type]}</td>
                <td>{p.durationDays} дн.</td>
                <td>{p.visitLimit ?? '∞'}</td>
                <td>{fmtMoney(p.price)}</td>
                <td><Badge tone={p.isActive ? 'green' : 'gray'}>{p.isActive ? 'Доступен' : 'Отключён'}</Badge></td>
                <td><Button variant="ghost" onClick={() => setEditing(p)}>Изменить</Button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </DataState>
      {editing && <PlanModal plan={editing === 'new' ? null : editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload() }} />}
    </>
  )
}

function PlanModal({ plan, onClose, onSaved }: { plan: MembershipPlan | null; onClose(): void; onSaved(): void }) {
  const [form, setForm] = useState({
    name: plan?.name ?? '', description: plan?.description ?? '', type: plan?.type ?? ('Unlimited' as MembershipPlanType),
    durationDays: String(plan?.durationDays ?? 30), visitLimit: String(plan?.visitLimit ?? ''), price: String(plan?.price ?? ''),
    isActive: plan?.isActive ?? true,
  })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setForm({ ...form, [k]: e.target.value })

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setErrors({})
    const body = {
      name: form.name, description: form.description || null, type: form.type, durationDays: Number(form.durationDays),
      visitLimit: form.type === 'LimitedVisits' ? Number(form.visitLimit) : null, price: Number(form.price), isActive: form.isActive,
    }
    try {
      await api(plan ? `/api/admin/membership-plans/${plan.id}` : '/api/admin/membership-plans', { method: plan ? 'PUT' : 'POST', body })
      onSaved()
    } catch (err) { setError(errorMessage(err)); setErrors(fieldErrors(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={plan ? 'Изменить план' : 'Новый план'} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        {plan && <p className="muted small">Изменения применяются к новым абонементам. Уже выданные сохраняют свои даты и лимит.</p>}
        <Field label="Название" error={errors.name}><input value={form.name} onChange={set('name')} required maxLength={128} /></Field>
        <Field label="Описание" error={errors.description}><textarea value={form.description} onChange={set('description')} rows={2} maxLength={1000} /></Field>
        <div className="grid-2">
          <Field label="Тип"><select value={form.type} onChange={set('type')}>
            <option value="Unlimited">Безлимит</option><option value="LimitedVisits">По посещениям</option>
          </select></Field>
          <Field label="Срок, дней" error={errors.durationDays}><input type="number" min={1} max={3660} value={form.durationDays} onChange={set('durationDays')} required /></Field>
        </div>
        <div className="grid-2">
          {form.type === 'LimitedVisits' &&
            <Field label="Количество посещений" error={errors.visitLimit}><input type="number" min={1} value={form.visitLimit} onChange={set('visitLimit')} required /></Field>}
          <Field label="Цена, сум" error={errors.price}><input type="number" min={0} step="1000" value={form.price} onChange={set('price')} required /></Field>
        </div>
        <label className="check"><input type="checkbox" checked={form.isActive} onChange={e => setForm({ ...form, isActive: e.target.checked })} /> Доступен для назначения</label>
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy}>Сохранить</Button>
        </div>
      </form>
    </Modal>
  )
}
