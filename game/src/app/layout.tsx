import type { Metadata, Viewport } from 'next';
import { EB_Garamond, Inter } from 'next/font/google';
import './globals.css';

const serif = EB_Garamond({ subsets: ['latin'], variable: '--font-serif', display: 'swap' });
const sans = Inter({ subsets: ['latin'], variable: '--font-sans', display: 'swap' });

export const metadata: Metadata = {
  title: 'Tebak Lukisan · GALERIA',
  description: 'Game pameran GALERIA: tebak pelukis dan aliran dari sebuah lukisan.',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#3e251e',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" className={`${serif.variable} ${sans.variable}`}>
      <body>{children}</body>
    </html>
  );
}
