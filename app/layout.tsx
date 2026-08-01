import type { Metadata } from "next";
import "./globals.css";
import "../presentation/app/globals.css";

export const metadata: Metadata = {
  title: "Folkloraš — vođenje KUD-a na jednom mestu",
  description:
    "Članovi, sekcije, prisustvo, članarine, nastupi i garderoba u jednom povezanom sistemu."
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
