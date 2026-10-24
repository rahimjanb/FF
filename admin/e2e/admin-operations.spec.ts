import { expect, test, type APIRequestContext, type Page } from '@playwright/test'

// Critical admin operations against a REAL running backend: trainers, trainer requests, reports, paging.
// Test data is created with unique "E2E" names; nothing is deleted. Requires ADMIN_PHONE / ADMIN_PASSWORD.
const adminPhone = process.env.ADMIN_PHONE
const adminPassword = process.env.ADMIN_PASSWORD
const api = 'http://localhost:5080'

test.skip(!adminPhone || !adminPassword, 'Set ADMIN_PHONE and ADMIN_PASSWORD')

let seq = 0
/** Unique 7-digit suffix per call, used in phones and names. */
const stamp = () => (Date.now() + seq++).toString().slice(-7)

async function signIn(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Номер телефона').fill(adminPhone!)
  await page.getByLabel('Пароль').fill(adminPassword!)
  await page.getByRole('button', { name: 'Войти' }).click()
  await expect(page.getByRole('heading', { name: 'Обзор' })).toBeVisible()
}

/** Thin JSON client for test setup and for checking what the panel did. */
class Api {
  constructor(private request: APIRequestContext, private token?: string) {}

  static async login(request: APIRequestContext, phone: string, password: string) {
    const res = await request.post(`${api}/api/auth/login`, { data: { phone, password } })
    expect(res.ok(), `login ${phone}`).toBeTruthy()
    const body = await res.json()
    return { api: new Api(request, body.accessToken), user: body.user }
  }

  private headers() { return this.token ? { Authorization: `Bearer ${this.token}` } : {} }
  get(path: string) { return this.request.get(`${api}${path}`, { headers: this.headers() }) }
  post(path: string, data: unknown = {}) { return this.request.post(`${api}${path}`, { data, headers: this.headers() }) }
  async json(path: string) { const r = await this.get(path); expect(r.ok(), path).toBeTruthy(); return r.json() }
  async created(path: string, data: unknown) { const r = await this.post(path, data); expect(r.status(), path).toBe(201); return r.json() }
}

const admin = (request: APIRequestContext) => Api.login(request, adminPhone!, adminPassword!).then(r => r.api)

async function newTrainer(a: Api, s = stamp()) {
  const phone = `+99894${s}`
  const t = await a.created('/api/admin/trainers', { phone, password: 'Temp12345', firstName: 'E2E', lastName: `Тренер ${s}` })
  return { ...t, phone, name: `E2E Тренер ${s}` }
}

/** Client created by staff who has already replaced the temporary password, as after a first sign-in. */
async function newClient(request: APIRequestContext, a: Api, s = stamp()) {
  const phone = `+99893${s}`
  const c = await a.created('/api/admin/clients', { phone, password: 'Temp12345', firstName: 'E2E', lastName: `Клиент ${s}` })
  const temp = await Api.login(request, phone, 'Temp12345')
  const changed = await temp.api.post('/api/auth/change-password', { currentPassword: 'Temp12345', newPassword: 'MyOwn12345' })
  expect(changed.ok()).toBeTruthy()
  return { ...c, phone, name: `E2E Клиент ${s}`, api: new Api(request, (await changed.json()).accessToken) }
}

test('trainers: validation, search, closing enrollment, password reset, blocking', async ({ page, request }) => {
  const s = stamp()
  const phone = `+99894${s}`
  const name = `E2E Тренер ${s}`
  await signIn(page)
  await page.getByRole('link', { name: 'Тренеры' }).click()

  async function create() {
    await page.getByRole('button', { name: '+ Новый тренер' }).click()
    const d = page.getByRole('dialog', { name: 'Новый тренер' })
    await d.getByLabel('Имя').fill('E2E')
    await d.getByLabel('Фамилия').fill(`Тренер ${s}`)
    await d.getByLabel('Телефон (логин)').fill(phone)
    await d.getByLabel('Временный пароль').fill('Temp12345')
    await d.getByRole('button', { name: 'Сохранить' }).click()
    return d
  }
  await expect(await create()).toHaveCount(0)
  // Search first: the list is paged and sorted by name, so a new trainer is not necessarily on page 1.
  await page.getByPlaceholder('Имя или телефон').fill(s)
  await page.getByRole('button', { name: 'Найти' }).click()
  await expect(page.getByRole('cell', { name })).toBeVisible()

  // The same phone twice: the API error is shown in the dialog, nothing is created.
  const dup = await create()
  await expect(dup.getByText('Пользователь с таким номером уже существует.')).toBeVisible()
  await dup.getByRole('button', { name: 'Отмена' }).click()

  // Search narrows the list to this trainer.
  await expect(page.locator('tbody tr')).toHaveCount(1)
  const row = page.getByRole('row').filter({ hasText: name })
  await expect(row).toContainText('Открыт')

  // Close enrollment: the trainer stays visible to clients but does not accept requests.
  await row.getByRole('button', { name: 'Изменить' }).click()
  const edit = page.getByRole('dialog', { name: 'Изменить тренера' })
  await edit.getByLabel('Принимает новых клиентов').uncheck()
  await edit.getByRole('button', { name: 'Сохранить' }).click()
  await expect(row).toContainText('Закрыт')
  const a = await admin(request)
  const [saved] = (await a.json(`/api/admin/trainers?search=${s}`)).items
  expect(saved.isAcceptingClients).toBe(false)
  const client = await newClient(request, a)
  const refused = await client.api.post('/api/me/trainer-requests', { trainerId: saved.id })
  expect((await refused.json()).code).toBe('trainer_not_accepting')

  // Password reset: a new temporary password that must be changed at the next sign-in.
  await row.getByRole('button', { name: 'Пароль' }).click()
  const reset = page.getByRole('dialog', { name: 'Новый пароль' })
  await reset.getByLabel('Временный пароль').fill('Reset12345')
  await reset.getByRole('button', { name: 'Сохранить' }).click()
  await expect(reset.getByText('Временный пароль установлен.')).toBeVisible()
  await reset.getByRole('button', { name: 'Готово' }).click()
  const trainer = await Api.login(request, phone, 'Reset12345')
  expect(trainer.user.mustChangePassword).toBe(true)
  expect((await request.post(`${api}/api/auth/login`, { data: { phone, password: 'Temp12345' } })).status()).toBe(401)

  // Blocking: the account can no longer sign in.
  await row.getByRole('button', { name: 'Изменить' }).click()
  await edit.getByLabel('Статус аккаунта').selectOption('Blocked')
  await edit.getByRole('button', { name: 'Сохранить' }).click()
  await expect(row).toContainText('Заблокирован')
  const blocked = await request.post(`${api}/api/auth/login`, { data: { phone, password: 'Reset12345' } })
  expect(blocked.status()).toBe(403)
  expect((await blocked.json()).code).toBe('account_blocked')
})

test('requests: reject with a reason, status tabs, repeated processing is refused', async ({ page, request }) => {
  const a = await admin(request)
  const trainer = await newTrainer(a)
  const client = await newClient(request, a)
  const req = await client.api.created('/api/me/trainer-requests', { trainerId: trainer.id, message: 'E2E: хочу тренироваться' })

  await signIn(page)
  await page.getByRole('link', { name: 'Заявки' }).click()
  const row = page.getByRole('row').filter({ hasText: client.name })
  await expect(row).toContainText('Ожидает')
  await expect(row).toContainText(trainer.name)

  page.once('dialog', d => d.accept('Нет свободных мест'))
  await row.getByRole('button', { name: 'Отклонить' }).click()
  await expect(row).toHaveCount(0) // gone from the "Ожидает" tab

  await page.getByRole('button', { name: 'Отклонена' }).click()
  await expect(row).toContainText('Отклонена')
  await expect(row).toContainText('Ответ: Нет свободных мест')
  await expect(row.getByRole('button', { name: 'Принять' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Все' }).click()
  await expect(row).toContainText('Отклонена')

  // The client sees the decision; a second decision on the same request is refused.
  const mine = await client.api.json('/api/me/trainer-requests')
  expect(mine.find((r: { id: string }) => r.id === req.id).status).toBe('Rejected')
  const notifications = await client.api.json('/api/notifications')
  expect(notifications.items.some((n: { type: string; relatedEntityId: string }) =>
    n.type === 'TrainerRequestRejected' && n.relatedEntityId === req.id)).toBe(true)
  const again = await a.post(`/api/admin/trainer-requests/${req.id}/accept`, { comment: null })
  expect(again.status()).toBe(409)
  expect((await again.json()).code).toBe('request_not_pending')
  expect((await client.api.json('/api/me/profile')).assignedTrainer).toBeNull()
})

test('reports: figures come from the API, change with new data and follow the date range', async ({ page, request }) => {
  const a = await admin(request)
  await signIn(page)
  await page.getByRole('link', { name: 'Отчёты' }).click()
  const from = await page.getByLabel('С', { exact: true }).inputValue()
  const to = await page.getByLabel('По', { exact: true }).inputValue()
  const stat = (label: string) => page.locator('.stat').filter({ hasText: label }).locator('.stat-value')

  const before = await a.json(`/api/admin/reports/summary?from=${from}&to=${to}`)
  await expect(stat('Выдано абонементов')).toHaveText(String(before.membershipsAssigned))
  await expect(stat('Посещений')).toHaveText(String(before.visits))
  await expect(stat('Новых клиентов')).toHaveText(String(before.newClients))

  // New client with a membership and a visit today.
  const plan = await a.created('/api/admin/membership-plans',
    { name: `E2E отчёт ${stamp()}`, type: 'Unlimited', durationDays: 30, price: 0 })
  const client = await newClient(request, a)
  await a.created('/api/admin/memberships', { clientId: client.id, planId: plan.id })
  await a.created('/api/admin/visits', { clientId: client.id })

  await page.getByRole('link', { name: 'Обзор' }).click()
  await page.getByRole('link', { name: 'Отчёты' }).click()
  await expect(stat('Выдано абонементов')).toHaveText(String(before.membershipsAssigned + 1))
  await expect(stat('Посещений')).toHaveText(String(before.visits + 1))
  await expect(stat('Новых клиентов')).toHaveText(String(before.newClients + 1))
  await expect(page.getByRole('row').filter({ hasText: plan.name })).toContainText('1')

  // A period before the club existed in the system: no data.
  await page.getByLabel('С', { exact: true }).fill('2020-01-01')
  await page.getByLabel('По', { exact: true }).fill('2020-01-31')
  await expect(stat('Выдано абонементов')).toHaveText('0')
  await expect(stat('Посещений')).toHaveText('0')
  await expect(page.getByText('Нет посещений за период')).toBeVisible()
})

test('pagination: the second page of trainers shows the next records without repeats', async ({ page, request }) => {
  const a = await admin(request)
  const { totalCount } = await a.json('/api/admin/trainers?pageSize=1')
  for (let i = totalCount; i < 21; i++) await newTrainer(a) // a second page needs more than 20

  await signIn(page)
  await page.getByRole('link', { name: 'Тренеры' }).click()
  const phones = () => page.locator('tbody tr td:nth-child(2)').allTextContents()
  await expect(page.locator('.pagination-page')).toHaveText(/^1 \/ \d+$/)
  const first = await phones()
  expect(first).toHaveLength(20)

  await page.getByRole('button', { name: 'Вперёд ›' }).click()
  await expect(page.locator('.pagination-page')).toHaveText(/^2 \/ \d+$/)
  const second = await phones()
  expect(second.length).toBeGreaterThan(0)
  expect(second.filter(p => first.includes(p))).toEqual([])

  // Same pages through the API: together they list distinct trainers.
  const p1 = await a.json('/api/admin/trainers?page=1&pageSize=20')
  const p2 = await a.json('/api/admin/trainers?page=2&pageSize=20')
  expect(p2.page).toBe(2)
  expect(new Set([...p1.items, ...p2.items].map((t: { id: string }) => t.id)).size).toBe(p1.items.length + p2.items.length)
})
