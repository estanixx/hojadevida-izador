'use client';

import FormWizard from '@/components/FormWizard';
import Navbar from '@/components/Navbar';
import { isAuthenticated } from '@/lib/auth';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

export default function CreateCVPage() {
  const router = useRouter();
  const [checking, setChecking] = useState(true);
  const [authed, setAuthed] = useState(false);

  useEffect(() => {
    let mounted = true;

    isAuthenticated()
      .then((result) => {
        if (!mounted) {
          return;
        }

        setAuthed(result);
        setChecking(false);
      })
      .catch(() => {
        if (!mounted) {
          return;
        }

        setAuthed(false);
        setChecking(false);
      });

    return () => {
      mounted = false;
    };
  }, []);

  if (checking) {
    return (
      <div className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-6 text-slate-100">
        <Navbar />
        <p className="mt-10 text-center text-sm text-white/70">Checking authentication...</p>
      </div>
    );
  }

  if (!authed) {
    return (
      <div className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-6 text-slate-100">
        <Navbar />
        <div className="mt-16 rounded-2xl border border-rose-400/20 bg-rose-400/10 p-8 text-center">
          <h1 className="text-2xl font-semibold text-white">Login Required</h1>
          <p className="mt-2 text-sm text-rose-100/90">
            You need to be authenticated before starting CV creation.
          </p>
          <button
            type="button"
            onClick={() => router.push('/')}
            className="mt-5 rounded-lg border border-white/10 bg-white/10 px-5 py-2 text-sm font-medium text-white transition hover:bg-white/20"
          >
            Go to Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-6 text-slate-100">
      <Navbar />
      <FormWizard />
    </div>
  );
}
