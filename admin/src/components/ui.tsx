import { useEffect, type ReactNode } from 'react'
import type { Tone } from '../lib/format'

export function Button({ children, variant = 'primary', ...props }:
  React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'secondary' | 'danger' | 'ghost' }) {
  return <button className={`btn btn-${variant}`} {...props}>{children}</button>
}

export function Field({ label, error, children, hint }: { label: string; error?: string; hint?: string; children: ReactNode }) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
      {error ? <span className="field-error">{error}</span> : hint ? <span className="field-hint">{hint}</span> : null}
    </label>
  )
}

export function Badge({ tone, children }: { tone: Tone; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}

export function ErrorBanner({ message, onRetry }: { message: string | null; onRetry?: () => void }) {
  if (!message) return null
  return (
    <div className="banner banner-error" role="alert">
      <span>{message}</span>
      {onRetry && <Button variant="ghost" onClick={onRetry}>Повторить</Button>}
    </div>
  )
}

export function Spinner() {
  return <div className="spinner" aria-label="Загрузка" />
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="empty">{children}</div>
}

export function PageHeader({ title, actions }: { title: string; actions?: ReactNode }) {
  return (
    <div className="page-header">
      <h1>{title}</h1>
      <div className="page-actions">{actions}</div>
    </div>
  )
}

export function Card({ title, children, actions }: { title?: string; children: ReactNode; actions?: ReactNode }) {
  return (
    <section className="card">
      {(title || actions) && <div className="card-header"><h2>{title}</h2>{actions}</div>}
      {children}
    </section>
  )
}

export function Pagination({ page, totalPages, totalCount, onChange }:
  { page: number; totalPages: number; totalCount: number; onChange(p: number): void }) {
  return (
    <div className="pagination">
      <span className="muted">Всего: {totalCount}</span>
      <div>
        <Button variant="secondary" disabled={page <= 1} onClick={() => onChange(page - 1)}>‹ Назад</Button>
        <span className="pagination-page">{page} / {Math.max(totalPages, 1)}</span>
        <Button variant="secondary" disabled={page >= totalPages} onClick={() => onChange(page + 1)}>Вперёд ›</Button>
      </div>
    </div>
  )
}

export function Modal({ title, onClose, children }: { title: string; onClose(): void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title} onMouseDown={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{title}</h2>
          <button className="icon-btn" onClick={onClose} aria-label="Закрыть">×</button>
        </div>
        {children}
      </div>
    </div>
  )
}

/** Wraps a table with loading / error / empty states so every list behaves the same. */
export function DataState({ loading, error, empty, onRetry, children }:
  { loading: boolean; error: string | null; empty: boolean; onRetry?: () => void; children: ReactNode }) {
  if (error) return <ErrorBanner message={error} onRetry={onRetry} />
  if (loading) return <Spinner />
  if (empty) return <Empty>Пока нет данных</Empty>
  return <>{children}</>
}
