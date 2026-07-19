// LaunchRights beta-signup handler.
// Receives a JSON POST from the website form, validates it, and emails it via SES.
// The AWS SDK v3 is provided by the Node.js 22 Lambda runtime — no bundling needed.
import { SESv2Client, SendEmailCommand } from '@aws-sdk/client-sesv2'

const ses = new SESv2Client({})
const SENDER = process.env.SENDER_EMAIL
const RECIPIENT = process.env.RECIPIENT_EMAIL
const API_KEY = process.env.API_KEY

const isEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)

const json = (statusCode, body) => ({
  statusCode,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
})

const escapeHtml = (s) =>
  s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]))

export const handler = async (event) => {
  // Require the shared API key (HTTP API headers are lower-cased).
  if (API_KEY) {
    const provided = (event.headers && event.headers['x-api-key']) || ''
    if (provided !== API_KEY) return json(401, { ok: false, error: 'Unauthorized.' })
  }

  // Parse the body (HTTP API may base64-encode it).
  let data
  try {
    const raw = event.isBase64Encoded
      ? Buffer.from(event.body || '', 'base64').toString('utf8')
      : event.body || ''
    data = JSON.parse(raw || '{}')
  } catch {
    return json(400, { ok: false, error: 'Invalid JSON body.' })
  }

  // Honeypot — bots fill this; accept-and-drop so they don't retry.
  if (data.company) return json(200, { ok: true })

  const name = String(data.name || '').trim()
  const organisation = String(data.organisation || '').trim()
  const email = String(data.email || '').trim()
  const useCase = String(data.useCase || '').trim()
  const message = String(data.message || '').trim().slice(0, 1000)

  const fields = []
  if (!name) fields.push('name')
  if (!organisation) fields.push('organisation')
  if (!isEmail(email)) fields.push('email')
  if (!useCase) fields.push('useCase')
  if (fields.length) {
    return json(400, { ok: false, error: 'Missing or invalid fields.', fields })
  }

  const text = [
    'New LaunchRights beta interest',
    '',
    `Name:         ${name}`,
    `Organisation: ${organisation}`,
    `Email:        ${email}`,
    `Use case:     ${useCase}`,
    `Anything else: ${message || '—'}`,
  ].join('\n')

  const html =
    '<h2>New LaunchRights beta interest</h2>' +
    '<table cellpadding="6" style="font-family:system-ui,sans-serif;font-size:14px">' +
    `<tr><td><strong>Name</strong></td><td>${escapeHtml(name)}</td></tr>` +
    `<tr><td><strong>Organisation</strong></td><td>${escapeHtml(organisation)}</td></tr>` +
    `<tr><td><strong>Email</strong></td><td>${escapeHtml(email)}</td></tr>` +
    `<tr><td><strong>Use case</strong></td><td>${escapeHtml(useCase)}</td></tr>` +
    `<tr><td valign="top"><strong>Anything else</strong></td><td>${message ? escapeHtml(message).replace(/\n/g, '<br>') : '—'}</td></tr>` +
    '</table>'

  try {
    await ses.send(
      new SendEmailCommand({
        FromEmailAddress: SENDER,
        Destination: { ToAddresses: [RECIPIENT] },
        ReplyToAddresses: [email], // replies go straight to the person who signed up
        Content: {
          Simple: {
            Subject: { Data: `LaunchRights beta — ${name} (${organisation})` },
            Body: {
              Text: { Data: text },
              Html: { Data: html },
            },
          },
        },
      }),
    )
  } catch (err) {
    console.error('SES send failed:', err)
    return json(502, { ok: false, error: 'Could not send the message. Please try again.' })
  }

  return json(200, { ok: true })
}
