import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  title: 'Hojadevida-izador',
  description: 'Build a polished CV with an interactive guided flow.',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable} min-h-screen antialiased`}>
        <main className="min-h-screen bg-linear-to-br from-[#0B0014] via-[#1A0B2E] to-[#0B0014] bg-size-[200%_200%] animate-gradient-xy text-slate-100">
          {children}
        </main>
      </body>
    </html>
  );
}
