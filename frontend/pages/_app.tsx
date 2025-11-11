import type { AppProps } from 'next/app';
import { useEffect, useState } from 'react';
import { Provider } from 'react-redux';
import { store } from '../store/store';
import { awsConfig, validateAwsConfig } from '../config/aws';
import { AuthService } from '../services/authService';
import dynamic from 'next/dynamic';
import '../styles/globals.css';

const AppContent = dynamic(
  () => import('../components/AppContent'), 
  { ssr: false } 
);

export default function App({ Component, pageProps }: AppProps) {
  return (
    <Provider store={store}>
      <AppContent Component={Component} pageProps={pageProps} />
    </Provider>
  );
}
