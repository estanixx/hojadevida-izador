'use client';

import { getIdToken } from '@/lib/auth';
import type { CVData, ExperienceItem, LanguageItem } from '@/lib/types';
import gsap from 'gsap';
import { useEffect, useMemo, useRef, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import ProgressBar from './ProgressBar';
import AdditionalInfoStep from './steps/AdditionalInfoStep';
import ExperienceStep from './steps/ExperienceStep';
import LanguagesStep from './steps/LanguagesStep';
import PersonalInfoStep from './steps/PersonalInfoStep';
import SkillsStep from './steps/SkillsStep';
const createEmptyExperience = (): ExperienceItem => ({
  id: uuidv4(),
  enterpriseName: '',
  fromDate: '',
  toDate: '',
  metrics: '',
  achievements: '',
});

const createEmptyLanguage = (): LanguageItem => ({
  id: uuidv4(),
  language: '',
  proficiencyLevel: '',
});

const initialData: CVData = {
  personalInfo: {
    fullName: '',
    email: '',
    phone: '',
    location: '',
    desiredRole: {
      title: '',
      description: '',
    },
  },
  experiences: [createEmptyExperience()],
  skills: [],
  languages: [createEmptyLanguage()],
  social: {
    github: '',
    linkedin: '',
  },
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
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
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

  const submitCv = async () => {
    if (isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      if (!apiUrl) {
        throw new Error('NEXT_PUBLIC_API_URL is not configured.');
      }

      const token = await getIdToken();

      if (!token) {
        throw new Error('Login required to generate CV.');
      }

      const createResponse = await fetch(`${apiUrl}/cvs/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(cvData),
      });

      if (!createResponse.ok) {
        throw new Error(`Generation failed with status ${createResponse.status}`);
      }

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
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : 'Could not generate CV.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleNext = () => {
    if (isAnimating) {
      return;
    }

    markCurrentStepCompleted();

    if (currentStep === steps.length - 1) {
      submitCv();
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
            social={cvData.social}
            onChangeSocial={(field, value) => {
              setCvData((previous) => ({
                ...previous,
                social: {
                  ...previous.social,
                  [field]: value,
                },
              }));
            }}
            onBack={handleBack}
            canGoBack={currentStep > 0}
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
              isGenerating={isSubmitting}
            />
          </div>
        )}
      </div>

      {submitted && (
        <p className="mt-5 text-center text-sm text-emerald-300">
          All set. Your CV was generated and saved.
        </p>
      )}

      {submitError && <p className="mt-4 text-center text-sm text-rose-300">{submitError}</p>}
    </div>
  );
}
