'use client';

import gsap from 'gsap';
import { useEffect, useRef } from 'react';

interface ProgressBarProps {
  totalSteps: number;
  currentStep: number;
  completedSteps: boolean[];
  onStepClick: (stepIndex: number) => void;
}

export default function ProgressBar({
  totalSteps,
  currentStep,
  completedSteps,
  onStepClick,
}: ProgressBarProps) {
  const dotRefs = useRef<Array<HTMLSpanElement | null>>([]);
  const prevProgressRef = useRef<boolean[]>(completedSteps);

  useEffect(() => {
    completedSteps.forEach((value, index) => {
      const previousValue = prevProgressRef.current[index] ?? false;
      const dot = dotRefs.current[index];

      if (!dot || !(value && !previousValue)) {
        return;
      }

      gsap.fromTo(
        dot,
        { scale: 0.65, backgroundColor: 'rgba(255,255,255,0)' },
        {
          scale: 1,
          backgroundColor: 'rgba(255,255,255,1)',
          duration: 0.24,
          ease: 'back.out(2)',
        }
      );
    });

    prevProgressRef.current = [...completedSteps];
  }, [completedSteps]);

  return (
    <div className="mb-8 flex items-center justify-center gap-4">
      {Array.from({ length: totalSteps }).map((_, index) => (
        <button
          key={`progress-dot-${index}`}
          type="button"
          onClick={() => onStepClick(index)}
          className="relative flex h-6 w-6 items-center justify-center"
          aria-label={`Go to step ${index + 1}`}
        >
          {currentStep === index && (
            <span className="absolute inline-flex h-5 w-5 rounded-full bg-white/40 animate-ping" />
          )}
          <span
            ref={(element) => {
              dotRefs.current[index] = element;
            }}
            className={`relative h-3.5 w-3.5 rounded-full border border-white transition-colors ${
              completedSteps[index] || currentStep === index ? 'bg-white' : 'bg-transparent'
            }`}
          />
        </button>
      ))}
    </div>
  );
}
