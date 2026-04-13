'use client';

import configureAmplify from '@/lib/amplify-config';
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import { ReactNode, useEffect, useState } from 'react';

interface AmplifyProviderProps {
  children: ReactNode;
}

/**
 * AmplifyProvider: Wraps the app with Amplify Authenticator
 * - Initializes Amplify configuration on mount
 * - Provides login UI if user is not authenticated
 * - Makes auth context available to child components
 *
 * Note: The Authenticator component from @aws-amplify/ui-react provides:
 * - Login/Sign-up forms
 * - Session management
 * - Automatic redirect to login if not authenticated
 */
export function AmplifyProvider({ children }: AmplifyProviderProps) {
  const [isConfigured, setIsConfigured] = useState(false);

  useEffect(() => {
    configureAmplify();
    setIsConfigured(true);
  }, []);

  if (!isConfigured) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-linear-to-br from-[#0B0014] via-[#1A0B2E] to-[#0B0014]">
        <div className="text-slate-200">Initializing...</div>
      </div>
    );
  }

  return <Authenticator>{children}</Authenticator>;
}
