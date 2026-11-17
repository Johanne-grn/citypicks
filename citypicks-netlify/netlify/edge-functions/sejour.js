// CityPick's · Passerelle « Formulaire → Webhook n8n »
// Le formulaire du site (page Planificateur) envoie ici la demande de séjour + l'e-mail du voyageur.
// Cette fonction vérifie la demande puis la transmet au webhook n8n, où l'orchestrateur
// délègue aux agents (Planificateur, Conseiller, Rédacteur) avant la validation humaine.
// L'adresse du webhook reste secrète : variable d'environnement Netlify N8N_WEBHOOK_URL.

const env = k => (globalThis.Netlify?.env?.get(k)) ?? globalThis.process?.env?.[k];

const CITIES = { paris: "Paris", londres: "Londres", madrid: "Madrid", barcelone: "Barcelone", lisbonne: "Lisbonne", rome: "Rome", berlin: "Berlin", amsterdam: "Amsterdam", prague: "Prague", vienne: "Vienne", copenhague: "Copenhague", budapest: "Budapest" };
const BUDGETS = { free: "Gratuit", p1: "€ (moins de 15 €)", p2: "€€ (15 à 40 €)", p3: "€€€ (sans limite)" };
const CATS = ["Restaurant", "Activité", "Bar & nuit", "Culture"];

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" } });

export default async (req) => {
  const hook = env("N8N_WEBHOOK_URL");
  // GET : le site demande si l'envoi à l'équipe est disponible (pour afficher ou non le bouton)
  if (req.method === "GET") return json({ enabled: !!hook });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée." }, 405);
  if (!hook) return json({ error: "L'envoi à l'équipe n'est pas encore activé." }, 503);

  let b;
  try { b = await req.json(); } catch { return json({ error: "Requête invalide." }, 400); }
  const city = String(b?.city || "");
  if (!CITIES[city]) return json({ error: "Choisissez une ville parmi les 12 villes CityPick's." }, 400);
  const email = String(b?.email || "").trim().slice(0, 120);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "Indiquez une adresse e-mail valide." }, 400);
  if (b?.consent !== true) return json({ error: "Cochez la case pour accepter l'envoi par e-mail." }, 400);
  const budget = BUDGETS[b?.budget] ? b.budget : "p2";
  const demande = {
    city, cityName: CITIES[city],
    days: Math.min(5, Math.max(1, parseInt(b?.days, 10) || 2)),
    budget, budgetLabel: BUDGETS[budget],
    interests: (Array.isArray(b?.interests) ? b.interests : []).filter(c => CATS.includes(c)),
    note: String(b?.note || "").replace(/\s+/g, " ").trim().slice(0, 200),
    email,
    receivedAt: new Date().toISOString()
  };

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 10000);
  try {
    const r = await fetch(hook, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(demande), signal: ctrl.signal });
    if (!r.ok) { console.error("n8n", r.status, (await r.text()).slice(0, 300)); return json({ error: "L'équipe d'agents n'est pas joignable pour l'instant. Réessayez plus tard." }, 502); }
  } catch {
    return json({ error: "L'équipe d'agents n'est pas joignable pour l'instant. Réessayez plus tard." }, 502);
  } finally { clearTimeout(timer); }
  return json({ ok: true });
};

export const config = { path: "/api/sejour" };
