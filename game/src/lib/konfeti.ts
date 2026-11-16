import gsap from 'gsap';

const WARNA = ['#dba12c', '#f0c86a', '#b13232', '#3e251e', '#2f7a2b', '#7d929e', '#fbf6ec'];

/** Ledakan konfeti dari bawah-tengah `host`; elemen dihapus sendiri setelah selesai. */
export function ledakKonfeti(host: HTMLElement, jumlah = 80): void {
  const r = host.getBoundingClientRect();
  for (let i = 0; i < jumlah; i++) {
    const el = document.createElement('span');
    const w = 6 + Math.random() * 8;
    el.style.cssText = `position:absolute;left:${r.width / 2}px;top:${r.height * 0.62}px;width:${w}px;height:${w * 0.5}px;` +
      `background:${WARNA[i % WARNA.length]};border-radius:2px;pointer-events:none;z-index:50;`;
    host.appendChild(el);
    const sudut = -Math.PI / 2 + (Math.random() - 0.5) * 1.9;
    const jarak = 220 + Math.random() * 420;
    gsap.fromTo(
      el,
      { x: 0, y: 0, rotation: 0, opacity: 1 },
      {
        x: Math.cos(sudut) * jarak,
        y: Math.sin(sudut) * jarak,
        rotation: (Math.random() - 0.5) * 900,
        duration: 0.9 + Math.random() * 0.5,
        ease: 'power3.out',
        onComplete: () => {
          gsap.to(el, {
            y: '+=' + (260 + Math.random() * 200),
            x: '+=' + (Math.random() - 0.5) * 140,
            rotation: '+=' + (Math.random() - 0.5) * 540,
            opacity: 0,
            duration: 1.4 + Math.random() * 0.8,
            ease: 'power1.in',
            onComplete: () => el.remove(),
          });
        },
      },
    );
  }
}
