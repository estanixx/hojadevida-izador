'use client';

import gsap from 'gsap';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';

function Login() {
  return (
    <button
      type="button"
      disabled
      className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm text-white/85 backdrop-blur-md"
    >
      Login
    </button>
  );
}

export default function Home() {
  const router = useRouter();
  const wrapperRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);
  const [isTransitioning, setIsTransitioning] = useState(false);

  useEffect(() => {
    if (!titleRef.current || !glowRef.current) {
      return;
    }

    gsap.fromTo(
      titleRef.current,
      { opacity: 0, y: 24 },
      { opacity: 1, y: 0, duration: 0.5, ease: 'power2.out' }
    );
  }, []);

  const handleStart = () => {
    if (!wrapperRef.current || isTransitioning) {
      return;
    }

    setIsTransitioning(true);
    gsap.to(wrapperRef.current, {
      opacity: 0,
      duration: 0.45,
      ease: 'power2.inOut',
      onComplete: () => {
        router.push('/create-cv');
      },
    });
  };

  return (
    <div ref={wrapperRef} className="relative flex min-h-screen flex-col px-8 py-6">
      <header className="flex items-center justify-between">
        <p className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-indigo-100 backdrop-blur-md">
          hello@hojadevida-izador.com
        </p>
        <Login />
      </header>

      <section className="relative flex flex-1 flex-col items-center justify-center text-center">
        <div
          ref={glowRef}
          className="pointer-events-none absolute h-60 w-60 rounded-full bg-purple-400/30 blur-3xl"
        />
        <h1
          ref={titleRef}
          className="relative text-5xl font-extrabold tracking-tight text-white md:text-7xl"
        >
          Hojadevida-izador
        </h1>
        <p className="mt-4 max-w-xl text-sm text-indigo-100/90 md:text-base">
          Craft a high-impact CV with guided prompts and polished output.
        </p>
        <button
          type="button"
          onClick={handleStart}
          disabled={isTransitioning}
          className="mt-10 rounded-full border border-white/10 bg-white/5 px-8 py-3 text-lg font-semibold text-white backdrop-blur-md transition hover:bg-white/15 disabled:cursor-not-allowed disabled:opacity-70"
        >
          Create your CV
        </button>
      </section>
    </div>
  );
}
