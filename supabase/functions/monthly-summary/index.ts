// Monthly summary email: for every user, a table of the past month's
// expenses, totals with each friend, and what is still remaining.
//
// Triggered by pg_cron on the 1st of each month (see supabase/monthly_email.sql).
// Sends from Gmail via SMTP on port 465 (Supabase blocks 25/587).
//
// Secrets (Edge Functions → Secrets): GMAIL_USER, GMAIL_APP_PASSWORD, CRON_SECRET.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
//
// Request body (all optional):
//   { "month": "2026-10", "only": "someone@gmail.com" }
// "only" sends to just that user, for testing.

import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6";

type Debt = {
  debtor_friend_id: string | null;
  creditor_friend_id: string | null;
  amount_paise: number;
};
type Split = {
  id: string;
  user_id: string;
  title: string;
  total_paise: number;
  payer_friend_id: string | null;
  created_at: string;
  split_debts: Debt[];
};
type Friend = { id: string; user_id: string; name: string };

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
const SETTLEMENT_PREFIX = "Settlement with ";

Deno.serve(async (req) => {
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  const body = await req.json().catch(() => ({}));
  const { start, end, label } = monthRange(body.month);
  const only: string | undefined = body.only?.toLowerCase();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const [users, friends, splits] = await Promise.all([
    listAllUsers(supabase),
    selectAll<Friend>(supabase, "friends", "id, user_id, name"),
    selectAll<Split>(supabase, "split_items", "*, split_debts(*)"),
  ]);

  const mailer = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: Deno.env.get("GMAIL_USER"), pass: Deno.env.get("GMAIL_APP_PASSWORD") },
  });

  const results: { email: string; status: string }[] = [];
  for (const user of users) {
    const email = user.email?.toLowerCase();
    if (!email || (only && email !== only)) continue;

    const userFriends = friends.filter((f) => f.user_id === user.id);
    const userSplits = splits.filter((s) => s.user_id === user.id);
    const report = buildReport(userFriends, userSplits, start, end);
    if (!report.hasContent && !only) {
      results.push({ email, status: "skipped (no activity)" });
      continue;
    }

    const name = (user.user_metadata?.name as string | undefined) ?? "there";
    try {
      await mailer.sendMail({
        from: `"Flox" <${Deno.env.get("GMAIL_USER")}>`,
        to: email,
        subject: `Your Flox summary for ${label}`,
        html: renderEmail(name, label, report),
      });
      results.push({ email, status: "sent" });
    } catch (e) {
      results.push({ email, status: `failed: ${(e as Error).message}` });
    }
  }

  return json({ month: label, results });
});

// ─── Data ────────────────────────────────────────────────────────────────────

/** Calendar month in India time. Defaults to the month before today. */
function monthRange(month?: string) {
  const nowIst = new Date(Date.now() + IST_OFFSET_MS);
  let y = nowIst.getUTCFullYear();
  let m = nowIst.getUTCMonth() - 1; // previous month
  const match = /^(\d{4})-(\d{2})$/.exec(month ?? "");
  if (match) {
    y = Number(match[1]);
    m = Number(match[2]) - 1;
  }
  const start = new Date(Date.UTC(y, m, 1) - IST_OFFSET_MS);
  const end = new Date(Date.UTC(y, m + 1, 1) - IST_OFFSET_MS);
  const label = new Date(Date.UTC(y, m, 1)).toLocaleString("en-IN", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  });
  return { start, end, label };
}

// deno-lint-ignore no-explicit-any
async function listAllUsers(supabase: any) {
  // deno-lint-ignore no-explicit-any
  const users: any[] = [];
  for (let page = 1; ; page++) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    users.push(...data.users);
    if (data.users.length < 1000) return users;
  }
}

// deno-lint-ignore no-explicit-any
async function selectAll<T>(supabase: any, table: string, columns: string): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += 1000) {
    const { data, error } = await supabase.from(table).select(columns).range(from, from + 999);
    if (error) throw error;
    rows.push(...data);
    if (data.length < 1000) return rows;
  }
}

type FriendRow = {
  name: string;
  expenses: number; // shared expenses this month
  sharedTotal: number; // their combined cost
  lent: number; // they owe you from this month
  borrowed: number; // you owe them from this month
  settled: number; // repayments either way this month
  balance: number; // all-time; positive = they owe you
};

type ExpenseRow = { date: Date; title: string; total: number; paidBy: string; yourShare: number };

/** Mirrors the app's Ledger: null ids mean "you". */
function buildReport(friends: Friend[], splits: Split[], start: Date, end: Date) {
  const nameOf = (id: string | null) =>
    id === null ? "You" : friends.find((f) => f.id === id)?.name ?? "Removed friend";

  // All-time balances (same rule as Ledger.netBalances).
  const balance = new Map<string, number>();
  for (const s of splits) {
    for (const d of s.split_debts) {
      if (d.debtor_friend_id === null && d.creditor_friend_id) {
        balance.set(d.creditor_friend_id, (balance.get(d.creditor_friend_id) ?? 0) - d.amount_paise);
      } else if (d.creditor_friend_id === null && d.debtor_friend_id) {
        balance.set(d.debtor_friend_id, (balance.get(d.debtor_friend_id) ?? 0) + d.amount_paise);
      }
    }
  }

  const inMonth = splits
    .filter((s) => {
      const t = new Date(s.created_at);
      return t >= start && t < end;
    })
    .sort((a, b) => a.created_at.localeCompare(b.created_at));

  const rows = new Map<string, FriendRow>();
  const row = (id: string) => {
    if (!rows.has(id)) {
      rows.set(id, {
        name: nameOf(id),
        expenses: 0,
        sharedTotal: 0,
        lent: 0,
        borrowed: 0,
        settled: 0,
        balance: balance.get(id) ?? 0,
      });
    }
    return rows.get(id)!;
  };

  const expenses: ExpenseRow[] = [];
  let youPaid = 0;
  let yourShareTotal = 0;

  for (const s of inMonth) {
    const isSettlement = s.title.startsWith(SETTLEMENT_PREFIX);
    const owedToYou = s.split_debts
      .filter((d) => d.creditor_friend_id === null)
      .reduce((a, d) => a + d.amount_paise, 0);
    const youOwe = s.split_debts
      .filter((d) => d.debtor_friend_id === null)
      .reduce((a, d) => a + d.amount_paise, 0);

    if (isSettlement) {
      for (const d of s.split_debts) {
        const friendId = d.debtor_friend_id ?? d.creditor_friend_id;
        if (friendId) row(friendId).settled += d.amount_paise;
      }
      continue;
    }

    // Your own consumption: what you didn't pass on, or what you owe the payer.
    const yourShare = s.payer_friend_id === null ? s.total_paise - owedToYou : youOwe;
    if (s.payer_friend_id === null) youPaid += s.total_paise;
    yourShareTotal += yourShare;
    expenses.push({
      date: new Date(s.created_at),
      title: s.title,
      total: s.total_paise,
      paidBy: nameOf(s.payer_friend_id),
      yourShare,
    });

    const involved = new Set<string>();
    if (s.payer_friend_id) involved.add(s.payer_friend_id);
    for (const d of s.split_debts) {
      if (d.debtor_friend_id) involved.add(d.debtor_friend_id);
      if (d.creditor_friend_id) involved.add(d.creditor_friend_id);
      if (d.creditor_friend_id === null && d.debtor_friend_id) row(d.debtor_friend_id).lent += d.amount_paise;
      if (d.debtor_friend_id === null && d.creditor_friend_id) row(d.creditor_friend_id).borrowed += d.amount_paise;
    }
    for (const id of involved) {
      row(id).expenses += 1;
      row(id).sharedTotal += s.total_paise;
    }
  }

  // Friends with an open balance appear even if nothing happened this month.
  for (const [id, b] of balance) if (b !== 0) row(id);

  const friendRows = [...rows.values()].sort((a, b) => Math.abs(b.balance) - Math.abs(a.balance));
  const owedToYouNow = [...balance.values()].filter((b) => b > 0).reduce((a, b) => a + b, 0);
  const youOweNow = [...balance.values()].filter((b) => b < 0).reduce((a, b) => a - b, 0);

  return {
    hasContent: inMonth.length > 0 || owedToYouNow > 0 || youOweNow > 0,
    expenses,
    friendRows,
    youPaid,
    yourShareTotal,
    owedToYouNow,
    youOweNow,
  };
}

// ─── Email ───────────────────────────────────────────────────────────────────

const inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" });
const money = (paise: number) => inr.format(paise / 100).replace(".00", "");

function esc(text: string) {
  return text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

const GREEN = "#0E9F6E";
const RED = "#E0245E";

function balanceCell(paise: number) {
  if (paise > 0) return `<span style="color:${GREEN};font-weight:700">Owes you ${money(paise)}</span>`;
  if (paise < 0) return `<span style="color:${RED};font-weight:700">You owe ${money(-paise)}</span>`;
  return `<span style="color:#6B7280">Settled up</span>`;
}

function renderEmail(name: string, month: string, r: ReturnType<typeof buildReport>) {
  const th = 'style="text-align:left;padding:10px 12px;background:#F3F0FF;color:#4C1D95;font-size:12px;text-transform:uppercase;letter-spacing:.5px"';
  const td = 'style="padding:10px 12px;border-top:1px solid #EEE;font-size:14px;color:#111827"';
  const tdr = 'style="padding:10px 12px;border-top:1px solid #EEE;font-size:14px;color:#111827;text-align:right"';
  const table = (head: string, body: string) =>
    `<table width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;border:1px solid #E5E7EB;border-radius:12px;overflow:hidden">${head}${body}</table>`;

  const stat = (label: string, value: string, color: string) =>
    `<td style="padding:6px"><div style="background:${color};border-radius:14px;padding:14px;color:#fff">
       <div style="font-size:11px;opacity:.85;text-transform:uppercase;letter-spacing:.5px">${label}</div>
       <div style="font-size:20px;font-weight:800;margin-top:4px">${value}</div></div></td>`;

  const friendTable = r.friendRows.length
    ? table(
      `<tr><th ${th}>Friend</th><th ${th}>Expenses together</th><th ${th}>You lent</th><th ${th}>You borrowed</th><th ${th}>Settled</th><th ${th}>Remaining</th></tr>`,
      r.friendRows.map((f) =>
        `<tr><td ${td}><b>${esc(f.name)}</b></td>
             <td ${td}>${f.expenses} · ${money(f.sharedTotal)}</td>
             <td ${tdr}>${money(f.lent)}</td>
             <td ${tdr}>${money(f.borrowed)}</td>
             <td ${tdr}>${money(f.settled)}</td>
             <td ${td}>${balanceCell(f.balance)}</td></tr>`
      ).join(""),
    )
    : `<p style="color:#6B7280">No friends to show.</p>`;

  const expenseTable = r.expenses.length
    ? table(
      `<tr><th ${th}>Date</th><th ${th}>Expense</th><th ${th}>Total</th><th ${th}>Paid by</th><th ${th}>Your share</th></tr>`,
      r.expenses.map((e) =>
        `<tr><td ${td}>${e.date.toLocaleDateString("en-IN", { day: "numeric", month: "short", timeZone: "Asia/Kolkata" })}</td>
             <td ${td}>${esc(e.title)}</td>
             <td ${tdr}>${money(e.total)}</td>
             <td ${td}>${esc(e.paidBy)}</td>
             <td ${tdr}>${money(e.yourShare)}</td></tr>`
      ).join(""),
    )
    : `<p style="color:#6B7280">No expenses this month.</p>`;

  return `<!doctype html><html><body style="margin:0;background:#F5F3FF;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif">
  <div style="max-width:680px;margin:0 auto;padding:24px 16px">
    <div style="background:linear-gradient(135deg,#7C4DFF,#FF4D9D,#FF9E44);background-color:#7C4DFF;border-radius:20px;padding:24px;color:#fff">
      <div style="font-size:28px;font-weight:900;letter-spacing:-1px">FLOX</div>
      <div style="font-size:16px;margin-top:6px">Hi ${esc(name)}, here's your summary for <b>${esc(month)}</b>.</div>
    </div>

    <table width="100%" cellspacing="0" cellpadding="0" style="margin:16px 0"><tr>
      ${stat("Expenses", String(r.expenses.length), "#7C4DFF")}
      ${stat("You paid", money(r.youPaid), "#4F8DFD")}
      ${stat("Your share", money(r.yourShareTotal), "#FF8E53")}
    </tr><tr>
      ${stat("Owed to you now", money(r.owedToYouNow), GREEN)}
      ${stat("You owe now", money(r.youOweNow), RED)}
      <td></td>
    </tr></table>

    <h2 style="font-size:18px;color:#111827;margin:24px 0 10px">With your friends</h2>
    ${friendTable}

    <h2 style="font-size:18px;color:#111827;margin:24px 0 10px">All expenses in ${esc(month)}</h2>
    ${expenseTable}

    <p style="color:#6B7280;font-size:12px;margin-top:24px">
      "Your share" is what you actually spent. "Remaining" is the total still open with each friend, across all months.
      Sent automatically by Flox on the 1st of every month.
    </p>
  </div></body></html>`;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });
}
