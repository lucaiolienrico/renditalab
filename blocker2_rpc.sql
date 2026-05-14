-- ═══════════════════════════════════════════════════════
-- BLOCKER 2: RPC get_my_pending_invites
-- 
-- Sostituisce la query diretta su workspace_invites
-- che dipendeva dalla RLS wi_select_invitee (subquery su auth.users).
-- Questa RPC accede a auth.users con SECURITY DEFINER,
-- eliminando la dipendenza dalla configurazione di accesso
-- del ruolo authenticated alla schema auth.
--
-- ESECUZIONE: Supabase Dashboard → SQL Editor → New Query → Incolla → Run
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_my_pending_invites()
RETURNS TABLE (
  id            UUID,
  workspace_id  UUID,
  role          TEXT,
  invited_by    UUID,
  created_at    TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_email TEXT;
BEGIN
  -- Recupera l'email dell'utente autenticato (accesso privilegiato a auth.users)
  SELECT email INTO v_email
    FROM auth.users
    WHERE id = auth.uid();

  IF v_email IS NULL THEN
    -- Utente non autenticato o email non trovata
    RETURN;
  END IF;

  RETURN QUERY
    SELECT
      i.id,
      i.workspace_id,
      i.role,
      i.invited_by,
      i.created_at,
      i.expires_at
    FROM public.workspace_invites i
    WHERE i.status = 'pending'
      AND i.expires_at > now()
      AND lower(i.invited_email) = lower(v_email)
    ORDER BY i.created_at DESC;
END;
$$;

-- Permesso di esecuzione per utenti autenticati
GRANT EXECUTE ON FUNCTION public.get_my_pending_invites() TO authenticated;
