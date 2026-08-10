// =========================================================
// Gassed — shared Supabase client
// Included via <script> on every page that talks to the database.
// Loads the Supabase JS SDK from a CDN, no build step / npm needed.
//
// SETUP: fill in your project's URL and anon (public) key below.
// Both come from your Supabase project settings -> API.
// The anon key is safe to expose in client-side code — it's the
// public key, and Row Level Security (see supabase/schema.sql)
// is what actually controls who can read/write what.
// =========================================================

const GASSED_SUPABASE_URL = 'https://kxkcjlwnamwziocwwazs.supabase.co';
const GASSED_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4a2NqbHduYW13emlvY3d3YXpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyMjA3MjcsImV4cCI6MjEwMTc5NjcyN30.388qa7tPPP9gl3xlicIkqhGQGbQG2c37YclAEu7bce0';

// Loaded as a classic (non-module) script from the CDN in each HTML file's
// <head>, before this file, so `supabase` is already a global here.
const gassedDb = supabase.createClient(GASSED_SUPABASE_URL, GASSED_SUPABASE_ANON_KEY);

// ---- Small shared helpers used across pages ----

async function gassedGetCurrentPromoter() {
  const { data: { session } } = await gassedDb.auth.getSession();
  if (!session) return null;
  const { data, error } = await gassedDb
    .from('promoters')
    .select('*')
    .eq('id', session.user.id)
    .single();
  if (error) { console.error('gassedGetCurrentPromoter', error); return null; }
  return data;
}

function gassedRequireLogin(redirectTo) {
  gassedDb.auth.getSession().then(({ data: { session } }) => {
    if (!session) window.location.href = redirectTo || '/login/';
  });
}

async function gassedLogout() {
  await gassedDb.auth.signOut();
  window.location.href = '/login/';
}

// Slugify a string for use in event links, e.g. "Ultraviolet" + "Jul 18" -> "ultraviolet-jul18"
function gassedSlugify(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}
