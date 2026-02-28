export interface PersonalInfo {
  fullName: string;
  email: string;
  phone: string;
  location: string;
  desiredRole: string;
}

export interface ExperienceItem {
  id: string;
  enterpriseName: string;
  fromDate: string;
  toDate: string;
  metrics: string;
  achievements: string;
}

export interface LanguageItem {
  id: string;
  language: string;
  proficiencyLevel: string;
}

export interface CVData {
  personalInfo: PersonalInfo;
  experiences: ExperienceItem[];
  skills: string[];
  languages: LanguageItem[];
  additionalInformation: string;
  summary: string;
  education: {
    institution: string;
    degree: string;
    graduationDate: string;
  }[];
  certifications: string[];
}
