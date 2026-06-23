import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { getToken } from "./auth";
import LandingPage from "./pages/LandingPage";
import LoginPage from "./pages/LoginPage";
import DrawListPage from "./pages/DrawListPage";
import DrawFormPage from "./pages/DrawFormPage";
import DrawDetailPage from "./pages/DrawDetailPage";
import AppLayout from "./components/AppLayout";

function RequireAuth({ children }: { children: JSX.Element }) {
  const loc = useLocation();
  if (!getToken()) return <Navigate to="/login" replace state={{ from: loc.pathname }} />;
  return <AppLayout>{children}</AppLayout>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/draws" element={<RequireAuth><DrawListPage /></RequireAuth>} />
      <Route path="/draws/new" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/draws/edit/:category/:issue" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/draws/:category/:issue" element={<RequireAuth><DrawDetailPage /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
