import { NextResponse, type NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  // Only protect /app/* routes
  if (request.nextUrl.pathname.startsWith('/app')) {
    // Check for Supabase auth cookie (sb-<ref>-auth-token)
    const hasAuthCookie = request.cookies.getAll().some(
      (cookie) => cookie.name.startsWith('sb-') && cookie.name.endsWith('-auth-token')
    )

    if (!hasAuthCookie) {
      const url = request.nextUrl.clone()
      url.pathname = '/login'
      return NextResponse.redirect(url)
    }
  }

  return NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
