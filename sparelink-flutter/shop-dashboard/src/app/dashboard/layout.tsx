"use client"

import { useEffect, useState } from "react"
import { useRouter, usePathname } from "next/navigation"
import Link from "next/link"
import { 
  supabase, 
  getCurrentSession, 
  onAuthStateChange, 
  updateSessionActivity,
  cleanupSession 
} from "@/lib/supabase"
import { 
  LayoutDashboard, 
  FileText, 
  Send, 
  Package, 
  Settings, 
  LogOut,
  Store,
  Bell,
  Menu,
  X,
  MessageSquare,
  Boxes,
  BarChart3,
  Users,
  CreditCard
} from "lucide-react"

interface ShopData {
  id: string
  name: string
  phone: string
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const pathname = usePathname()
  const [shop, setShop] = useState<ShopData | null>(null)
  const [loading, setLoading] = useState(true)
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [notifications, setNotifications] = useState(0)

  useEffect(() => {
    checkAuth()
    
    // Set up auth state listener for session persistence
    const { data: { subscription } } = onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT' || !session) {
        router.push("/login")
      } else if (event === 'TOKEN_REFRESHED') {
        console.log('Session token refreshed automatically')
      }
    })
    
    // Update session activity periodically (every 5 minutes)
    const activityInterval = setInterval(() => {
      updateSessionActivity()
    }, 5 * 60 * 1000)
    
    return () => {
      subscription.unsubscribe()
      clearInterval(activityInterval)
    }
  }, [])

  const checkAuth = async () => {
    // First try to get existing session from storage
    const { session } = await getCurrentSession()
    
    if (!session) {
      router.push("/login")
      return
    }
    
    const user = session.user

    const { data: shopData } = await supabase
      .from("shops")
      .select("id, name, phone")
      .eq("owner_id", user.id)
      .single()

    if (shopData) {
      setShop(shopData)
    }
    
    // Update session activity on page load
    updateSessionActivity()
    
    setLoading(false)
  }

  const handleLogout = async () => {
    // Clean up device session before signing out
    await cleanupSession()
    await supabase.auth.signOut()
    router.push("/login")
  }

  const navItems = [
    { href: "/dashboard", icon: LayoutDashboard, label: "Overview" },
    { href: "/dashboard/requests", icon: FileText, label: "Part Requests" },
    { href: "/dashboard/quotes", icon: Send, label: "My Quotes" },
    { href: "/dashboard/chats", icon: MessageSquare, label: "Chats" },
    { href: "/dashboard/orders", icon: Package, label: "Orders" },
    { href: "/dashboard/inventory", icon: Boxes, label: "Inventory" },
    { href: "/dashboard/customers", icon: Users, label: "Customers" },
    { href: "/dashboard/analytics", icon: BarChart3, label: "Analytics" },
    { href: "/dashboard/settings", icon: Settings, label: "Settings" },
  ]

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0a0a0a] flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#0a0a0a] flex">
      {/* Mobile Menu Button */}
      <button
        onClick={() => setSidebarOpen(!sidebarOpen)}
        className="lg:hidden fixed top-4 left-4 z-50 p-2 bg-[#1a1a1a] rounded-lg border border-gray-800"
      >
        {sidebarOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
      </button>

      {/* Sidebar Overlay */}
      {sidebarOpen && (
        <div 
          className="lg:hidden fixed inset-0 bg-black/50 z-40"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`
        fixed lg:static inset-y-0 left-0 z-40
        w-64 bg-[#1a1a1a] border-r border-gray-800
        transform transition-transform duration-200
        ${sidebarOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"}
      `}>
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="p-6 border-b border-gray-800">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-accent rounded-lg flex items-center justify-center">
                <Store className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="font-bold text-white">SpareLink</h1>
                <p className="text-xs text-gray-400">Shop Dashboard</p>
              </div>
            </div>
          </div>

          {/* Shop Info */}
          {shop && (
            <div className="px-4 py-4 border-b border-gray-800">
              <p className="text-sm font-medium text-white truncate">{shop.name}</p>
              <p className="text-xs text-gray-400">{shop.phone}</p>
            </div>
          )}

          {/* Navigation */}
          <nav className="flex-1 p-4 space-y-1">
            {navItems.map((item) => {
              const isActive = pathname === item.href
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setSidebarOpen(false)}
                  className={`
                    flex items-center gap-3 px-4 py-3 rounded-lg transition-colors
                    ${isActive 
                      ? "bg-accent text-white" 
                      : "text-gray-400 hover:text-white hover:bg-[#2d2d2d]"
                    }
                  `}
                >
                  <item.icon className="w-5 h-5" />
                  <span className="font-medium">{item.label}</span>
                </Link>
              )
            })}
          </nav>

          {/* Logout */}
          <div className="p-4 border-t border-gray-800">
            <button
              onClick={handleLogout}
              className="flex items-center gap-3 px-4 py-3 w-full text-gray-400 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
            >
              <LogOut className="w-5 h-5" />
              <span className="font-medium">Sign Out</span>
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 lg:ml-0">
        {/* Top Bar */}
        <header className="sticky top-0 z-30 bg-[#0a0a0a]/80 backdrop-blur-lg border-b border-gray-800">
          <div className="flex items-center justify-between px-6 py-4 lg:pl-6 pl-16">
            <h2 className="text-xl font-semibold text-white">
              {navItems.find(item => item.href === pathname)?.label || "Dashboard"}
            </h2>
            <button className="relative p-2 text-gray-400 hover:text-white transition-colors">
              <Bell className="w-6 h-6" />
              {notifications > 0 && (
                <span className="absolute top-1 right-1 w-4 h-4 bg-accent rounded-full text-xs flex items-center justify-center">
                  {notifications}
                </span>
              )}
            </button>
          </div>
        </header>

        {/* Page Content */}
        <div className="p-6">
          {children}
        </div>
      </main>
    </div>
  )
}
