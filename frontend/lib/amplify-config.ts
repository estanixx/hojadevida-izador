import { Amplify } from 'aws-amplify';

/**
 * Initialize AWS Amplify with Cognito configuration
 * Environment variables (provided at build time via CI/CD or .env.local):
 * - NEXT_PUBLIC_AWS_REGION: AWS region (default: us-east-1)
 * - NEXT_PUBLIC_COGNITO_USER_POOL_ID: Cognito User Pool ID from serverless deploy
 * - NEXT_PUBLIC_COGNITO_CLIENT_ID: Cognito App Client ID from serverless deploy
 */
export const configureAmplify = () => {
  const userPoolId = process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID;
  const clientId = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID;

  if (!userPoolId || !clientId) {
    console.warn(
      'Amplify not fully configured: missing NEXT_PUBLIC_COGNITO_USER_POOL_ID or NEXT_PUBLIC_COGNITO_CLIENT_ID. ' +
        'Auth features will not work. Check your .env.local or build arguments.'
    );
    return;
  }

  Amplify.configure({
    Auth: {
      Cognito: {
        userPoolId,
        userPoolClientId: clientId,
        signUpVerificationMethod: 'code',
        loginWith: {
          email: true,
        },
        passwordFormat: {
          minLength: 8,
          requireNumbers: true,
          requireSpecialCharacters: true,
          requireUppercase: true,
          requireLowercase: true,
        },
      },
    },
  });
};

export default configureAmplify;
