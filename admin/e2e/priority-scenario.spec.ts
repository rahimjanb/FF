import { expect, test, type APIRequestContext, type Page } from '@playwright/test'

// Priority scenario of stage 1, against a REAL running backend:
//   admin creates trainer + client and assigns a membership (browser)
//   → client signs in with the temporary password, must change it, sees the membership and requests the trainer (API)
//   → the request is processed in the admin panel (browser).
// Requires ADMIN_PHONE / ADMIN_PASSWORD of an existing administrator.
const adminPhone = process.env.ADMIN_PHONE
const adminPassword = process.env.ADMIN_PASSWORD
const api = 'http://localhost:5080'

test.skip(!adminPhone || !adminPassword, 'Set ADMIN_PHONE and ADMIN_PASSWORD')

async function signIn(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Номер телефона').fill(adminPhone!)
  await page.getByLabel('Пароль').fill(adminPassword!)
  await page.getByRole('button', { name: 'Войти' }).click()
  await expect(page.getByRole('heading', { name: 'Обзор' })).toBeVisible()
}

async function post(request: APIRequestContext, path: string, data: unknown, token?: string) {
  return request.post(`${api}${path}`, { data, headers: token ? { Authorization: `Bearer ${token}` } : {} })
}

test('admin → client → trainer request → admin processes it', async ({ page, request }) => {
  const stamp = Date.now().toString().slice(-7)
  const planName = `E2E план ${stamp}`
  const clientPhone = `+99893${stamp}`
  const trainerPhone = `+99894${stamp}`
  const clientName = `E2E Клиент ${stamp}`
  const trainerName = `E2E Тренер ${stamp}`

  await signIn(page)
  await expect(page.getByText('Клиентов всего')).toBeVisible()

  // Trainer
  await page.getByRole('link', { name: 'Тренеры' }).click()
  await page.getByRole('button', { name: '+ Новый тренер' }).click()
  const trainerDialog = page.getByRole('dialog', { name: 'Новый тренер' })
  await trainerDialog.getByLabel('Имя').fill('E2E')
  await trainerDialog.getByLabel('Фамилия').fill(`Тренер ${stamp}`)
  await trainerDialog.getByLabel('Телефон (логин)').fill(trainerPhone)
  await trainerDialog.getByLabel('Временный пароль').fill('Temp12345')
  await trainerDialog.getByLabel('Специализация').fill('Функциональный тренинг')
  await trainerDialog.getByRole('button', { name: 'Сохранить' }).click()
  await expect(trainerDialog).toHaveCount(0)
  // The list is paged and sorted by name; search so the check does not depend on how many trainers exist.
  await page.getByPlaceholder('Имя или телефон').fill(stamp)
  await page.getByRole('button', { name: 'Найти' }).click()
  await expect(page.getByRole('cell', { name: trainerName })).toBeVisible()

  // Membership plan
  await page.getByRole('link', { name: 'Планы' }).click()
  await page.getByRole('button', { name: '+ Новый план' }).click()
  const planDialog = page.getByRole('dialog', { name: 'Новый план' })
  await planDialog.getByLabel('Название').fill(planName)
  await planDialog.getByLabel('Срок, дней').fill('30')
  await planDialog.getByLabel('Цена, сум').fill('0')
  await planDialog.getByRole('button', { name: 'Сохранить' }).click()
  await expect(page.getByRole('cell', { name: planName })).toBeVisible()

  // Client
  await page.getByRole('link', { name: 'Клиенты' }).click()
  await page.getByRole('button', { name: '+ Новый клиент' }).click()
  const clientDialog = page.getByRole('dialog', { name: 'Новый клиент' })
  await clientDialog.getByLabel('Имя').fill('E2E')
  await clientDialog.getByLabel('Фамилия').fill(`Клиент ${stamp}`)
  await clientDialog.getByLabel('Телефон').fill(clientPhone)
  await clientDialog.getByLabel('Временный пароль').fill('Temp12345')
  await clientDialog.getByRole('button', { name: 'Создать' }).click()
  await expect(page.getByRole('heading', { name: clientName })).toBeVisible()
  await expect(page.getByText('Нет действующего абонемента.')).toBeVisible()

  // Assign membership
  await page.getByRole('button', { name: '+ Назначить' }).click()
  const assign = page.getByRole('dialog', { name: 'Назначить абонемент' })
  await assign.getByLabel('План').selectOption({ label: `${planName} — 30 дн.` })
  await assign.getByRole('button', { name: 'Назначить' }).click()
  await expect(page.getByText(planName).first()).toBeVisible()
  await expect(page.locator('.badge', { hasText: 'Активен' }).first()).toBeVisible()

  // Visit
  await page.getByRole('button', { name: 'Отметить посещение' }).click()
  await expect(page.getByText('Посещение отмечено.')).toBeVisible()

  // --- Client side (what the mobile app does), through the real API ---
  const login = await post(request, '/api/auth/login', { phone: clientPhone, password: 'Temp12345' })
  expect(login.ok()).toBeTruthy()
  const temp = await login.json()
  expect(temp.user.mustChangePassword).toBe(true)
  const gated = await request.get(`${api}/api/me/dashboard`, { headers: { Authorization: `Bearer ${temp.accessToken}` } })
  expect(gated.status()).toBe(403)
  expect((await gated.json()).code).toBe('password_change_required')

  const changed = await post(request, '/api/auth/change-password', { currentPassword: 'Temp12345', newPassword: 'MyOwn12345' }, temp.accessToken)
  expect(changed.ok()).toBeTruthy()
  const token = (await changed.json()).accessToken as string

  const dashboard = await (await request.get(`${api}/api/me/dashboard`, { headers: { Authorization: `Bearer ${token}` } })).json()
  expect(dashboard.currentMembership.planName).toBe(planName)
  expect(dashboard.currentMembership.effectiveStatus).toBe('Active')

  const trainers = await (await request.get(`${api}/api/trainers`, { headers: { Authorization: `Bearer ${token}` } })).json()
  const trainer = trainers.find((t: { lastName: string }) => t.lastName === `Тренер ${stamp}`)
  expect(trainer).toBeTruthy()
  const sent = await post(request, '/api/me/trainer-requests', { trainerId: trainer.id, message: 'E2E: хочу тренироваться' }, token)
  expect(sent.status()).toBe(201)
  const duplicate = await post(request, '/api/me/trainer-requests', { trainerId: trainer.id }, token)
  expect(duplicate.status()).toBe(409)

  // --- Admin processes the request in the panel ---
  await page.getByRole('link', { name: 'Заявки' }).click()
  const row = page.getByRole('row').filter({ hasText: clientName })
  await expect(row).toContainText('Ожидает')
  page.once('dialog', d => d.accept('Добро пожаловать'))
  await row.getByRole('button', { name: 'Принять' }).click()
  await page.getByRole('button', { name: 'Принята' }).click()
  await expect(page.getByRole('row').filter({ hasText: clientName })).toContainText('Принята')

  // Client now sees the assigned trainer
  const after = await (await request.get(`${api}/api/me/dashboard`, { headers: { Authorization: `Bearer ${token}` } })).json()
  expect(after.trainer.lastName).toBe(`Тренер ${stamp}`)

  // Admin panel reflects it
  await page.getByRole('link', { name: 'Тренеры' }).click()
  await page.getByPlaceholder('Имя или телефон').fill(stamp)
  await page.getByRole('button', { name: 'Найти' }).click()
  await expect(page.getByRole('row').filter({ hasText: trainerName })).toContainText('1')
  await page.getByRole('link', { name: 'Отчёты' }).click()
  await expect(page.getByText('Выдано абонементов')).toBeVisible()
})
