import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Toaster } from "@/components/ui/sonner";
import { QueryProvider } from "@/providers/query-provider";
import { SupabaseProvider } from "@/providers/supabase-provider";
import { TooltipProvider } from "@/components/ui/tooltip";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "GovMetrics - Avaliação de Serviços Públicos",
  description:
    "Plataforma de avaliação cidadã para órgãos públicos. Acompanhe em tempo real a qualidade do atendimento prestado à população.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="pt-BR"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <QueryProvider>
          <SupabaseProvider>
            <TooltipProvider>{children}</TooltipProvider>
          </SupabaseProvider>
        </QueryProvider>
        <Toaster richColors position="top-right" />
      </body>
    </html>
  );
}
