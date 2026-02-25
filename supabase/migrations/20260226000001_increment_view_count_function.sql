-- Increment view_count on a broadcast.
-- SECURITY DEFINER so normal users (who lack UPDATE on broadcasts) can call it.
CREATE OR REPLACE FUNCTION public.increment_view_count(broadcast_uuid UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE broadcasts
       SET view_count = COALESCE(view_count, 0) + 1
     WHERE id = broadcast_uuid;
END;
$$;

-- Allow any authenticated user to call the function
GRANT EXECUTE ON FUNCTION public.increment_view_count(UUID) TO authenticated;
