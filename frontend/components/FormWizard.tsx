'use client';

import type { CVData, ExperienceItem, LanguageItem } from '@/lib/types';
import gsap from 'gsap';
import { useEffect, useMemo, useRef, useState } from 'react';
import ProgressBar from './ProgressBar';
import AdditionalInfoStep from './steps/AdditionalInfoStep';
import ExperienceStep from './steps/ExperienceStep';
import LanguagesStep from './steps/LanguagesStep';
import PersonalInfoStep from './steps/PersonalInfoStep';
import SkillsStep from './steps/SkillsStep';

const createEmptyExperience = (): ExperienceItem => ({
  id: crypto.randomUUID(),
  enterpriseName: '',
  fromDate: '',
  toDate: '',
  metrics: '',
  achievements: '',
});

const createEmptyLanguage = (): LanguageItem => ({
  id: crypto.randomUUID(),
  language: '',
  proficiencyLevel: '',
});

const initialData: CVData = {
  personalInfo: {
    fullName: '',
    email: '',
    phone: '',
    location: '',
    desiredRole: '',
  },
  experiences: [createEmptyExperience()],
  skills: [],
  languages: [createEmptyLanguage()],
  additionalInformation: '',
  summary: '',
  education: [],
  certifications: [],
};

export default function FormWizard() {
  const [cvData, setCvData] = useState<CVData>(initialData);
  const [currentStep, setCurrentStep] = useState(0);
  const [completedSteps, setCompletedSteps] = useState<boolean[]>([
    false,
    false,
    false,
    false,
    false,
  ]);
  const [submitted, setSubmitted] = useState(false);
  const [isSkillsInputFocused, setIsSkillsInputFocused] = useState(false);
  const [isAnimating, setIsAnimating] = useState(false);
  const stepRef = useRef<HTMLDivElement>(null);
  const successPulseRef = useRef<HTMLDivElement>(null);

  const steps = useMemo(
    () => [
      {
        id: 'personal',
        label: 'Personal Info',
      },
      {
        id: 'experience',
        label: 'Experience',
      },
      {
        id: 'skills',
        label: 'Skills',
      },
      {
        id: 'languages',
        label: 'Languages',
      },
      {
        id: 'additional',
        label: 'Additional Info',
      },
    ],
    []
  );

  useEffect(() => {
    if (!stepRef.current) {
      return;
    }

    gsap.fromTo(
      stepRef.current,
      { opacity: 0, y: 16 },
      { opacity: 1, y: 0, duration: 0.35, ease: 'power2.out' }
    );
  }, [currentStep]);

  const transitionToStep = (nextStep: number) => {
    if (!stepRef.current || isAnimating || nextStep < 0 || nextStep >= steps.length) {
      return;
    }

    setIsAnimating(true);
    gsap.to(stepRef.current, {
      opacity: 0,
      y: -8,
      duration: 0.2,
      ease: 'power1.inOut',
      onComplete: () => {
        setCurrentStep(nextStep);
        setIsAnimating(false);
      },
    });
  };

  const markCurrentStepCompleted = () => {
    setCompletedSteps((previous) => {
      const next = [...previous];
      next[currentStep] = true;
      return next;
    });
  };

  const handleNext = () => {
    if (isAnimating) {
      return;
    }

    markCurrentStepCompleted();

    if (currentStep === steps.length - 1) {
      setSubmitted(true);
      if (successPulseRef.current) {
        gsap.fromTo(
          successPulseRef.current,
          { boxShadow: '0 0 0px rgba(255,255,255,0.2)' },
          {
            boxShadow: '0 0 45px rgba(167,139,250,0.85)',
            duration: 0.45,
            yoyo: true,
            repeat: 1,
            ease: 'power2.inOut',
          }
        );
      }
      console.log('CV JSON:\n', JSON.stringify(cvData, null, 2));
      return;
    }

    transitionToStep(currentStep + 1);
  };

  const handleBack = () => {
    if (currentStep === 0) {
      return;
    }

    transitionToStep(currentStep - 1);
  };

  const handleStepClick = (stepIndex: number) => {
    transitionToStep(stepIndex);
  };

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Enter' || isSkillsInputFocused) {
        return;
      }

      const target = event.target as HTMLElement | null;
      if (target?.tagName === 'TEXTAREA') {
        return;
      }

      event.preventDefault();
      handleNext();
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  });

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-5xl flex-col justify-center px-6 py-10 text-slate-100">
      <ProgressBar
        totalSteps={steps.length}
        currentStep={currentStep}
        completedSteps={completedSteps}
        onStepClick={handleStepClick}
      />

      <div ref={stepRef}>
        {currentStep === 0 && (
          <PersonalInfoStep
            data={cvData.personalInfo}
            onChange={(field, value) => {
              setCvData((previous) => ({
                ...previous,
                personalInfo: {
                  ...previous.personalInfo,
                  [field]: value,
                },
              }));
            }}
            onNext={handleNext}
          />
        )}

        {currentStep === 1 && (
          <ExperienceStep
            experiences={cvData.experiences}
            onChangeExperience={(index, field, value) => {
              setCvData((previous) => {
                const nextExperiences = [...previous.experiences];
                nextExperiences[index] = {
                  ...nextExperiences[index],
                  [field]: value,
                };

                return {
                  ...previous,
                  experiences: nextExperiences,
                };
              });
            }}
            onAddExperience={() => {
              setCvData((previous) => ({
                ...previous,
                experiences: [...previous.experiences, createEmptyExperience()],
              }));
            }}
            onBack={handleBack}
            onNext={handleNext}
          />
        )}

        {currentStep === 2 && (
          <SkillsStep
            skills={cvData.skills}
            onAddSkill={(skill) => {
              setCvData((previous) => {
                if (previous.skills.includes(skill)) {
                  return previous;
                }

                return {
                  ...previous,
                  skills: [...previous.skills, skill],
                };
              });
            }}
            onRemoveSkill={(skillToRemove) => {
              setCvData((previous) => ({
                ...previous,
                skills: previous.skills.filter((skill) => skill !== skillToRemove),
              }));
            }}
            setIsSkillInputFocused={setIsSkillsInputFocused}
            onBack={handleBack}
            onNext={handleNext}
            submitLabel="Next"
          />
        )}

        {currentStep === 3 && (
          <LanguagesStep
            languages={cvData.languages}
            onChangeLanguage={(index, field, value) => {
              setCvData((previous) => {
                const nextLanguages = [...previous.languages];
                nextLanguages[index] = {
                  ...nextLanguages[index],
                  [field]: value,
                };

                return {
                  ...previous,
                  languages: nextLanguages,
                };
              });
            }}
            onAddLanguage={() => {
              setCvData((previous) => ({
                ...previous,
                languages: [...previous.languages, createEmptyLanguage()],
              }));
            }}
            onBack={handleBack}
            onNext={handleNext}
          />
        )}

        {currentStep === 4 && (
          <div ref={successPulseRef} className="rounded-2xl">
            <AdditionalInfoStep
              additionalInformation={cvData.additionalInformation}
              onChange={(value) => {
                setCvData((previous) => ({
                  ...previous,
                  additionalInformation: value,
                }));
              }}
              onBack={handleBack}
              onGenerate={handleNext}
            />
          </div>
        )}
      </div>

      {submitted && (
        <p className="mt-5 text-center text-sm text-emerald-300">
          All set. Your CV data was logged successfully.
        </p>
      )}
    </div>
  );
}
