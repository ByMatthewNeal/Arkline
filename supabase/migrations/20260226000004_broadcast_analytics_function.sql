-- Server-side analytics aggregation for broadcast dashboard.
-- Returns a JSON object with totals filtered by a rolling period.

CREATE OR REPLACE FUNCTION get_broadcast_analytics(period_days INT DEFAULT 30)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  p_start TIMESTAMPTZ;
BEGIN
  IF period_days <= 0 THEN
    p_start := '1970-01-01'::TIMESTAMPTZ;
  ELSE
    p_start := NOW() - (period_days || ' days')::INTERVAL;
  END IF;

  SELECT json_build_object(
    'total_broadcasts', COUNT(*)::INT,
    'total_views', COALESCE(SUM(view_count), 0)::INT,
    'total_reactions', COALESCE(SUM(reaction_count), 0)::INT,
    'avg_views_per_broadcast', CASE WHEN COUNT(*) > 0
      THEN ROUND(COALESCE(SUM(view_count), 0)::NUMERIC / COUNT(*), 1)
      ELSE 0 END,
    'avg_reactions_per_broadcast', CASE WHEN COUNT(*) > 0
      THEN ROUND(COALESCE(SUM(reaction_count), 0)::NUMERIC / COUNT(*), 1)
      ELSE 0 END,
    'top_performing_broadcast_id', (
      SELECT id FROM broadcasts
      WHERE status = 'published' AND published_at >= p_start
      ORDER BY view_count DESC NULLS LAST LIMIT 1
    ),
    'most_used_reaction', (
      SELECT emoji FROM broadcast_reactions
      WHERE created_at >= p_start
      GROUP BY emoji ORDER BY COUNT(*) DESC LIMIT 1
    ),
    'period_start', p_start,
    'period_end', NOW()
  ) INTO result
  FROM broadcasts
  WHERE status = 'published' AND published_at >= p_start;

  RETURN result;
END;
$$;
