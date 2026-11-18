import { useCallback, useEffect, useRef, useState } from 'react'
import { Link } from 'react-router'
import { api } from '../api/client'
import type { CheckInResult } from '../api/types'
import { Badge, Button, Card, PageHeader } from '../components/ui'
import {
  checkInReasonLabel, displayPhone, fmtDate, fmtDateTime, fullName, membershipStatusLabel, membershipStatusTone, planTypeLabel,
} from '../lib/format'
import { errorMessage } from '../lib/useAsync'

const SOUND_KEY = 'ff.admin.checkin.sound'

/**
 * Maps a key press to a pass character by the physical key, not the produced character: a USB scanner is a keyboard,
 * and in the Russian layout it would otherwise type Cyrillic letters. Pass codes use only A–Z and 0–9.
 */
function passChar(e: KeyboardEvent): string | null {
  if (/^Key[A-Z]$/.test(e.code)) return e.code.slice(3)
  if (/^(Digit|Numpad)[0-9]$/.test(e.code)) return e.code.slice(-1)
  return null
}

function beep(ok: boolean) {
  try {
    const ctx = new AudioContext()
    const tones = ok ? [[880, 0], [1320, 0.12]] : [[220, 0], [180, 0.18]]
    for (const [freq, at] of tones) {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = ok ? 'sine' : 'square'
      osc.frequency.value = freq
      gain.gain.setValueAtTime(0.15, ctx.currentTime + at)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + at + 0.16)
      osc.connect(gain).connect(ctx.destination)
      osc.start(ctx.currentTime + at)
      osc.stop(ctx.currentTime + at + 0.17)
    }
    setTimeout(() => void ctx.close(), 600)
  } catch { /* no audio device */ }
}

interface Scan { at: string; result: CheckInResult; undone: boolean }

/** Club desk: the scanner types the QR pass; entry is decided and recorded at once. */
export function CheckInPage() {
  const [buffer, setBuffer] = useState('')
  const [checking, setChecking] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [scans, setScans] = useState<Scan[]>([])
  const [focused, setFocused] = useState(() => document.hasFocus())
  const [sound, setSound] = useState(() => {
    try { return localStorage.getItem(SOUND_KEY) !== 'off' } catch { return true }
  })
  const bufferRef = useRef('')
  const checkingRef = useRef(false)
  const soundRef = useRef(sound)
  useEffect(() => { soundRef.current = sound }, [sound])

  const setCode = (code: string) => { bufferRef.current = code; setBuffer(code) }

  const check = useCallback(async (raw: string) => {
    const code = raw.trim()
    if (!code || checkingRef.current) return
    checkingRef.current = true
    setChecking(true)
    setError(null)
    try {
      const result = await api<CheckInResult>('/api/admin/check-in', { method: 'POST', body: { code } })
      setScans(s => [{ at: new Date().toISOString(), result, undone: false }, ...s].slice(0, 15))
      if (soundRef.current) beep(result.allowed)
    } catch (e) {
      setError(errorMessage(e))
      if (soundRef.current) beep(false)
    } finally {
      checkingRef.current = false
      setChecking(false)
      setCode('')
    }
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey || e.altKey) return
      const target = e.target as HTMLElement | null
      if (target?.closest('input, textarea, select, [contenteditable="true"]')) return
      if (e.key === 'Enter' || (e.key === 'Tab' && bufferRef.current)) {
        e.preventDefault()
        void check(bufferRef.current)
      } else if (e.key === 'Escape') {
        setCode('')
      } else if (e.key === 'Backspace') {
        e.preventDefault()
        setCode(bufferRef.current.slice(0, -1))
      } else {
        const c = passChar(e)
        if (c && bufferRef.current.length < 128) {
          e.preventDefault()
          setCode(bufferRef.current + c)
        }
      }
    }
    const onPaste = (e: ClipboardEvent) => {
      const target = e.target as HTMLElement | null
      if (target?.closest('input, textarea')) return
      const text = e.clipboardData?.getData('text') ?? ''
      if (text) { e.preventDefault(); void check(text) }
    }
    const onFocus = () => setFocused(true)
    const onBlur = () => setFocused(false)
    window.addEventListener('keydown', onKey)
    window.addEventListener('paste', onPaste)
    window.addEventListener('focus', onFocus)
    window.addEventListener('blur', onBlur)
    return () => {
      window.removeEventListener('keydown', onKey)
      window.removeEventListener('paste', onPaste)
      window.removeEventListener('focus', onFocus)
      window.removeEventListener('blur', onBlur)
    }
  }, [check])

  function toggleSound() {
    const next = !sound
    setSound(next)
    try { localStorage.setItem(SOUND_KEY, next ? 'on' : 'off') } catch { /* private mode */ }
  }

  async function undo(scan: Scan) {
    const visit = scan.result.visit
    if (!visit || !window.confirm('Отменить отмеченный вход? Посещение будет удалено.')) return
    try {
      await api(`/api/admin/visits/${visit.id}`, { method: 'DELETE' })
      setScans(s => s.map(x => (x === scan ? { ...x, undone: true } : x)))
    } catch (e) { window.alert(errorMessage(e)) }
  }

  const last = scans[0]
  return (
    <>
      <PageHeader title="Пропуск" actions={
        <Button variant="secondary" onClick={toggleSound}>{sound ? 'Звук: вкл' : 'Звук: выкл'}</Button>
      } />
      <div className={`scan-panel ${focused ? '' : 'scan-panel-idle'}`} data-testid="scan-panel">
        <div className="scan-icon" aria-hidden>▣</div>
        <div className="scan-text">
          <b>{checking ? 'Проверяем…' : focused ? 'Готово к сканированию' : 'Окно не активно — щёлкните здесь, чтобы сканер работал'}</b>
          <span className="muted small">
            Поднесите QR-пропуск клиента к сканеру. Код можно ввести с клавиатуры или вставить (Ctrl+V) и нажать Enter.
          </span>
          <code className="scan-code" aria-label="Считанный код">{buffer || ' '}</code>
        </div>
      </div>
      {error && <div className="banner banner-error" role="alert">{error}</div>}
      {last && <ScanResult scan={last} onUndo={() => undo(last)} />}
      {scans.length > 1 && (
        <Card title="Последние сканирования">
          <table className="table compact">
            <tbody>
              {scans.slice(1).map(s => (
                <tr key={s.at}>
                  <td>{fmtDateTime(s.at)}</td>
                  <td>{s.result.client ? fullName(s.result.client) : '—'}</td>
                  <td>{s.undone ? <Badge tone="gray">Вход отменён</Badge>
                    : s.result.allowed ? <Badge tone="green">{s.result.repeated ? 'Повторно' : 'Вход разрешён'}</Badge>
                    : <Badge tone="red">{checkInReasonLabel[s.result.reason ?? ''] ?? 'Отказ'}</Badge>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}
    </>
  )
}

function ScanResult({ scan, onUndo }: { scan: Scan; onUndo(): void }) {
  const r = scan.result
  const m = r.membership
  const tone = scan.undone ? 'undone' : r.allowed ? (r.repeated ? 'repeated' : 'allowed') : 'denied'
  const title = scan.undone ? 'Вход отменён'
    : r.allowed ? (r.repeated ? 'Вход уже отмечен' : 'Вход разрешён')
    : 'Вход запрещён'
  return (
    <section className={`scan-result scan-${tone}`} role="status" data-testid="scan-result">
      <div className="scan-verdict">
        <span className="scan-verdict-title">{title}</span>
        {!r.allowed && <span>{checkInReasonLabel[r.reason ?? ''] ?? r.reason}</span>}
        {r.allowed && r.repeated && r.visit && <span>Этот клиент уже прошёл в {fmtDateTime(r.visit.visitedAt).slice(-5)}, повторно не записано.</span>}
      </div>
      {r.client && (
        <div className="scan-details">
          <div className="kv">
            <div><span>Клиент</span><b><Link to={`/clients/${r.client.id}`}>{fullName(r.client)}</Link></b></div>
            <div><span>Телефон</span><b>{displayPhone(r.client.phone)}</b></div>
            <div><span>Тренер</span><b>{r.client.assignedTrainer ? fullName(r.client.assignedTrainer) : '—'}</b></div>
            <div><span>Посещений сегодня</span><b>{r.visitsToday}</b></div>
            <div><span>Предыдущее посещение</span><b>{fmtDateTime(r.previousVisitAt)}</b></div>
          </div>
          <div className="kv">
            {m ? <>
              <div><span>Абонемент</span><b>{m.planName} · {planTypeLabel[m.planType]}</b></div>
              <div><span>Статус</span><Badge tone={membershipStatusTone[m.effectiveStatus]}>{membershipStatusLabel[m.effectiveStatus]}</Badge></div>
              <div><span>Срок</span><b>{fmtDate(m.startDate)} — {fmtDate(m.endDate)}</b></div>
              <div><span>Осталось дней</span><b>{m.daysLeft}</b></div>
              <div><span>Посещения</span><b>{m.visitLimit !== null ? `${m.visitsUsed} из ${m.visitLimit}` : `${m.visitsUsed} (безлимит)`}</b></div>
              {m.freezeStartDate && <div><span>Заморозка</span><b>{fmtDate(m.freezeStartDate)} — {fmtDate(m.freezeEndDate)}</b></div>}
            </> : <div><span>Абонемент</span><b>нет</b></div>}
          </div>
        </div>
      )}
      {r.allowed && r.visit && !scan.undone && (
        <div className="row"><Button variant="secondary" onClick={onUndo}>Отменить вход</Button></div>
      )}
    </section>
  )
}
