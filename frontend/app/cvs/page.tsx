'use client';

import Navbar from '@/components/Navbar';
import { getIdToken } from '@/lib/auth';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

interface CvListItem {
  cvId: string;
  name: string;
  createdAt: string;
  downloadUrl: string;
}

export default function CvsPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [items, setItems] = useState<CvListItem[]>([]);

  useEffect(() => {
    const load = async () => {
      try {
        const token = await getIdToken();
        if (!token) {
          router.replace('/');
          return;
        }

        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        if (!apiUrl) {
          throw new Error('Missing NEXT_PUBLIC_API_URL.');
        }

        const response = await fetch(`${apiUrl}/cvs`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        if (!response.ok) {
          throw new Error(`Failed to fetch CVs (${response.status}).`);
        }

        const data = await response.json();
        setItems(data.items ?? []);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unable to load CVs.');
      } finally {
        setLoading(false);
      }
    };

    void load();
  }, [router]);

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-6 text-slate-100">
      <Navbar />

      <section className="mt-8 rounded-2xl border border-white/10 bg-white/5 p-6 shadow-lg backdrop-blur-md">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h1 className="text-2xl font-semibold text-white">Your CVs</h1>
          <Link
            href="/create-cv"
            className="rounded-lg border border-white/10 bg-white/10 px-4 py-2 text-sm font-medium text-white transition hover:bg-white/20"
          >
            Create New CV
          </Link>
        </div>

        {loading && <p className="mt-4 text-sm text-white/70">Loading CVs...</p>}
        {error && <p className="mt-4 text-sm text-rose-300">{error}</p>}

        {!loading && !error && items.length === 0 && (
          <p className="mt-4 text-sm text-white/70">No CVs yet. Create your first one.</p>
        )}

        {!loading && !error && items.length > 0 && (
          <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {items.map((item) => (
              <article
                key={item.cvId}
                className="rounded-xl border border-white/10 bg-black/20 p-4"
              >
                <h2 className="text-lg font-semibold text-white">{item.name}</h2>
                <p className="mt-1 text-xs text-white/70">
                  {new Date(item.createdAt).toLocaleString()}
                </p>
                <a
                  href={item.downloadUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-4 inline-flex rounded-lg border border-white/10 bg-white/10 px-3 py-2 text-sm text-white transition hover:bg-white/20"
                >
                  Download
                </a>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
