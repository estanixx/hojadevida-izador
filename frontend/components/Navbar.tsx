'use client';

import { getUserEmail, isAuthenticated } from '@/lib/auth';
import { signOut } from '@aws-amplify/auth';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

const linkClass = (active: boolean) =>
  `rounded-lg border px-3 py-2 text-sm transition ${
    active
      ? 'border-white/25 bg-white/20 text-white'
      : 'border-white/10 bg-white/5 text-white/80 hover:bg-white/15'
  }`;

export default function Navbar() {
  const pathname = usePathname();
  const router = useRouter();
  const [authed, setAuthed] = useState(false);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let mounted = true;

    const loadAuth = async () => {
      try {
        const isAuth = await isAuthenticated();
        if (mounted) {
          setAuthed(isAuth);
          if (isAuth) {
            const email = await getUserEmail();
            if (mounted) {
              setUserEmail(email);
            }
          }
        }
      } finally {
        if (mounted) {
          setIsLoading(false);
        }
      }
    };

    loadAuth();

    return () => {
      mounted = false;
    };
  }, []);

  const handleSignOut = async () => {
    try {
      await signOut();
      setAuthed(false);
      setUserEmail(null);
      router.push('/');
    } catch (error) {
      console.error('Sign out failed:', error);
    }
  };

  return (
    <header className="flex items-center justify-between gap-4">
      <p className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-indigo-100 backdrop-blur-md">
        {userEmail || 'hello@hojadevida-izador.com'}
      </p>

      <nav className="flex items-center gap-2">
        <Link href="/" className={linkClass(pathname === '/')}>
          Home
        </Link>
        {authed && (
          <>
            <Link href="/create-cv" className={linkClass(pathname === '/create-cv')}>
              Create CV
            </Link>
            <Link href="/cvs" className={linkClass(pathname === '/cvs')}>
              My CVs
            </Link>
            <button
              type="button"
              onClick={handleSignOut}
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm text-white/85 backdrop-blur-md cursor-pointer hover:bg-white/10 transition"
            >
              Sign Out
            </button>
          </>
        )}
      </nav>
    </header>
  );
}
