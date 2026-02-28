'use client';

import { useState } from 'react';

interface SkillsStepProps {
  skills: string[];
  onAddSkill: (skill: string) => void;
  onRemoveSkill: (skill: string) => void;
  setIsSkillInputFocused: (focused: boolean) => void;
  onBack: () => void;
  onNext: () => void;
  submitLabel?: string;
}

const inputStyles =
  'w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-white placeholder:text-white/45 backdrop-blur-md focus:border-white/25 focus:outline-none';

export default function SkillsStep({
  skills,
  onAddSkill,
  onRemoveSkill,
  setIsSkillInputFocused,
  onBack,
  onNext,
  submitLabel = 'Next',
}: SkillsStepProps) {
  const [skillInput, setSkillInput] = useState('');

  const addSkill = () => {
    const normalized = skillInput.trim();
    if (!normalized) {
      return;
    }

    onAddSkill(normalized);
    setSkillInput('');
  };

  const handleSkillKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      event.stopPropagation();
      addSkill();
    }
  };

  return (
    <section className="rounded-2xl border border-white/10 bg-white/5 p-6 shadow-lg backdrop-blur-md">
      <h2 className="text-2xl font-semibold text-white">Skills</h2>
      <p className="mt-1 text-sm text-white/70">
        Add your skills as tags. Press Enter to create each tag.
      </p>

      <div className="mt-6 flex gap-3">
        <input
          value={skillInput}
          onChange={(event) => setSkillInput(event.target.value)}
          onKeyDown={handleSkillKeyDown}
          onFocus={() => setIsSkillInputFocused(true)}
          onBlur={() => setIsSkillInputFocused(false)}
          placeholder="Type a skill and press Enter"
          className={inputStyles}
        />
        <button
          type="button"
          onClick={addSkill}
          className="rounded-lg border border-white/10 bg-white/10 px-4 py-2 text-sm text-white transition hover:bg-white/20"
        >
          Add
        </button>
      </div>

      <div className="mt-4 flex min-h-12 flex-wrap gap-2">
        {skills.map((skill) => (
          <span
            key={skill}
            className="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3 py-1 text-sm text-white"
          >
            {skill}
            <button
              type="button"
              onClick={() => onRemoveSkill(skill)}
              className="text-white/70 transition hover:text-white"
              aria-label={`Remove ${skill}`}
            >
              ×
            </button>
          </span>
        ))}
      </div>

      <div className="mt-6 flex items-center justify-between">
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
          {submitLabel}
        </button>
      </div>
    </section>
  );
}
