'use client';

import type { LanguageItem } from '@/lib/types';

interface LanguagesStepProps {
  languages: LanguageItem[];
  onChangeLanguage: (index: number, field: keyof LanguageItem, value: string) => void;
  onAddLanguage: () => void;
  onBack: () => void;
  onNext: () => void;
}

const inputStyles =
  'w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-white placeholder:text-white/45 backdrop-blur-md focus:border-white/25 focus:outline-none';

const proficiencyOptions = [
  'Native',
  'C2 - Mastery',
  'C1 - Advanced',
  'B2 - Upper Intermediate',
  'B1 - Intermediate',
  'A2 - Elementary',
  'A1 - Beginner',
];

export default function LanguagesStep({
  languages,
  onChangeLanguage,
  onAddLanguage,
  onBack,
  onNext,
}: LanguagesStepProps) {
  return (
    <section className="rounded-2xl border border-white/10 bg-white/5 p-6 shadow-lg backdrop-blur-md">
      <h2 className="text-2xl font-semibold text-white">Languages</h2>
      <p className="mt-1 text-sm text-white/70">Add each language and your proficiency level.</p>

      <div className="mt-6 space-y-4">
        {languages.map((languageItem, index) => (
          <article
            key={languageItem.id}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <p className="mb-3 text-xs uppercase tracking-[0.18em] text-white/60">
              Language {index + 1}
            </p>

            <div className="grid gap-3 md:grid-cols-2">
              <input
                value={languageItem.language}
                onChange={(event) => onChangeLanguage(index, 'language', event.target.value)}
                placeholder="Language (e.g., English, Spanish)"
                className={inputStyles}
              />

              <select
                value={languageItem.proficiencyLevel}
                onChange={(event) =>
                  onChangeLanguage(index, 'proficiencyLevel', event.target.value)
                }
                className={inputStyles}
              >
                <option value="" className="bg-[#13091f] text-white/80">
                  Select proficiency level
                </option>
                {proficiencyOptions.map((option) => (
                  <option key={option} value={option} className="bg-[#13091f] text-white">
                    {option}
                  </option>
                ))}
              </select>
            </div>
          </article>
        ))}
      </div>

      <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
        <button
          type="button"
          onClick={onAddLanguage}
          className="rounded-lg border border-white/10 bg-white/10 px-4 py-2 text-sm text-white transition hover:bg-white/20"
        >
          Add another language
        </button>

        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onBack}
            className="rounded-lg border border-white/10 px-4 py-2 text-sm text-white transition hover:bg-white/10"
          >
            Back
          </button>
          <button
            type="button"
            onClick={onNext}
            className="rounded-lg border border-white/10 bg-white/10 px-5 py-2 text-sm font-medium text-white transition hover:bg-white/20"
          >
            Next
          </button>
        </div>
      </div>
    </section>
  );
}
