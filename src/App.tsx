import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from '@/features/auth/AuthProvider';
import { AppRoutes } from '@/router';

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  );
}
