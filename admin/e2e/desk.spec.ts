import { expect, test, type APIRequestContext, type Page } from '@playwright/test'

// Club desk against a REAL running backend: QR check-in, freezing, renewal requests paid at the desk.
// Test data is created with unique "E2E" names; nothing is deleted. Requires ADMIN_PHONE / ADMIN_PASSWORD.
const adminPhone = process.env.ADMIN_PHONE
const adminPassword = process.env.ADMIN_PASSWORD
const api = 'http://localhost:5080'

test.skip(!adminPhone || !adminPassword, 'Set ADMIN_PHONE and ADMIN_PASSWORD')

const stamp = () => Date.now().toString().slice(-7)

async function signIn(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Номер телефона').fill(adminPhone!)
  await page.getByLabel('Пароль').fill(adminPassword!)
  await page.getByRole('button', { name: 'Войти' }).click()
  await expect(page.getByRole('heading', { name: 'Обзор' })).toBeVisible()
}

async function login(request: APIRequestContext, phone: string, password: string) {
  const res = await request.post(`${api}/api/auth/login`, { data: { phone, password } })
  expect(res.ok(), `login ${phone}`).toBeTruthy()
  return (await res.json()).accessToken as string
}

function client(request: APIRequestContext, token: string) {
  const headers = { Authorization: `Bearer ${token}` }
  return {
    get: async (path: string) => { const r = await request.get(`${api}${path}`, { headers }); expect(r.ok(), path).toBeTruthy(); return r.json() },
    post: (path: string, data: unknown = {}) => request.post(`${api}${path}`, { data, headers }),
  }
}

/**
 * A client with a six-month plan of 8 visits who has replaced the temporary password, as after a first sign-in.
 * Six months is the shortest plan that can be frozen.
 */
async function clientWithMembership(request: APIRequestContext) {
  const s = stamp()
  const admin = client(request, await login(request, adminPhone!, adminPassword!))
  const plan = await (await admin.post('/api/admin/membership-plans', {
    name: `E2E План ${s}`, type: 'LimitedVisits', durationDays: 180, visitLimit: 8, price: 250000,
  })).json()
  const phone = `+99895${s}`
  const created = await (await admin.post('/api/admin/clients', { phone, password: 'Temp12345', firstName: 'E2E', lastName: `Пропуск ${s}` })).json()
  expect((await admin.post('/api/admin/memberships', { clientId: created.id, planId: plan.id })).status()).toBe(201)
  const temp = client(request, await login(request, phone, 'Temp12345'))
  const changed = await temp.post('/api/auth/change-password', { currentPassword: 'Temp12345', newPassword: 'MyOwn12345' })
  expect(changed.ok()).toBeTruthy()
  const me = client(request, (await changed.json()).accessToken)
  return { me, plan, id: created.id as string, name: `E2E Пропуск ${s}` }
}

/** The scanner is a keyboard: it types the code and presses Enter. */
async function scan(page: Page, code: string) {
  await page.keyboard.type(code, { delay: 2 })
  await page.keyboard.press('Enter')
}

test('QR pass at the desk: entry is recorded once, can be undone; bad and frozen passes are refused', async ({ page, request }) => {
  const c = await clientWithMembership(request)
  await signIn(page)
  await page.getByRole('link', { name: 'Пропуск' }).click()
  await expect(page.getByText('Готово к сканированию')).toBeVisible()

  const { code } = await c.me.get('/api/me/pass')
  await scan(page, code)
  const result = page.getByTestId('scan-result')
  await expect(result).toContainText('Вход разрешён')
  await expect(result).toContainText(c.name)
  await expect(result).toContainText('1 из 8')
  expect((await c.me.get('/api/me/dashboard')).visits.total).toBe(1)

  // The same code again a moment later is not a second visit.
  await scan(page, code)
  await expect(result).toContainText('Вход уже отмечен')
  await expect(result).toContainText('1 из 8')

  page.once('dialog', d => d.accept())
  await result.getByRole('button', { name: 'Отменить вход' }).click()
  await expect(result).toContainText('Вход отменён')
  expect((await c.me.get('/api/me/dashboard')).visits.total).toBe(0)

  await scan(page, 'HELLO123')
  await expect(result).toContainText('Вход запрещён')
  await expect(result).toContainText('Код не распознан')

  // Freeze on the client card: the pass is refused while frozen, unfreezing restores entry.
  await page.goto(`/clients/${c.id}`)
  const row = page.getByRole('row').filter({ hasText: c.plan.name })
  await row.getByRole('button', { name: 'Заморозить' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog).toContainText('Дней заморозки')
  await dialog.getByRole('button', { name: /Заморозить на 14 дн\./ }).click()
  await expect(row).toContainText('Заморожен')
  await expect(row).toContainText('Заморозка')

  await page.getByRole('link', { name: 'Пропуск' }).click()
  await expect(page.getByText('Готово к сканированию')).toBeVisible()
  await scan(page, (await c.me.get('/api/me/pass')).code)
  await expect(result).toContainText('Абонемент заморожен')

  await page.goto(`/clients/${c.id}`)
  page.once('dialog', d => d.accept())
  await row.getByRole('button', { name: 'Разморозить' }).click()
  await expect(row).toContainText('Активен')
})

test('renewal requested in the app is completed at the desk after payment', async ({ page, request }) => {
  const c = await clientWithMembership(request)
  const sent = await c.me.post('/api/me/membership-requests', { planId: c.plan.id, kind: 'Renew' })
  expect(sent.status()).toBe(201)

  await signIn(page)
  await page.getByRole('link', { name: 'Заявки' }).click()
  await page.getByRole('link', { name: 'На абонемент' }).click()
  const row = page.getByRole('row').filter({ hasText: c.name })
  await expect(row).toContainText('Продление')
  await expect(row).toContainText('Ожидает оплаты')
  await row.getByRole('button', { name: 'Оформить' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Оплачено — оформить' }).click()
  await expect(row).toHaveCount(0) // gone from the pending tab

  await page.getByRole('button', { name: 'Оформлена' }).click()
  await expect(page.getByRole('row').filter({ hasText: c.name })).toContainText('Оформлена')
  const dash = await c.me.get('/api/me/dashboard')
  expect(dash.nextMembership.planId).toBe(c.plan.id)
  expect(dash.nextMembership.startDate > dash.currentMembership.endDate).toBeTruthy()
})
