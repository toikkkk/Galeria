import { useState } from "react";
import { login } from "./api.js";

export default function Login({ onSukses, pesan }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [lihat, setLihat] = useState(false);
  const [error, setError] = useState(pesan || "");
  const [kirim, setKirim] = useState(false);
  const [ingat, setIngat] = useState(false);
  const [capsLock, setCapsLock] = useState(false);
  const [lupa, setLupa] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setError("");
    setKirim(true);
    try {
      await login(email.trim(), password, ingat);
      onSukses();
    } catch (err) {
      setError(err.message);
      setPassword("");
    } finally {
      setKirim(false);
    }
  }

  return (
    <main className="login-wrap">
      <form className="card login" onSubmit={submit} aria-labelledby="h-login">
        <div className="login-kop">
          <h1 className="nama" id="h-login">GALERIA</h1>
          <span className="garis" aria-hidden="true" />
          <span className="peran">PANEL ADMIN</span>
        </div>
        <p className="login-sapa">Selamat datang kembali.<br />Masuk untuk melihat pendapatan dan perkembangan pengguna Pro.</p>

        {error && <div className="login-error" role="alert">{error}</div>}

        <label htmlFor="email">Email</label>
        <input id="email" type="email" autoComplete="username" required autoFocus
          value={email} onChange={(e) => setEmail(e.target.value)} />

        <label htmlFor="password">Password</label>
        <div className="pw">
          <input id="password" type={lihat ? "text" : "password"} autoComplete="current-password" required
            value={password} onChange={(e) => setPassword(e.target.value)}
            onKeyUp={(e) => setCapsLock(e.getModifierState("CapsLock"))}
            onKeyDown={(e) => setCapsLock(e.getModifierState("CapsLock"))}
            onBlur={() => setCapsLock(false)} />
          <button type="button" className="link" onClick={() => setLihat((v) => !v)} aria-pressed={lihat}>
            {lihat ? "Sembunyikan" : "Tampilkan"}
          </button>
        </div>
        {capsLock && <p className="login-caps" role="status">Caps Lock sedang aktif</p>}

        <div className="login-opsi">
          <label className="ingat">
            <input type="checkbox" checked={ingat} onChange={(e) => setIngat(e.target.checked)} />
            Ingat saya selama 7 hari
          </label>
          <button type="button" className="link" aria-expanded={lupa} onClick={() => setLupa((v) => !v)}>
            Lupa password?
          </button>
        </div>
        {lupa && (
          <p className="login-lupa">
            Akun admin tidak memakai email pemulihan. Minta pengembang membuat password baru dengan
            {" "}<code>python scripts/buat_hash_admin.py</code> di folder backend, lalu memperbarui <code>ADMIN_PASSWORD_HASH</code> di <code>.env</code>.
          </p>
        )}

        <button type="submit" className="btn-masuk" disabled={kirim || !email || !password}>
          {kirim ? "Memeriksa…" : "Masuk"}
        </button>
      </form>
      <p className="login-kaki">© GALERIA · Khusus pengelola platform</p>
    </main>
  );
}
