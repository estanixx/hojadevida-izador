'use client';

interface AdditionalInfoStepProps {
  additionalInformation: string;
  onChange: (value: string) => void;
  onBack: () => void;
  onGenerate: () => void;
}

const inputStyles =
  'w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-white placeholder:text-white/45 backdrop-blur-md focus:border-white/25 focus:outline-none';

export default function AdditionalInfoStep({
  additionalInformation,
  onChange,
  onBack,
  onGenerate,
}: AdditionalInfoStepProps) {
  return (
    <section className="rounded-2xl border border-white/10 bg-white/5 p-6 shadow-lg backdrop-blur-md">
      <h2 className="text-2xl font-semibold text-white">Additional information</h2>
      <p className="mt-1 text-sm text-white/70">
        Add certifications, volunteer work, hobbies, or a brief about-me summary.
      </p>

      <textarea
        value={additionalInformation}
        onChange={(event) => onChange(event.target.value)}
        rows={9}
        placeholder="Anything else you'd like to include in your CV..."
        className={`${inputStyles} mt-6 resize-none`}
      />

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
          onClick={onGenerate}
          className="rounded-lg border border-white/10 bg-white/10 px-5 py-2 text-sm font-medium text-white transition hover:bg-white/20"
        >
          Generate CV
        </button>
      </div>
    </section>
  );
}
