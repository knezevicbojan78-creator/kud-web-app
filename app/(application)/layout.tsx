import { AppShell } from "../_components/AppShell";

export default function ApplicationLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return <AppShell>{children}</AppShell>;
}
