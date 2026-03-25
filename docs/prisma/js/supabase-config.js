const SUPABASE_URL = window.ENV?.SUPABASE_URL;
const SUPABASE_ANON_KEY = window.ENV?.SUPABASE_ANON_KEY;

let supabaseClient = null;

try {
  if (typeof supabase !== "undefined" && SUPABASE_ANON_KEY) {
    supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    window.supabaseClient = supabaseClient;
    console.log("✅ Supabase Client inicializado");
    console.log("📡 URL:", SUPABASE_URL);
  } else {
    console.warn(
      "⚠️ Supabase Client não pode ser inicializado - modo localStorage apenas"
    );
  }
} catch (error) {
  console.error("❌ Erro ao inicializar Supabase Client:", error);
  console.warn("⚠️ Usando modo fallback (localStorage)");
}
