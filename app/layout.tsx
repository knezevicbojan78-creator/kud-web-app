import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "App KUD",
  description: "KUD management application layout"
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
