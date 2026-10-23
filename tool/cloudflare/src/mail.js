// The accounts' email, sent through Resend. The address goes to Resend and
// nowhere else. A failure says its status and nothing about the address, the
// code or the link.

// The email that carries a one-time code.
export function codeMail(code) {
  return {
    subject: 'Shnayim Mikrah: your code · קוד האימות שלכם',
    text: [
      `Your code is ${code}. It works for 15 minutes.`,
      'If you did not ask for it, you can ignore this email.',
      '',
      `הקוד שלכם הוא ${code}. הוא תקף 15 דקות.`,
      'אם לא ביקשתם אותו, אפשר להתעלם מהודעה זו.',
    ].join('\n'),
  };
}

// The email that carries a password reset link.
export function resetMail(link) {
  return {
    subject: 'Shnayim Mikrah: reset your password · איפוס הסיסמה',
    text: [
      `To choose a new password, open this link within an hour: ${link}`,
      'If you did not ask for it, you can ignore this email.',
      '',
      `כדי לבחור סיסמה חדשה, פתחו את הקישור תוך שעה: ${link}`,
      'אם לא ביקשתם זאת, אפשר להתעלם מהודעה זו.',
    ].join('\n'),
  };
}

export async function sendMail(env, to, { subject, text }) {
  if (!env.RESEND_API_KEY || !env.ACCOUNTS_FROM) throw new Error('email is not configured');
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: env.ACCOUNTS_FROM, to: [to], subject, text }),
  });
  if (!response.ok) throw new Error(`email failed with status ${response.status}`);
}
