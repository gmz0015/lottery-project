import { Navigate, Route, Routes } from "react-router-dom";
import { getToken } from "./auth";
import LoginPage from "./pages/LoginPage";
import DrawListPage from "./pages/DrawListPage";
import DrawFormPage from "./pages/DrawFormPage";
import DrawDetailPage from "./pages/DrawDetailPage";

function RequireAuth({ children }: { children: JSX.Element }) {
  return getToken() ? children : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/" element={<RequireAuth><DrawListPage /></RequireAuth>} />
      <Route path="/new" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/edit/:category/:issue" element={<RequireAuth><DrawFormPage /></RequireAuth>} />
      <Route path="/draw/:category/:issue" element={<RequireAuth><DrawDetailPage /></RequireAuth>} />
    </Routes>
  );
}
