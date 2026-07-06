import type { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '@/features/auth/AuthProvider';
import { Spinner } from './Spinner';

/** Gates a route behind an authenticated session. */
export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { loading, user, configured } = useAuth();

  if (!configured) return <Navigate to="/login" replace />;
  if (loading) return <Spinner label="Lighting the candles…" />;
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
