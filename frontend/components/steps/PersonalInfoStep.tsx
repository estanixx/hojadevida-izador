'use client';

import { getUserEmail } from '@/lib/auth';
import type { PersonalInfo } from '@/lib/types';
import { useEffect } from 'react';

interface PersonalInfoStepProps {
  data: PersonalInfo;
  onChange: (field: keyof PersonalInfo, value: string) => void;
  social: {
    github: string;
    linkedin: string;
  };
  onChangeSocial: (field: 'github' | 'linkedin', value: string) => void;
  onBack: () => void;
  canGoBack: boolean;
  onNext: () => void;
}

const inputStyles =
  'w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-white placeholder:text-white/45 backdrop-blur-md focus:border-white/25 focus:outline-none';

export default function PersonalInfoStep({
  data,
  onChange,
  social,
  onChangeSocial,
  onBack,
  canGoBack,
  onNext,
}: PersonalInfoStepProps) {
  // Auto-populate email from Cognito user if not already set
  useEffect(() => {
    const autoPopulateEmail = async () => {
      if (!data.email) {
        const email = await getUserEmail();
        if (email) {
          onChange('email', email);
        }
      }
    };
    autoPopulateEmail();
  }, []);

  const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      onNext();
    }
  };

  return (
    <section className="rounded-2xl border border-white/10 bg-white/5 p-6 shadow-lg backdrop-blur-md">
      <h2 className="text-2xl font-semibold text-white">Personal information</h2>
      <p className="mt-1 text-sm text-white/70">Tell us who you are and the role you want next.</p>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <input
          value={data.fullName}
          onChange={(event) => onChange('fullName', event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Full Name"
          className={inputStyles}
        />
        <input
          value={data.email}
          onChange={(event) => onChange('email', event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Email"
          type="email"
          className={inputStyles}
        />
        <input
          value={data.phone}
          onChange={(event) => onChange('phone', event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Phone"
          className={inputStyles}
        />
        <input
          value={data.location}
          onChange={(event) => onChange('location', event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Location"
          className={inputStyles}
        />
      </div>

      <div className="mt-4">
        <input
          value={data.desiredRole}
          onChange={(event) => onChange('desiredRole', event.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Desired Role"
          className={inputStyles}
        />
      </div>

      <div className="mt-6 border-t border-white/10 pt-5">
        <h3 className="text-sm font-semibold uppercase tracking-[0.16em] text-white/70">
          Social Media
        </h3>
        <div className="mt-3 grid gap-4 md:grid-cols-2">
          <input
            value={social.github}
            onChange={(event) => onChangeSocial('github', event.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="GitHub URL"
            className={inputStyles}
          />
          <input
            value={social.linkedin}
            onChange={(event) => onChangeSocial('linkedin', event.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="LinkedIn URL"
            className={inputStyles}
          />
        </div>
      </div>

      <div className="mt-6 flex items-center justify-between">
        <button
          type="button"
          onClick={onBack}
          disabled={!canGoBack}
          className="rounded-lg border border-white/10 px-4 py-2 text-sm text-white transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onNext}
          className="rounded-lg border border-white/10 bg-white/10 px-5 py-2 font-medium text-white transition hover:bg-white/20"
        >
          Next
        </button>
      </div>
    </section>
  );
}
