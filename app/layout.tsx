import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "App KUD",
  description: "Web aplikacija za upravljanje KUD-ovima."
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
