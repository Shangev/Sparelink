"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { FileText, Send, Package, TrendingUp, Clock, CheckCircle, RefreshCw } from "lucide-react"

interface Stats {
  newRequests: number
  pendingQuotes: number
  acceptedQuotes: number
  activeOrders: number
  completedOrders: number
}

interface RecentRequest {
  id: string
  vehicle_make: string
  vehicle_model: string
  vehicle_year: number
  part_category: string
  created_at: string
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({ newRequests: 0, pendingQuotes: 0, acceptedQuotes: 0, activeOrders: 0, completedOrders: 0 })
  const [recentRequests, setRecentRequests] = useState<RecentRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [shopId, setShopId] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)

  useEffect(() => {
    loadDashboardData()
  }, [])

  // Set up real-time subscriptions
  useEffect(() => {
    if (!shopId) return

    // Subscribe to multiple tables for live updates
    const channel = supabase
      .channel('dashboard-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'part_requests' }, () => {
        loadDashboardData()
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offers', filter: `shop_id=eq.${shopId}` }, () => {
        loadDashboardData()
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        loadDashboardData()
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [shopId])

  const loadDashboardData = async () => {
    try {
      // Get authenticated user and shop
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: shop } = await supabase
        .from("shops")
        .select("id")
        .eq("owner_id", user.id)
        .single()

      if (shop && !shopId) {
        setShopId(shop.id)
      }

      // Get recent part requests assigned to THIS shop via request_chats
      let requests: RecentRequest[] = []
      if (shop) {
        // First get request IDs assigned to this shop from request_chats
        const { data: assignedChats } = await supabase
          .from("request_chats")
          .select("request_id")
          .eq("shop_id", shop.id)

        if (assignedChats && assignedChats.length > 0) {
          const requestIds = assignedChats.map(chat => chat.request_id)
          
          const { data: requestData } = await supabase
            .from("part_requests")
            .select("id, vehicle_make, vehicle_model, vehicle_year, part_category, created_at")
            .in("id", requestIds)
            .eq("status", "pending")
            .order("created_at", { ascending: false })
            .limit(5)
          
          requests = requestData || []
        }
      }

      // Get quote stats for this shop
      let pendingQuotes = 0
      let acceptedQuotes = 0
      
      if (shop) {
        const { data: quotes } = await supabase
          .from("offers")
          .select("id, status")
          .eq("shop_id", shop.id)

        if (quotes) {
          pendingQuotes = quotes.filter(q => q.status === "pending").length
          acceptedQuotes = quotes.filter(q => q.status === "accepted").length
        }

        // Get order stats for this shop
        const { data: orders } = await supabase
          .from("orders")
          .select("id, status, offers!inner(shop_id)")
          .eq("offers.shop_id", shop.id)

        let activeOrders = 0
        let completedOrders = 0

        if (orders) {
          activeOrders = orders.filter(o => ["confirmed", "processing", "shipped"].includes(o.status)).length
          completedOrders = orders.filter(o => o.status === "delivered").length
        }

        setStats({
          newRequests: requests?.length || 0,
          pendingQuotes,
          acceptedQuotes,
          activeOrders,
          completedOrders
        })
      }

      setRecentRequests(requests)
      
      setLastUpdated(new Date())
    } catch (error) {
      console.error("Error loading dashboard:", error)
    } finally {
      setLoading(false)
    }
  }

  const statCards = [
    { label: "New Requests", value: stats.newRequests, icon: FileText, color: "bg-blue-500/20 text-blue-400" },
    { label: "Pending Quotes", value: stats.pendingQuotes, icon: Send, color: "bg-yellow-500/20 text-yellow-400" },
    { label: "Accepted Quotes", value: stats.acceptedQuotes, icon: CheckCircle, color: "bg-green-500/20 text-green-400" },
    { label: "Active Orders", value: stats.activeOrders, icon: Package, color: "bg-accent/20 text-accent" },
  ]

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffMins < 60) return diffMins + "m ago"
    if (diffHours < 24) return diffHours + "h ago"
    return diffDays + "d ago"
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header with refresh */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard Overview</h1>
          {lastUpdated && (
            <p className="text-gray-500 text-sm">Last updated: {lastUpdated.toLocaleTimeString()}</p>
          )}
        </div>
        <button
          onClick={() => loadDashboardData()}
          className="p-2 bg-[#1a1a1a] border border-gray-800 rounded-lg hover:border-gray-700 transition-colors flex items-center gap-2"
          title="Refresh dashboard"
        >
          <RefreshCw className={`w-5 h-5 text-gray-400 ${loading ? 'animate-spin' : ''}`} />
          <span className="text-gray-400 text-sm hidden sm:inline">Refresh</span>
        </button>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat) => (
          <div key={stat.label} className="bg-[#1a1a1a] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">{stat.label}</p>
                <p className="text-3xl font-bold text-white mt-1">{stat.value}</p>
              </div>
              <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${stat.color}`}>
                <stat.icon className="w-6 h-6" />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Recent Requests */}
      <div className="bg-[#1a1a1a] rounded-xl border border-gray-800">
        <div className="px-6 py-4 border-b border-gray-800 flex items-center justify-between">
          <h3 className="text-lg font-semibold text-white">Recent Part Requests</h3>
          <a href="/dashboard/requests" className="text-accent hover:text-accent-hover text-sm font-medium">
            View All
          </a>
        </div>
        
        {recentRequests.length === 0 ? (
          <div className="p-12 text-center">
            <FileText className="w-12 h-12 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No pending requests</p>
            <p className="text-gray-500 text-sm mt-1">New part requests from mechanics will appear here</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-800">
            {recentRequests.map((request) => (
              <div key={request.id} className="px-6 py-4 hover:bg-[#2d2d2d] transition-colors">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white font-medium">
                      {request.vehicle_year} {request.vehicle_make} {request.vehicle_model}
                    </p>
                    <p className="text-gray-400 text-sm mt-1">{request.part_category}</p>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-gray-500 text-sm flex items-center gap-1">
                      <Clock className="w-4 h-4" />
                      {formatDate(request.created_at)}
                    </span>
                    <a 
                      href={`/dashboard/requests?id=${request.id}`}
                      className="px-4 py-2 bg-accent hover:bg-accent-hover text-white text-sm font-medium rounded-lg transition-colors"
                    >
                      Send Quote
                    </a>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-[#1a1a1a] rounded-xl p-6 border border-gray-800">
          <h3 className="text-lg font-semibold text-white mb-4">Quick Actions</h3>
          <div className="space-y-3">
            <a href="/dashboard/requests" className="flex items-center gap-3 p-3 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors">
              <FileText className="w-5 h-5 text-accent" />
              <span className="text-white">Browse Part Requests</span>
            </a>
            <a href="/dashboard/orders" className="flex items-center gap-3 p-3 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors">
              <Package className="w-5 h-5 text-accent" />
              <span className="text-white">Manage Orders</span>
            </a>
            <a href="/dashboard/settings" className="flex items-center gap-3 p-3 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors">
              <TrendingUp className="w-5 h-5 text-accent" />
              <span className="text-white">Update Working Hours</span>
            </a>
          </div>
        </div>

        <div className="bg-[#1a1a1a] rounded-xl p-6 border border-gray-800">
          <h3 className="text-lg font-semibold text-white mb-4">Performance</h3>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-sm mb-1">
                <span className="text-gray-400">Response Rate</span>
                <span className="text-white">--</span>
              </div>
              <div className="h-2 bg-[#2d2d2d] rounded-full">
                <div className="h-full bg-accent rounded-full" style={{ width: "0%" }} />
              </div>
            </div>
            <div>
              <div className="flex justify-between text-sm mb-1">
                <span className="text-gray-400">Quote Acceptance</span>
                <span className="text-white">--</span>
              </div>
              <div className="h-2 bg-[#2d2d2d] rounded-full">
                <div className="h-full bg-blue-500 rounded-full" style={{ width: "0%" }} />
              </div>
            </div>
            <p className="text-gray-500 text-sm mt-4">Stats will appear once you start responding to requests</p>
          </div>
        </div>
      </div>
    </div>
  )
}
