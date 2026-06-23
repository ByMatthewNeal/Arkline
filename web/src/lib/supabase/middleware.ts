import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  // Skip auth in development when Supabase isn't configured
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!supabaseUrl || supabaseUrl === 'your_supabase_url_here') {
    return supabaseResponse;
  }

  const supabase = createServerClient(
    supabaseUrl,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const isDashboard = pathname.startsWith('/dashboard');
  const isOnboarding = pathname.startsWith('/onboarding');
  const isAuthPage = pathname === '/login' || pathname === '/signup';

  // Unauthenticated: protect dashboard + onboarding
  if (!user && (isDashboard || isOnboarding)) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url);
  }

  // Authenticated: gate by onboarding completion so users who haven't finished
  // setup (and unpaid/incomplete invites) can't slip straight into the dashboard.
  if (user && (isDashboard || isOnboarding || isAuthPage)) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('onboarding_complete')
      .eq('id', user.id)
      .maybeSingle();
    const onboarded = profile?.onboarding_complete === true;

    if (!onboarded && (isDashboard || isAuthPage)) {
      const url = request.nextUrl.clone();
      url.pathname = '/onboarding';
      return NextResponse.redirect(url);
    }
    if (onboarded && (isOnboarding || isAuthPage)) {
      const url = request.nextUrl.clone();
      url.pathname = '/dashboard';
      return NextResponse.redirect(url);
    }
  }

  return supabaseResponse;
}
