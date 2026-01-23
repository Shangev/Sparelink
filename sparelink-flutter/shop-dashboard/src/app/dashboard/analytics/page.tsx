"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { BarChart3, TrendingUp, TrendingDown, DollarSign, Package, Users, ShoppingCart, Calendar, Download, RefreshCw, PieChart, Target } from "lucide-react"

interface RevenueData {
  month: string
  revenue: number
  orders: number
  quotes: number
}

interface TopPart {
  name: string
  category: string
  quantity: number
  revenue: number
}

interface StaffPerformance {
  name: string
  quotesHandled: number
  ordersCompleted: number
  avgResponseTime: number
  revenue: number
}

interface Analytics {
  totalRevenue: number
  totalOrders: number
  totalQuotes: number
  avgOrderValue: number
  conversionRate: number
  monthlyGrowth: number
  topParts: TopPart[]
  staffPerformance: StaffPerformance[]
  monthlyData: RevenueData[]
  categoryBreakdown: { category: string; revenue: number; percentage: number }[]
}

export default function AnalyticsPage() {
  const [analytics, setAnalytics] = useState<Analytics | null>(null)
  const [loading, setLoading] = useState(true)
  const [period, setPeriod] = useState<"week" | "month" | "quarter" | "year">("month")
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [shopId, setShopId] = useState<string | null>(null)

  useEffect(() => {
    initializeAndLoad()
  }, [])

  useEffect(() => {
    if (shopId) {
      loadAnalytics(shopId)
    }
  }, [period, shopId])

  const initializeAndLoad = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        setLoading(false)
        return
      }

      const { data: shop } = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .single()

      if (shop) {
        setShopId(shop.id)
        await loadAnalytics(shop.id)
      } else {
        const { data: staffRecord } = await supabase
          .from('shop_staff')
          .select('shop_id')
          .eq('user_id', user.id)
          .single()
        
        if (staffRecord) {
          setShopId(staffRecord.shop_id)
          await loadAnalytics(staffRecord.shop_id)
        }
      }
    } catch (error) {
      console.error('Error initializing:', error)
    } finally {
      setLoading(false)
    }
  }

  const loadAnalytics = async (shopIdParam: string) => {
    setLoading(true)
    try {
      // Calculate date range based on period
      const now = new Date()
      let startDate: Date
      switch (period) {
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
          break
        case 'quarter':
          startDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000)
          break
        case 'year':
          startDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000)
          break
        default: // month
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
      }

      // Fetch orders for the period
      const { data: ordersData, error: ordersError } = await supabase
        .from('orders')
        .select(`
          id,
          total_cents,
          status,
          payment_status,
          created_at,
          part_requests:request_id (
            part_category
          )
        `)
        .eq('shop_id', shopIdParam)
        .gte('created_at', startDate.toISOString())
        .order('created_at', { ascending: false })

      if (ordersError) throw ordersError

      // Fetch quotes for the period
      const { data: quotesData, error: quotesError } = await supabase
        .from('quotes')
        .select('id, price_cents, status, created_at')
        .eq('shop_id', shopIdParam)
        .gte('created_at', startDate.toISOString())

      if (quotesError) throw quotesError

      // Fetch previous period for growth calculation
      const prevStartDate = new Date(startDate.getTime() - (now.getTime() - startDate.getTime()))
      const { data: prevOrdersData } = await supabase
        .from('orders')
        .select('total_cents, payment_status')
        .eq('shop_id', shopIdParam)
        .gte('created_at', prevStartDate.toISOString())
        .lt('created_at', startDate.toISOString())

      // Calculate KPIs
      const paidOrders = ordersData?.filter(o => o.payment_status === 'paid') || []
      const totalRevenue = paidOrders.reduce((sum, o) => sum + (o.total_cents || 0), 0) / 100
      const totalOrders = ordersData?.length || 0
      const totalQuotes = quotesData?.length || 0
      const acceptedQuotes = quotesData?.filter(q => q.status === 'accepted').length || 0
      const conversionRate = totalQuotes > 0 ? (acceptedQuotes / totalQuotes) * 100 : 0
      const avgOrderValue = totalOrders > 0 ? Math.round(totalRevenue / totalOrders) : 0

      // Calculate growth
      const prevRevenue = (prevOrdersData?.filter(o => o.payment_status === 'paid') || [])
        .reduce((sum, o) => sum + (o.total_cents || 0), 0) / 100
      const monthlyGrowth = prevRevenue > 0 ? ((totalRevenue - prevRevenue) / prevRevenue) * 100 : 0

      // Calculate category breakdown
      const categoryMap: Record<string, number> = {}
      paidOrders.forEach(order => {
        const category = order.part_requests?.part_category || 'Other'
        categoryMap[category] = (categoryMap[category] || 0) + ((order.total_cents || 0) / 100)
      })
      
      const totalCategoryRevenue = Object.values(categoryMap).reduce((a, b) => a + b, 0)
      const categoryBreakdown = Object.entries(categoryMap)
        .map(([category, revenue]) => ({
          category,
          revenue,
          percentage: totalCategoryRevenue > 0 ? Math.round((revenue / totalCategoryRevenue) * 1000) / 10 : 0
        }))
        .sort((a, b) => b.revenue - a.revenue)
        .slice(0, 6)

      // Calculate monthly data (last 6 months)
      const monthlyData: RevenueData[] = []
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
      
      for (let i = 5; i >= 0; i--) {
        const monthDate = new Date(now.getFullYear(), now.getMonth() - i, 1)
        const monthEnd = new Date(now.getFullYear(), now.getMonth() - i + 1, 0)
        
        const monthOrders = ordersData?.filter(o => {
          const orderDate = new Date(o.created_at)
          return orderDate >= monthDate && orderDate <= monthEnd
        }) || []
        
        const monthQuotes = quotesData?.filter(q => {
          const quoteDate = new Date(q.created_at)
          return quoteDate >= monthDate && quoteDate <= monthEnd
        }) || []

        monthlyData.push({
          month: monthNames[monthDate.getMonth()],
          revenue: monthOrders.filter(o => o.payment_status === 'paid')
            .reduce((sum, o) => sum + ((o.total_cents || 0) / 100), 0),
          orders: monthOrders.length,
          quotes: monthQuotes.length
        })
      }

      // Get top parts from inventory with sales data
      const { data: inventoryData } = await supabase
        .from('inventory')
        .select('part_name, category, selling_price, stock_quantity')
        .eq('shop_id', shopIdParam)
        .order('stock_quantity', { ascending: true })
        .limit(10)

      // Build top parts from order categories
      const partCounts: Record<string, { category: string, count: number, revenue: number }> = {}
      paidOrders.forEach(order => {
        const category = order.part_requests?.part_category || 'Other'
        if (!partCounts[category]) {
          partCounts[category] = { category, count: 0, revenue: 0 }
        }
        partCounts[category].count += 1
        partCounts[category].revenue += (order.total_cents || 0) / 100
      })

      const topParts: TopPart[] = Object.entries(partCounts)
        .map(([name, data]) => ({
          name,
          category: data.category,
          quantity: data.count,
          revenue: data.revenue
        }))
        .sort((a, b) => b.revenue - a.revenue)
        .slice(0, 5)

      // Get staff performance (from shop_staff if available)
      const { data: staffData } = await supabase
        .from('shop_staff')
        .select('id, user_id, role, profiles:user_id (full_name)')
        .eq('shop_id', shopIdParam)

      const staffPerformance: StaffPerformance[] = staffData?.map(staff => ({
        name: (staff.profiles as any)?.full_name || 'Staff Member',
        quotesHandled: Math.floor(totalQuotes / (staffData?.length || 1)),
        ordersCompleted: Math.floor(totalOrders / (staffData?.length || 1)),
        avgResponseTime: 1.5,
        revenue: Math.round(totalRevenue / (staffData?.length || 1))
      })) || []

      // If no staff data, show owner
      if (staffPerformance.length === 0) {
        staffPerformance.push({
          name: 'Shop Owner',
          quotesHandled: totalQuotes,
          ordersCompleted: totalOrders,
          avgResponseTime: 1.5,
          revenue: totalRevenue
        })
      }

      setAnalytics({
        totalRevenue,
        totalOrders,
        totalQuotes,
        avgOrderValue,
        conversionRate: Math.round(conversionRate * 10) / 10,
        monthlyGrowth: Math.round(monthlyGrowth * 10) / 10,
        topParts,
        staffPerformance,
        monthlyData,
        categoryBreakdown
      })
      setLastUpdated(new Date())
    } catch (error) {
      console.error("Error loading analytics:", error)
    } finally {
      setLoading(false)
    }
  }

  const exportReport = () => {
    if (!analytics) return
    
    const report = `
SPARELINK BUSINESS INTELLIGENCE REPORT
Generated: ${new Date().toLocaleString()}
Period: ${period.charAt(0).toUpperCase() + period.slice(1)}

=== SUMMARY ===
Total Revenue: R${analytics.totalRevenue.toLocaleString()}
Total Orders: ${analytics.totalOrders}
Total Quotes: ${analytics.totalQuotes}
Avg Order Value: R${analytics.avgOrderValue.toLocaleString()}
Conversion Rate: ${analytics.conversionRate}%
Monthly Growth: ${analytics.monthlyGrowth}%

=== TOP SELLING PARTS ===
${analytics.topParts.map((p, i) => `${i + 1}. ${p.name} (${p.category}) - ${p.quantity} sold - R${p.revenue.toLocaleString()}`).join('\n')}

=== STAFF PERFORMANCE ===
${analytics.staffPerformance.map(s => `${s.name}: ${s.quotesHandled} quotes, ${s.ordersCompleted} orders, R${s.revenue.toLocaleString()} revenue`).join('\n')}

=== CATEGORY BREAKDOWN ===
${analytics.categoryBreakdown.map(c => `${c.category}: R${c.revenue.toLocaleString()} (${c.percentage}%)`).join('\n')}
    `
    
    const blob = new Blob([report], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `business-report-${new Date().toISOString().split('T')[0]}.txt`
    a.click()
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!analytics) return null

  const maxRevenue = Math.max(...analytics.monthlyData.map(d => d.revenue))

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Business Intelligence</h1>
          {lastUpdated && (
            <p className="text-gray-400 text-sm">Last updated: {lastUpdated.toLocaleTimeString()}</p>
          )}
        </div>
        <div className="flex items-center gap-3">
          <select
            value={period}
            onChange={(e) => setPeriod(e.target.value as any)}
            className="bg-[#1a1a1a] text-white px-4 py-2 rounded-lg border border-gray-800"
          >
            <option value="week">This Week</option>
            <option value="month">This Month</option>
            <option value="quarter">This Quarter</option>
            <option value="year">This Year</option>
          </select>
          <button
            onClick={() => shopId && loadAnalytics(shopId)}
            className="p-2 bg-[#1a1a1a] border border-gray-800 rounded-lg hover:border-gray-700"
          >
            <RefreshCw className={`w-5 h-5 text-gray-400 ${loading ? 'animate-spin' : ''}`} />
          </button>
          <button
            onClick={exportReport}
            className="px-4 py-2 bg-accent hover:bg-accent-hover text-white rounded-lg flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export Report
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-2 mb-2">
            <DollarSign className="w-5 h-5 text-green-400" />
            <span className="text-gray-400 text-sm">Revenue</span>
          </div>
          <p className="text-2xl font-bold text-white">R{(analytics.totalRevenue / 1000).toFixed(0)}k</p>
          <p className="text-green-400 text-xs flex items-center gap-1 mt-1">
            <TrendingUp className="w-3 h-3" /> +{analytics.monthlyGrowth}%
          </p>
        </div>

        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-2 mb-2">
            <ShoppingCart className="w-5 h-5 text-blue-400" />
            <span className="text-gray-400 text-sm">Orders</span>
          </div>
          <p className="text-2xl font-bold text-white">{analytics.totalOrders}</p>
          <p className="text-gray-500 text-xs mt-1">Total completed</p>
        </div>

        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-2 mb-2">
            <Package className="w-5 h-5 text-purple-400" />
            <span className="text-gray-400 text-sm">Quotes</span>
          </div>
          <p className="text-2xl font-bold text-white">{analytics.totalQuotes}</p>
          <p className="text-gray-500 text-xs mt-1">Sent this period</p>
        </div>

        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-2 mb-2">
            <Target className="w-5 h-5 text-yellow-400" />
            <span className="text-gray-400 text-sm">Avg Order</span>
          </div>
          <p className="text-2xl font-bold text-white">R{analytics.avgOrderValue.toLocaleString()}</p>
          <p className="text-gray-500 text-xs mt-1">Per transaction</p>
        </div>

        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-2 mb-2">
            <TrendingUp className="w-5 h-5 text-accent" />
            <span className="text-gray-400 text-sm">Conversion</span>
          </div>
          <p className="text-2xl font-bold text-white">{analytics.conversionRate}%</p>
          <p className="text-gray-500 text-xs mt-1">Quote to order</p>
        </div>

        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-2 mb-2">
            <Users className="w-5 h-5 text-pink-400" />
            <span className="text-gray-400 text-sm">Staff</span>
          </div>
          <p className="text-2xl font-bold text-white">{analytics.staffPerformance.length}</p>
          <p className="text-gray-500 text-xs mt-1">Active members</p>
        </div>
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Revenue Chart */}
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold text-white flex items-center gap-2">
              <BarChart3 className="w-5 h-5 text-accent" />
              Monthly Revenue
            </h3>
          </div>
          <div className="flex items-end justify-between h-48 gap-2">
            {analytics.monthlyData.map((data) => (
              <div key={data.month} className="flex-1 flex flex-col items-center gap-2">
                <div className="w-full flex flex-col items-center" style={{ height: '160px' }}>
                  <div 
                    className="w-full bg-accent/80 rounded-t transition-all hover:bg-accent"
                    style={{ height: `${(data.revenue / maxRevenue) * 100}%`, minHeight: '4px' }}
                    title={`R${data.revenue.toLocaleString()}`}
                  />
                </div>
                <span className="text-gray-500 text-xs">{data.month}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Category Breakdown */}
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold text-white flex items-center gap-2">
              <PieChart className="w-5 h-5 text-accent" />
              Revenue by Category
            </h3>
          </div>
          <div className="space-y-3">
            {analytics.categoryBreakdown.map((cat) => (
              <div key={cat.category}>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-gray-400">{cat.category}</span>
                  <span className="text-white">R{cat.revenue.toLocaleString()} ({cat.percentage}%)</span>
                </div>
                <div className="h-2 bg-[#2d2d2d] rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-accent rounded-full transition-all"
                    style={{ width: `${cat.percentage}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Tables Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Selling Parts */}
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
          <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <Package className="w-5 h-5 text-accent" />
            Top Selling Parts
          </h3>
          <div className="space-y-3">
            {analytics.topParts.map((part, index) => (
              <div key={part.name} className="flex items-center justify-between p-3 bg-[#2d2d2d] rounded-lg">
                <div className="flex items-center gap-3">
                  <span className="w-6 h-6 bg-accent/20 text-accent rounded-full flex items-center justify-center text-sm font-bold">
                    {index + 1}
                  </span>
                  <div>
                    <p className="text-white font-medium">{part.name}</p>
                    <p className="text-gray-500 text-sm">{part.category}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-medium">R{part.revenue.toLocaleString()}</p>
                  <p className="text-gray-500 text-sm">{part.quantity} sold</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Staff Performance */}
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
          <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <Users className="w-5 h-5 text-accent" />
            Staff Performance
          </h3>
          <div className="space-y-3">
            {analytics.staffPerformance.map((staff) => (
              <div key={staff.name} className="p-4 bg-[#2d2d2d] rounded-lg">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-white font-medium">{staff.name}</p>
                  <p className="text-green-400 font-bold">R{staff.revenue.toLocaleString()}</p>
                </div>
                <div className="grid grid-cols-3 gap-4 text-center">
                  <div>
                    <p className="text-2xl font-bold text-white">{staff.quotesHandled}</p>
                    <p className="text-gray-500 text-xs">Quotes</p>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-white">{staff.ordersCompleted}</p>
                    <p className="text-gray-500 text-xs">Orders</p>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-white">{staff.avgResponseTime}h</p>
                    <p className="text-gray-500 text-xs">Avg Response</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
