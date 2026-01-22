"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { FileText, Send, Package, TrendingUp, Clock, CheckCircle, RefreshCw, AlertTriangle, Bell, MessageSquare, DollarSign, BarChart3, ArrowUpRight, ArrowDownRight } from "lucide-react"

interface Stats {
  newRequests: number
  pendingQuotes: number
  acceptedQuotes: number
  activeOrders: number
  completedOrders: number
  totalRevenue: number
  responseRate: number
  quoteAcceptanceRate: number
  avgResponseTime: number
}

interface RecentRequest {
  id: string
  vehicle_make: string
  vehicle_model: string
  vehicle_year: number
  part_category: string
  created_at: string
}

interface Alert {
  id: string
  type: 'warning' | 'urgent' | 'info'
  title: string
  description: string
  action?: { label: string; href: string }
}

interface ExpiringQuote {
  id: string
  request_id: string
  price: number
  expires_at: string
  vehicle_info: string
}

interface WeeklyTrend {
  day: string
  requests: number
  quotes: number
  revenue: number
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({ 
    newRequests: 0, 
    pendingQuotes: 0, 
    acceptedQuotes: 0, 
    activeOrders: 0, 
    completedOrders: 0,
    totalRevenue: 0,
    responseRate: 0,
    quoteAcceptanceRate: 0,
    avgResponseTime: 0
  })
  const [recentRequests, setRecentRequests] = useState<RecentRequest[]>([])
  const [alerts, setAlerts] = useState<Alert[]>([])
  const [expiringQuotes, setExpiringQuotes] = useState<ExpiringQuote[]>([])
  const [weeklyTrends, setWeeklyTrends] = useState<WeeklyTrend[]>([])
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
      let totalQuotes = 0
      let totalRevenue = 0
      let responseRate = 0
      let quoteAcceptanceRate = 0
      let avgResponseTime = 0
      const newAlerts: Alert[] = []
      const expiring: ExpiringQuote[] = []
      
      if (shop) {
        // Get all quotes with expiry info
        const { data: quotes } = await supabase
          .from("offers")
          .select("id, status, price, expires_at, created_at, request_id, part_requests(vehicle_make, vehicle_model, vehicle_year)")
          .eq("shop_id", shop.id)

        if (quotes) {
          totalQuotes = quotes.length
          pendingQuotes = quotes.filter(q => q.status === "pending").length
          acceptedQuotes = quotes.filter(q => q.status === "accepted").length
          
          // Calculate quote acceptance rate
          const decidedQuotes = quotes.filter(q => q.status === "accepted" || q.status === "rejected")
          if (decidedQuotes.length > 0) {
            quoteAcceptanceRate = Math.round((acceptedQuotes / decidedQuotes.length) * 100)
          }

          // Find expiring quotes (within 24 hours)
          const now = new Date()
          const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000)
          
          quotes.forEach(quote => {
            if (quote.status === "pending" && quote.expires_at) {
              const expiryDate = new Date(quote.expires_at)
              if (expiryDate <= tomorrow && expiryDate > now) {
                const req = quote.part_requests as any
                expiring.push({
                  id: quote.id,
                  request_id: quote.request_id,
                  price: quote.price,
                  expires_at: quote.expires_at,
                  vehicle_info: req ? `${req.vehicle_year} ${req.vehicle_make} ${req.vehicle_model}` : 'Unknown Vehicle'
                })
              }
            }
          })
        }

        // Get order stats and revenue for this shop
        const { data: orders } = await supabase
          .from("orders")
          .select("id, status, total_amount, offers!inner(shop_id)")
          .eq("offers.shop_id", shop.id)

        let activeOrders = 0
        let completedOrders = 0

        if (orders) {
          activeOrders = orders.filter(o => ["confirmed", "processing", "shipped"].includes(o.status)).length
          completedOrders = orders.filter(o => o.status === "delivered").length
          
          // Calculate total revenue from delivered orders
          totalRevenue = orders
            .filter(o => o.status === "delivered")
            .reduce((sum, o) => sum + (o.total_amount || 0), 0)
        }

        // Calculate response rate (quotes sent / requests received)
        const { data: assignedChats } = await supabase
          .from("request_chats")
          .select("request_id")
          .eq("shop_id", shop.id)
        
        if (assignedChats && assignedChats.length > 0 && totalQuotes > 0) {
          responseRate = Math.min(100, Math.round((totalQuotes / assignedChats.length) * 100))
        }

        // Generate alerts based on data
        if (expiring.length > 0) {
          newAlerts.push({
            id: 'expiring-quotes',
            type: 'warning',
            title: `${expiring.length} Quote${expiring.length > 1 ? 's' : ''} Expiring Soon`,
            description: `You have ${expiring.length} quote${expiring.length > 1 ? 's' : ''} expiring within 24 hours`,
            action: { label: 'View Quotes', href: '/dashboard/quotes' }
          })
        }

        if (pendingQuotes === 0 && requests.length > 0) {
          newAlerts.push({
            id: 'no-quotes',
            type: 'info',
            title: 'New Requests Waiting',
            description: `You have ${requests.length} request${requests.length > 1 ? 's' : ''} without quotes`,
            action: { label: 'Send Quotes', href: '/dashboard/requests' }
          })
        }

        if (responseRate < 50 && totalQuotes > 0) {
          newAlerts.push({
            id: 'low-response',
            type: 'urgent',
            title: 'Low Response Rate',
            description: 'Your response rate is below 50%. Responding quickly improves your visibility.',
            action: { label: 'View Requests', href: '/dashboard/requests' }
          })
        }

        if (activeOrders > 3) {
          newAlerts.push({
            id: 'many-orders',
            type: 'info',
            title: 'Multiple Active Orders',
            description: `You have ${activeOrders} orders in progress. Stay on top of deliveries!`,
            action: { label: 'Manage Orders', href: '/dashboard/orders' }
          })
        }

        setStats({
          newRequests: requests?.length || 0,
          pendingQuotes,
          acceptedQuotes,
          activeOrders,
          completedOrders,
          totalRevenue,
          responseRate,
          quoteAcceptanceRate,
          avgResponseTime
        })
        
        setAlerts(newAlerts)
        setExpiringQuotes(expiring)
      }

      // Generate weekly trends (mock data for now - would come from analytics table in production)
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
      const trends: WeeklyTrend[] = days.map((day, i) => ({
        day,
        requests: Math.floor(Math.random() * 10) + 2,
        quotes: Math.floor(Math.random() * 8) + 1,
        revenue: Math.floor(Math.random() * 5000) + 1000
      }))
      setWeeklyTrends(trends)

      setRecentRequests(requests)
      setLastUpdated(new Date())
    } catch (error) {
      console.error("Error loading dashboard:", error)
    } finally {
      setLoading(false)
    }
  }

  const statCards = [
    { label: "New Requests", value: stats.newRequests, icon: FileText, color: "bg-blue-500/20 text-blue-400", trend: null },
    { label: "Pending Quotes", value: stats.pendingQuotes, icon: Send, color: "bg-yellow-500/20 text-yellow-400", trend: null },
    { label: "Accepted Quotes", value: stats.acceptedQuotes, icon: CheckCircle, color: "bg-green-500/20 text-green-400", trend: stats.quoteAcceptanceRate > 0 ? `${stats.quoteAcceptanceRate}% rate` : null },
    { label: "Active Orders", value: stats.activeOrders, icon: Package, color: "bg-purple-500/20 text-purple-400", trend: null },
    { label: "Total Revenue", value: `R${stats.totalRevenue.toLocaleString()}`, icon: DollarSign, color: "bg-green-500/20 text-green-400", trend: stats.completedOrders > 0 ? `${stats.completedOrders} completed` : null },
  ]

  const getAlertStyles = (type: Alert['type']) => {
    switch (type) {
      case 'urgent':
        return 'bg-red-500/10 border-red-500/30 text-red-400'
      case 'warning':
        return 'bg-yellow-500/10 border-yellow-500/30 text-yellow-400'
      case 'info':
        return 'bg-blue-500/10 border-blue-500/30 text-blue-400'
    }
  }

  const getAlertIcon = (type: Alert['type']) => {
    switch (type) {
      case 'urgent':
        return <AlertTriangle className="w-5 h-5 text-red-400" />
      case 'warning':
        return <Clock className="w-5 h-5 text-yellow-400" />
      case 'info':
        return <Bell className="w-5 h-5 text-blue-400" />
    }
  }

  const formatTimeRemaining = (expiresAt: string) => {
    const now = new Date()
    const expiry = new Date(expiresAt)
    const diffMs = expiry.getTime() - now.getTime()
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
    const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60))
    
    if (diffHours > 0) return `${diffHours}h ${diffMins}m`
    return `${diffMins}m`
  }

  const maxTrendValue = Math.max(...weeklyTrends.map(t => t.requests), 1)

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

      {/* Alerts Section */}
      {alerts.length > 0 && (
        <div className="space-y-3">
          {alerts.map((alert) => (
            <div key={alert.id} className={`rounded-xl p-4 border flex items-center justify-between ${getAlertStyles(alert.type)}`}>
              <div className="flex items-center gap-3">
                {getAlertIcon(alert.type)}
                <div>
                  <p className="font-semibold">{alert.title}</p>
                  <p className="text-sm opacity-80">{alert.description}</p>
                </div>
              </div>
              {alert.action && (
                <a href={alert.action.href} className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-sm font-medium transition-colors">
                  {alert.action.label}
                </a>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Stats Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
        {statCards.map((stat) => (
          <div key={stat.label} className="bg-[#1a1a1a] rounded-xl p-5 border border-gray-800">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">{stat.label}</p>
                <p className="text-2xl font-bold text-white mt-1">{stat.value}</p>
                {stat.trend && (
                  <p className="text-xs text-gray-500 mt-1">{stat.trend}</p>
                )}
              </div>
              <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${stat.color}`}>
                <stat.icon className="w-5 h-5" />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Expiring Quotes Warning */}
      {expiringQuotes.length > 0 && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <Clock className="w-5 h-5 text-yellow-400" />
            <h3 className="text-yellow-400 font-semibold">Quotes Expiring Soon</h3>
          </div>
          <div className="space-y-2">
            {expiringQuotes.map((quote) => (
              <div key={quote.id} className="flex items-center justify-between bg-[#1a1a1a] rounded-lg p-3">
                <div>
                  <p className="text-white text-sm font-medium">{quote.vehicle_info}</p>
                  <p className="text-gray-400 text-xs">R{quote.price.toLocaleString()}</p>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-yellow-400 text-sm font-medium">{formatTimeRemaining(quote.expires_at)} left</span>
                  <a href={`/dashboard/quotes?id=${quote.id}`} className="px-3 py-1.5 bg-yellow-500 hover:bg-yellow-600 text-black text-xs font-medium rounded-lg transition-colors">
                    Extend
                  </a>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Analytics Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Weekly Trends Chart */}
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <BarChart3 className="w-5 h-5 text-accent" />
              <h3 className="text-lg font-semibold text-white">Weekly Activity</h3>
            </div>
            <div className="flex items-center gap-4 text-xs">
              <span className="flex items-center gap-1"><span className="w-3 h-3 bg-accent rounded-sm"></span> Requests</span>
              <span className="flex items-center gap-1"><span className="w-3 h-3 bg-blue-500 rounded-sm"></span> Quotes</span>
            </div>
          </div>
          <div className="flex items-end justify-between h-40 gap-2">
            {weeklyTrends.map((trend, i) => (
              <div key={trend.day} className="flex-1 flex flex-col items-center gap-1">
                <div className="w-full flex gap-1 items-end" style={{ height: '120px' }}>
                  <div 
                    className="flex-1 bg-accent/80 rounded-t transition-all"
                    style={{ height: `${(trend.requests / maxTrendValue) * 100}%`, minHeight: '4px' }}
                    title={`${trend.requests} requests`}
                  />
                  <div 
                    className="flex-1 bg-blue-500/80 rounded-t transition-all"
                    style={{ height: `${(trend.quotes / maxTrendValue) * 100}%`, minHeight: '4px' }}
                    title={`${trend.quotes} quotes`}
                  />
                </div>
                <span className="text-gray-500 text-xs">{trend.day}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Performance Metrics */}
        <div className="bg-[#1a1a1a] rounded-xl p-6 border border-gray-800">
          <div className="flex items-center gap-2 mb-6">
            <TrendingUp className="w-5 h-5 text-accent" />
            <h3 className="text-lg font-semibold text-white">Performance Metrics</h3>
          </div>
          <div className="space-y-5">
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-400">Response Rate</span>
                <span className="text-white font-medium">{stats.responseRate}%</span>
              </div>
              <div className="h-3 bg-[#2d2d2d] rounded-full overflow-hidden">
                <div 
                  className={`h-full rounded-full transition-all duration-500 ${stats.responseRate >= 70 ? 'bg-green-500' : stats.responseRate >= 40 ? 'bg-yellow-500' : 'bg-red-500'}`} 
                  style={{ width: `${stats.responseRate}%` }} 
                />
              </div>
              <p className="text-gray-500 text-xs mt-1">
                {stats.responseRate >= 70 ? 'Excellent! Keep it up.' : stats.responseRate >= 40 ? 'Good, but could improve.' : 'Try responding to more requests.'}
              </p>
            </div>
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-400">Quote Acceptance Rate</span>
                <span className="text-white font-medium">{stats.quoteAcceptanceRate}%</span>
              </div>
              <div className="h-3 bg-[#2d2d2d] rounded-full overflow-hidden">
                <div 
                  className={`h-full rounded-full transition-all duration-500 ${stats.quoteAcceptanceRate >= 50 ? 'bg-green-500' : stats.quoteAcceptanceRate >= 25 ? 'bg-yellow-500' : 'bg-blue-500'}`}
                  style={{ width: `${stats.quoteAcceptanceRate}%` }} 
                />
              </div>
              <p className="text-gray-500 text-xs mt-1">
                {stats.quoteAcceptanceRate >= 50 ? 'Great conversion rate!' : stats.quoteAcceptanceRate >= 25 ? 'Average - competitive pricing helps.' : 'Consider adjusting your pricing strategy.'}
              </p>
            </div>
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-400">Completed Orders</span>
                <span className="text-white font-medium">{stats.completedOrders}</span>
              </div>
              <div className="flex items-center gap-2 mt-2">
                <CheckCircle className="w-4 h-4 text-green-400" />
                <span className="text-gray-400 text-sm">
                  {stats.completedOrders > 0 
                    ? `R${Math.round(stats.totalRevenue / stats.completedOrders).toLocaleString()} avg order value`
                    : 'Complete orders to see average value'}
                </span>
              </div>
            </div>
          </div>
        </div>
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
      <div className="bg-[#1a1a1a] rounded-xl p-6 border border-gray-800">
        <h3 className="text-lg font-semibold text-white mb-4">Quick Actions</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <a href="/dashboard/requests" className="flex flex-col items-center gap-2 p-4 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors text-center">
            <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center">
              <FileText className="w-5 h-5 text-blue-400" />
            </div>
            <span className="text-white text-sm">Browse Requests</span>
            {stats.newRequests > 0 && (
              <span className="text-xs text-blue-400">{stats.newRequests} new</span>
            )}
          </a>
          <a href="/dashboard/quotes" className="flex flex-col items-center gap-2 p-4 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors text-center">
            <div className="w-10 h-10 rounded-full bg-yellow-500/20 flex items-center justify-center">
              <Send className="w-5 h-5 text-yellow-400" />
            </div>
            <span className="text-white text-sm">Manage Quotes</span>
            {stats.pendingQuotes > 0 && (
              <span className="text-xs text-yellow-400">{stats.pendingQuotes} pending</span>
            )}
          </a>
          <a href="/dashboard/orders" className="flex flex-col items-center gap-2 p-4 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors text-center">
            <div className="w-10 h-10 rounded-full bg-purple-500/20 flex items-center justify-center">
              <Package className="w-5 h-5 text-purple-400" />
            </div>
            <span className="text-white text-sm">Manage Orders</span>
            {stats.activeOrders > 0 && (
              <span className="text-xs text-purple-400">{stats.activeOrders} active</span>
            )}
          </a>
          <a href="/dashboard/chats" className="flex flex-col items-center gap-2 p-4 bg-[#2d2d2d] hover:bg-[#3d3d3d] rounded-lg transition-colors text-center">
            <div className="w-10 h-10 rounded-full bg-green-500/20 flex items-center justify-center">
              <MessageSquare className="w-5 h-5 text-green-400" />
            </div>
            <span className="text-white text-sm">View Chats</span>
          </a>
        </div>
      </div>
    </div>
  )
}
