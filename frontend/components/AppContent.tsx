import { useEffect, useState } from 'react';
import { Amplify } from 'aws-amplify';
import { awsConfig, validateAwsConfig } from '../config/aws';
import { AuthService } from '../services/authService';

export default function AppContent({ Component, pageProps }: any) {
  const [isAmplifyConfigured, setAmplifyConfigured] = useState(false);

  useEffect(() => {
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

    setAmplifyConfigured(true);

    const checkAuth = async () => {
      try {
        const user = await AuthService.getCurrentUser();
        if (user) console.log("User logged in:", user);
      } catch (error) {
        console.error(error);
      }
    };

    checkAuth();
  }, []);

  if (!isAmplifyConfigured) return null;
  return <Component {...pageProps} />;
}
