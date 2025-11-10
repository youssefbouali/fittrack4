import { Amplify } from 'aws-amplify';
import Auth from '@aws-amplify/auth';

export const initializeAuth = (config: {
  region: string;
  userPoolId: string;
  clientId: string;
}) => {
  Amplify.configure({
    Auth: {
      mandatorySignIn: true,
      region: config.region,
      userPoolId: config.userPoolId,
      userPoolWebClientId: config.clientId,
      identityPoolId: process.env.NEXT_PUBLIC_IDENTITY_POOL_ID,
      authenticationFlowType: 'USER_PASSWORD_AUTH',
    } as any,
  });
};


interface User {
  id: string;
  email: string;
  username: string;
  name?: string;
}



export const AuthService = {
  async signup(credentials: { email: string; password: string; username?: string }): Promise<{ userId: string; userSub: string }> {
    try {
      const username = credentials.username || credentials.email;
      const result = await Auth.signUp({
        username,
        password: credentials.password,
        attributes: { email: credentials.email },
      });

      return { userId: result.userSub, userSub: result.userSub };
    } catch (error) {
      throw new Error(error instanceof Error ? error.message : 'Signup failed');
    }
  },

  async signin(credentials: { username: string; password: string }): Promise<{ user: User; accessToken: string; idToken: string }> {
  try {
    const result = await Auth.signIn(credentials.username, credentials.password);
    const session = result.signInUserSession;

    const user: User = {
      id: session.idToken.payload.sub,
      email: session.idToken.payload.email,
      username: result.username,
      name: session.idToken.payload.name,
    };

    localStorage.setItem('auth_token', session.accessToken.jwtToken);
    localStorage.setItem('id_token', session.idToken.jwtToken);

    return { user, accessToken: session.accessToken.jwtToken, idToken: session.idToken.jwtToken };
  } catch (error) {
    throw new Error(error instanceof Error ? error.message : 'Sign in failed');
  }
},

  async signout(): Promise<void> {
    try {
      await Auth.signOut();
      localStorage.removeItem('auth_token');
      localStorage.removeItem('id_token');
    } catch (error) {
      throw new Error(error instanceof Error ? error.message : 'Sign out failed');
    }
  },

  async getCurrentUser(): Promise<User | null> {
    try {
      const cognitoUser = await Auth.currentAuthenticatedUser();
      const idToken = cognitoUser.signInUserSession.idToken;
      return {
        id: idToken.payload.sub,
        email: idToken.payload.email,
        username: cognitoUser.username,
        name: idToken.payload.name,
      };
    } catch {
      return null;
    }
  },

  async getAccessToken(): Promise<string | null> {
    try {
      const session = await Auth.currentSession();
      return session.getAccessToken().getJwtToken();
    } catch {
      return null;
    }
  },

  async getIdToken(): Promise<string | null> {
    try {
      const session = await Auth.currentSession();
      return session.getIdToken().getJwtToken();
    } catch {
      return null;
    }
  },
};
