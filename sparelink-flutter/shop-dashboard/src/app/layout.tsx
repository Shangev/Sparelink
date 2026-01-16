import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "SpareLink Shop Dashboard",
  description: "Manage your auto parts shop - quotes, orders, and more",
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  )
}
