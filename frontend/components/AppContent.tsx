// components/AppContent.tsx
import { useEffect, useState } from 'react';
import { Amplify } from 'aws-amplify';
import { awsConfig, validateAwsConfig } from '../config/aws';
import { AuthService } from '../services/authService';

export default function AppContent({ Component, pageProps }: any) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    validateAwsConfig();

    Amplify.configure({
      Auth: {
        region: awsConfig.region,
        userPoolId: awsConfig.userPoolId,
        userPoolWebClientId: awsConfig.clientId,
        identityPoolId: awsConfig.identityPoolId,
      },
      Storage: {
        region: awsConfig.region,
        bucket: awsConfig.s3Bucket,
        identityPoolId: awsConfig.identityPoolId,
      },
    });

    setReady(true);

    AuthService.getCurrentUser()
      .then(user => user && console.log('User logged in:', user))
      .catch(console.error);
  }, []);

  if (!ready) return null;
  return <Component {...pageProps} />;
}
