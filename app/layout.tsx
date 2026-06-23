import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "FOLKLORAŠ",
  description: "Aplikacija za upravljanje kulturno-umetničkim društvom"
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="sr">
      <body>{children}</body>
    </html>
  );
}
