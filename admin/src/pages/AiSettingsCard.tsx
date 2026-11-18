import { useState, type FormEvent } from 'react'
import { api } from '../api/client'
import type { AiCheckStep, AiProviderOption, AiSettings, AuditEntry } from '../api/types'
import { Badge, Button, DataState, ErrorBanner, Field, Modal } from '../components/ui'
import { fmtDateTime } from '../lib/format'
import { errorMessage, useAsync } from '../lib/useAsync'

const CUSTOM = '__custom'

const providerTitle: Record<string, string> = { OpenAI: 'ChatGPT (OpenAI)', Anthropic: 'Claude (Anthropic)' }
const keyHint: Record<string, string> = {
  OpenAI: 'Создайте ключ на platform.openai.com → API keys (Create new secret key) и пополните баланс в разделе Billing.',
  Anthropic: 'Создайте ключ в console.anthropic.com → API keys и пополните баланс в разделе Billing.',
}

/** The AI service of the «Питание» section: the client app's photo analysis, labels, consultant and reports. */
export function AiSettingsCard() {
  const { data, error, loading, reload } = useAsync(() => api<AiSettings>('/api/admin/ai'), [])
  return (
    <DataState loading={loading} error={error} empty={false} onRetry={reload}>
      {data && <AiCard initial={data} />}
    </DataState>
  )
}

interface Form { isEnabled: boolean; provider: string; visionModel: string; chatModel: string; budget: string }

function toForm(s: AiSettings): Form {
  return {
    isEnabled: s.isEnabled, provider: s.provider, visionModel: s.visionModel ?? '', chatModel: s.chatModel ?? '',
    budget: s.monthlyBudgetUsd === null ? '' : String(s.monthlyBudgetUsd),
  }
}

function AiCard({ initial }: { initial: AiSettings }) {
  const [current, setCurrent] = useState(initial)
  const [form, setForm] = useState(() => toForm(initial))
  const [error, setError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  const [busy, setBusy] = useState(false)
  const [checking, setChecking] = useState(false)
  const [keyAction, setKeyAction] = useState<'set' | 'delete' | null>(null)
  const [showAudit, setShowAudit] = useState(false)

  const provider = current.providers.find(p => p.id === form.provider) ?? current.providers[0]
  const key = current.keys[provider.id]
  const dirty = JSON.stringify(form) !== JSON.stringify(toForm(current))
  const status = statusOf(current)

  function apply(next: AiSettings) {
    setCurrent(next)
    setForm(toForm(next))
  }

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setSaved(false)
    try {
      apply(await api<AiSettings>('/api/admin/ai', {
        method: 'PUT',
        body: {
          isEnabled: form.isEnabled, provider: form.provider, visionModel: form.visionModel.trim() || null,
          chatModel: form.chatModel.trim() || null, monthlyBudgetUsd: form.budget.trim() === '' ? null : Number(form.budget),
          version: current.version,
        },
      }))
      setSaved(true)
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  async function check() {
    setChecking(true); setError(null); setSaved(false)
    try { apply(await api<AiSettings>('/api/admin/ai/check', { method: 'POST' })) } catch (err) { setError(errorMessage(err)) } finally { setChecking(false) }
  }

  const spent = `$${current.usage.spentUsd.toFixed(2)}`
  const budget = current.active.monthlyBudgetUsd > 0 ? ` из $${current.active.monthlyBudgetUsd}` : ''

  return (
    <section className="card" aria-label="ИИ-анализ еды" data-testid="ai-settings">
      <div className="card-header">
        <div>
          <h2>ИИ-анализ еды</h2>
          <div className="muted small">
            Распознавание блюд и этикеток по фото, ИИ-консультант и отчёты в разделе «Питание» приложения. Калории и БЖУ
            считаются по базе продуктов — ИИ только узнаёт еду и оценивает вес.
          </div>
        </div>
        <Badge tone={status.tone}>{status.label}</Badge>
      </div>
      <p className="small">
        {current.active.source === 'None'
          ? 'Сейчас ИИ не подключён: в приложении анализ фото недоступен, дневник и штрихкоды работают.'
          : `Сейчас работает: ${current.active.providerName} · фото — ${current.active.visionModel}, консультант — ${current.active.chatModel}` +
            (current.active.source === 'Server' ? ' (из настроек сервера).' : '.')}
      </p>

      <form className="form" onSubmit={save}>
        <ErrorBanner message={error} />
        {saved && <div className="banner banner-success">Сохранено. Изменения уже действуют в приложении.</div>}
        {!current.encryptionConfigured && (
          <ErrorBanner message="На сервере не задан ключ шифрования Integrations__EncryptionKey: API-ключ сохранить нельзя." />
        )}
        <div className="grid-2">
          <Field label="Провайдер">
            <select value={form.provider} data-testid="ai-provider"
              onChange={e => setForm({ ...form, provider: e.target.value, visionModel: '', chatModel: '' })}>
              {current.providers.map(p => <option key={p.id} value={p.id}>{providerTitle[p.id] ?? p.name}</option>)}
            </select>
          </Field>
          <label className="check" style={{ alignSelf: 'end', paddingBottom: 10 }}>
            <input type="checkbox" checked={form.isEnabled} data-testid="ai-enabled"
              onChange={e => setForm({ ...form, isEnabled: e.target.checked })} />
            ИИ включён для клиентов
          </label>
        </div>

        <div className="secret-row">
          <div>
            <div className="field-label">API-ключ {providerTitle[provider.id] ?? provider.name}</div>
            {key?.isSet
              ? <div><code data-testid="ai-key-mask">{key.mask ?? '••••'}</code> <span className="muted small">задан {fmtDateTime(key.updatedAt)}</span>
                  {!key.isReadable && <div className="field-error">Не расшифровывается (сменён ключ шифрования сервера) — задайте заново.</div>}</div>
              : <div className="muted">Не задан</div>}
            <div className="muted small">{keyHint[provider.id]}</div>
          </div>
          <div className="row-actions">
            <Button type="button" variant="secondary" disabled={!current.encryptionConfigured}
              data-testid="ai-key-set" onClick={() => setKeyAction('set')}>{key?.isSet ? 'Заменить' : 'Задать ключ'}</Button>
            {key?.isSet && <Button type="button" variant="ghost" onClick={() => setKeyAction('delete')}>Удалить</Button>}
          </div>
        </div>

        <div className="grid-2">
          <ModelField key={`v-${provider.id}`} label="Модель для фото и этикеток" provider={provider} value={form.visionModel} kind="vision"
            onChange={v => setForm({ ...form, visionModel: v })} />
          <ModelField key={`c-${provider.id}`} label="Модель для консультанта и отчётов" provider={provider} value={form.chatModel} kind="chat"
            onChange={v => setForm({ ...form, chatModel: v })} />
        </div>
        <Field label="Лимит расходов в месяц, $"
          hint={`Пусто — как в настройках сервера ($${current.serverMonthlyBudgetUsd}); 0 — без лимита. При достижении лимита анализ ставится на паузу до следующего месяца.`}>
          <input type="number" min={0} step={1} value={form.budget} placeholder={String(current.serverMonthlyBudgetUsd)}
            onChange={e => setForm({ ...form, budget: e.target.value })} style={{ maxWidth: 200 }} />
        </Field>
        <p className="muted small" data-testid="ai-usage">
          В этом месяце: потрачено {spent}{budget}, запросов к ИИ — {current.usage.requests}
          {current.usage.failed > 0 ? ` (с ошибкой — ${current.usage.failed})` : ''}, распознано фото — {current.usage.photoScans}.
        </p>

        <div className="secret-row">
          <div>
            <div className="field-label">Проверка подключения</div>
            <div className="muted small">
              Настоящие запросы с сохранённым ключом и моделями: фото-модель получает картинку и отвечает JSON, модель консультанта вызывает
              функцию. Данные клиентов не отправляются; стоит доли цента.
            </div>
          </div>
          <div className="row-actions">
            <Button type="button" variant="secondary" data-testid="ai-check" disabled={checking || dirty || !key?.isReadable}
              onClick={check}>{checking ? 'Проверяем…' : 'Проверить подключение'}</Button>
          </div>
        </div>
        {dirty && key?.isReadable && <p className="muted small">Сохраните изменения, чтобы проверить их.</p>}
        {current.lastCheck && <CheckResult check={current.lastCheck} />}

        <div className="form-actions">
          <span className="muted small">
            {current.updatedAt ? `Изменено ${fmtDateTime(current.updatedAt)}${current.updatedBy ? `, ${current.updatedBy}` : ''}` : 'Ещё не настраивалось'}
          </span>
          <Button type="button" variant="ghost" onClick={() => setShowAudit(v => !v)}>Журнал</Button>
          <Button type="submit" disabled={busy || !dirty} data-testid="ai-save">Сохранить</Button>
        </div>
      </form>

      {showAudit && <AiAudit version={current.version} />}
      {keyAction && (
        <KeyModal provider={provider} kind={keyAction} onClose={() => setKeyAction(null)}
          onDone={next => {
            // The key is saved at once; unsaved choices in the form (another provider, models) stay as they are.
            setCurrent(next)
            setForm(f => ({ ...f }))
            setKeyAction(null)
          }} />
      )}
    </section>
  )
}

function statusOf(s: AiSettings): { label: string; tone: 'gray' | 'blue' | 'orange' | 'green' | 'red' } {
  if (s.lastCheck && !s.lastCheck.ok) return { label: 'Проверка не прошла', tone: 'orange' }
  if (s.active.source === 'Admin') return { label: `Работает · ${providerTitle[s.active.provider ?? ''] ?? s.active.providerName}`, tone: 'green' }
  if (s.active.source === 'Server') return { label: 'Работает по настройкам сервера', tone: 'blue' }
  return { label: s.keys[s.provider]?.isSet ? 'Выключено' : 'Не подключено', tone: 'gray' }
}

function ModelField({ label, provider, value, kind, onChange }: {
  label: string; provider: AiProviderOption; value: string; kind: 'vision' | 'chat'; onChange(v: string): void
}) {
  const fallback = kind === 'vision' ? provider.defaultVisionModel : provider.defaultChatModel
  const [custom, setCustom] = useState(value !== '' && !provider.models.includes(value))
  const selected = custom ? CUSTOM : value || fallback
  return (
    <Field label={label} hint={custom ? 'Идентификатор модели из документации провайдера.' : undefined}>
      <select value={selected} data-testid={`ai-model-${kind}`} onChange={e => {
        const v = e.target.value
        setCustom(v === CUSTOM)
        onChange(v === CUSTOM ? value : v === fallback ? '' : v)
      }}>
        {provider.models.map(m => <option key={m} value={m}>{m}{m === fallback ? ' (по умолчанию)' : ''}</option>)}
        <option value={CUSTOM}>Другая модель…</option>
      </select>
      {custom && (
        <input value={value} onChange={e => onChange(e.target.value)} placeholder={fallback} spellCheck={false}
          autoComplete="off" style={{ marginTop: 6 }} />
      )}
    </Field>
  )
}

function stepTitle(s: AiCheckStep) {
  return s.step === 'vision' ? 'Фото' : 'Консультант'
}

function stepProblem(s: AiCheckStep): string {
  if (s.errorCode === 'unexpected_answer') return 'Модель ответила, но не так, как просили. Попробуйте другую модель.'
  if (s.billing) return 'На счёте нет средств или достигнут лимит расходов. Пополните баланс в кабинете провайдера (Billing).'
  switch (s.providerStatus) {
    case 401: return 'Ключ не подошёл: провайдер его не принял. Проверьте, что ключ скопирован целиком и не отозван.'
    case 403: return 'Нет доступа: этому ключу или проекту не разрешена модель.'
    case 404: return `Модель «${s.model}» не найдена или недоступна для этого ключа.`
    case 429: return 'Слишком много запросов. Повторите через минуту.'
    case 400: return 'Провайдер отклонил запрос: возможно, модель не поддерживает фото, функции или ответ по схеме.'
  }
  if (s.providerCode === 'timeout') return 'Провайдер не ответил вовремя. Повторите проверку.'
  if (s.providerCode === 'network') return 'Сервер клуба не может связаться с провайдером: проверьте доступ сервера в интернет.'
  if (s.errorCode === 'ai_refused') return 'Модель отказалась отвечать.'
  if (s.errorCode === 'ai_invalid_response') return 'Ответ модели не подошёл по формату.'
  return 'Ошибка при обращении к провайдеру.'
}

function CheckResult({ check }: { check: NonNullable<AiSettings['lastCheck']> }) {
  return (
    <div className={`banner ${check.ok ? 'banner-success' : 'banner-error'}`} data-testid="ai-check-result" style={{ display: 'block' }}>
      <div><b>{check.ok ? 'Подключение работает' : 'Подключение не работает'}</b> · {providerTitle[check.provider] ?? check.provider} · {fmtDateTime(check.at)}</div>
      {check.steps.map(s => (
        <div key={s.step} className="small" style={{ marginTop: 6 }}>
          {s.ok ? '✓' : '✗'} {stepTitle(s)}: <code>{s.model}</code> — {s.ok
            ? `${s.step === 'vision' ? 'картинка распознана' : 'функция вызвана'}, ответ «${s.answer}» за ${(s.durationMs / 1000).toFixed(1)} с`
            : stepProblem(s)}
          {!s.ok && s.detail && <div className="muted small" style={{ wordBreak: 'break-word' }}>{s.detail}</div>}
        </div>
      ))}
    </div>
  )
}

/** Setting, replacing and removing a key are explicit actions. The value lives only in this input. */
function KeyModal({ provider, kind, onClose, onDone }: {
  provider: AiProviderOption; kind: 'set' | 'delete'; onClose(): void; onDone(next: AiSettings): void
}) {
  const [value, setValue] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const title = providerTitle[provider.id] ?? provider.name
  const url = `/api/admin/ai/keys/${provider.id}`

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null)
    try {
      onDone(await api<AiSettings>(url, kind === 'set' ? { method: 'PUT', body: { value } } : { method: 'DELETE' }))
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={kind === 'set' ? `API-ключ ${title}` : `Удалить ключ ${title}?`} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        {kind === 'set' ? (
          <>
            <Field label="Ключ" hint="Сохраняется зашифрованным и больше не показывается целиком (видны только последние 4 символа).">
              <input type="password" value={value} onChange={e => setValue(e.target.value)} required minLength={20} maxLength={512}
                autoComplete="off" autoFocus spellCheck={false} data-testid="ai-key-input"
                placeholder={provider.id === 'OpenAI' ? 'sk-proj-…' : 'sk-ant-…'} />
            </Field>
            <p className="muted small">{keyHint[provider.id]} <a href={provider.keysUrl} target="_blank" rel="noreferrer">Открыть страницу ключей</a></p>
          </>
        ) : (
          <p>Ключ будет удалён без возможности восстановления. Чтобы снова подключить провайдера, его придётся ввести заново.</p>
        )}
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" variant={kind === 'set' ? 'primary' : 'danger'} disabled={busy} data-testid="ai-key-save">
            {kind === 'set' ? 'Сохранить ключ' : 'Удалить'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}

const auditAction: Record<string, string> = {
  ai_settings_updated: 'Изменены настройки', ai_key_set: 'Задан ключ', ai_key_replaced: 'Заменён ключ', ai_key_removed: 'Удалён ключ',
  ai_checked: 'Проверка подключения',
}

function AiAudit({ version }: { version: number }) {
  const { data, error, loading, reload } = useAsync(() => api<AuditEntry[]>('/api/admin/ai/audit'), [version])
  return (
    <DataState loading={loading} error={error} empty={!!data && data.length === 0} onRetry={reload}>
      <table className="table compact">
        <tbody>
          {data?.map((a, i) => (
            <tr key={i}>
              <td className="muted small">{fmtDateTime(a.createdAt)}</td>
              <td>{auditAction[a.action] ?? a.action}</td>
              <td className="small">{a.details}</td>
              <td className="muted small">{a.userName}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </DataState>
  )
}
