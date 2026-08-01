import type { Metadata } from "next";
import { CookieConsent } from "./_components/CookieConsent";
import "./globals.css";
import "../presentation/app/globals.css";

const googleAnalyticsId = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID;

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
      <CookieConsent googleAnalyticsId={googleAnalyticsId} />
    </html>
  );
}
