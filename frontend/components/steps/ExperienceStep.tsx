'use client';

import type { ExperienceItem } from '@/lib/types';

interface ExperienceStepProps {
  experiences: ExperienceItem[];
  onChangeExperience: (index: number, field: keyof ExperienceItem, value: string) => void;
  onAddExperience: () => void;
  onBack: () => void;
  onNext: () => void;
}

const inputStyles =
  'w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-white placeholder:text-white/45 backdrop-blur-md focus:border-white/25 focus:outline-none';

export default function ExperienceStep({
  experiences,
  onChangeExperience,
  onAddExperience,
  onBack,
  onNext,
}: ExperienceStepProps) {
  return (
    <section className="rounded-2xl border border-white/10 bg-white/5 p-6 shadow-lg backdrop-blur-md">
      <h2 className="text-2xl font-semibold text-white">Work experience</h2>
      <p className="mt-1 text-sm text-white/70">Add one or multiple roles with clear outcomes.</p>

      <div className="mt-6 space-y-5">
        {experiences.map((experience, index) => (
          <article
            key={experience.id}
            className="rounded-xl border border-white/10 bg-black/20 p-4"
          >
            <p className="text-xs uppercase tracking-[0.18em] text-white/60">
              Experience {index + 1}
            </p>

            <div className="mt-3 grid gap-3 md:grid-cols-3">
              <input
                value={experience.enterpriseName}
                onChange={(event) =>
                  onChangeExperience(index, 'enterpriseName', event.target.value)
                }
                placeholder="Enterprise Name"
                className={inputStyles}
              />
              <input
                value={experience.fromDate}
                onChange={(event) => onChangeExperience(index, 'fromDate', event.target.value)}
                type="date"
                className={inputStyles}
              />
              <input
                value={experience.toDate}
                onChange={(event) => onChangeExperience(index, 'toDate', event.target.value)}
                type="date"
                className={inputStyles}
              />
            </div>

            <div className="mt-3 grid gap-3 md:grid-cols-2">
              <textarea
                value={experience.metrics}
                onChange={(event) => onChangeExperience(index, 'metrics', event.target.value)}
                placeholder="Metrics"
                rows={3}
                className={inputStyles}
              />
              <textarea
                value={experience.achievements}
                onChange={(event) => onChangeExperience(index, 'achievements', event.target.value)}
                placeholder="Achievements"
                rows={3}
                className={inputStyles}
              />
            </div>
          </article>
        ))}
      </div>

      <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
        <button
          type="button"
          onClick={onAddExperience}
          className="rounded-lg border border-white/10 bg-white/10 px-4 py-2 text-sm text-white transition hover:bg-white/20"
        >
          Add another experience
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
