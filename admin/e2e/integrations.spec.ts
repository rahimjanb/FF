import { expect, test, type Page } from '@playwright/test'

// Settings → Integrations against a REAL running backend (dev API with Integrations__EncryptionKey).
// Uses test-mode, format-valid placeholder credentials (not real merchant keys) and removes the secret at the end.
// Requires ADMIN_PHONE / ADMIN_PASSWORD of an administrator allowed to manage integrations.
const adminPhone = process.env.ADMIN_PHONE
const adminPassword = process.env.ADMIN_PASSWORD

test.skip(!adminPhone || !adminPassword, 'Set ADMIN_PHONE and ADMIN_PASSWORD')

async function signIn(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Номер телефона').fill(adminPhone!)
  await page.getByLabel('Пароль').fill(adminPassword!)
  await page.getByRole('button', { name: 'Войти' }).click()
  await expect(page.getByRole('heading', { name: 'Обзор' })).toBeVisible()
}

test('integrations: settings are saved, the secret is only masked and never leaves the server', async ({ page }) => {
  const secret = `E2E-secret-${Date.now()}`
  const bodies: string[] = []
  page.on('response', async r => {
    if (r.url().includes('/api/')) bodies.push(await r.text().catch(() => ''))
  })

  await signIn(page)
  await page.getByRole('link', { name: 'Настройки' }).click()
  await expect(page.getByText('Управление интеграциями')).toBeVisible()
  await page.getByRole('link', { name: 'Интеграции' }).click()

  const click = page.getByTestId('integration-Click')
  const payme = page.getByTestId('integration-Payme')
  await expect(click.getByRole('heading', { name: 'Click' })).toBeVisible()
  await expect(payme.getByRole('heading', { name: 'Payme' })).toBeVisible()
  await expect(page.getByText('Активно')).toHaveCount(0) // never shown without a verified provider request

  // Non-secret fields of the test mode.
  await click.getByLabel('Режим').selectOption('Test')
  await click.getByLabel(/^Service ID/).fill('12345')
  await click.getByLabel(/^Merchant ID/).fill('678')
  await click.getByLabel(/^Merchant User ID/).fill('910')
  await click.getByRole('button', { name: 'Сохранить' }).click()
  await expect(click.getByText('Сохранено')).toBeVisible()

  // Setting the secret is an explicit action; afterwards only a mask is shown.
  await click.getByRole('button', { name: /^(Задать|Заменить)$/ }).click()
  await page.getByLabel(/Secret key \(тестовый режим\)/).fill(secret)
  await page.getByRole('button', { name: 'Сохранить ключ' }).click()
  await expect(click.getByText('••••••••')).toBeVisible()
  await expect(click.getByText('Настроено')).toBeVisible()

  await page.reload()
  await expect(page.getByTestId('integration-Click').getByText('••••••••')).toBeVisible()
  expect(bodies.join('\n')).not.toContain(secret)
  expect(await page.content()).not.toContain(secret)
  const storage = await page.evaluate(() => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage }))
  expect(storage).not.toContain(secret)

  // Removing requires confirmation.
  const clickAfter = page.getByTestId('integration-Click')
  await clickAfter.getByRole('button', { name: 'Удалить' }).click()
  await expect(page.getByText('Ключ будет удалён без возможности восстановления.')).toBeVisible()
  await page.getByRole('dialog').getByRole('button', { name: 'Удалить' }).click()
  await expect(clickAfter.getByText('Не задан')).toBeVisible()
  await expect(clickAfter.getByText('Не настроено')).toBeVisible()

  // The audit lists the actions without values.
  await clickAfter.getByRole('button', { name: 'Журнал' }).click()
  await expect(clickAfter.getByText('Удалён ключ').first()).toBeVisible()
  await expect(clickAfter.getByText(secret)).toHaveCount(0)
})
