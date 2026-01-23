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

  useEffect(() => {
    loadAnalytics()
  }, [period])

  const loadAnalytics = async () => {
    setLoading(true)
    try {
      // In production, would fetch from Supabase
      // For now, generate realistic mock data
      await new Promise(resolve => setTimeout(resolve, 500))

      const mockData: Analytics = {
        totalRevenue: 245680,
        totalOrders: 127,
        totalQuotes: 342,
        avgOrderValue: 1935,
        conversionRate: 37.1,
        monthlyGrowth: 12.5,
        topParts: [
          { name: "Brake Pads Set", category: "Brake System", quantity: 45, revenue: 20250 },
          { name: "Oil Filter", category: "Filters", quantity: 89, revenue: 7565 },
          { name: "Alternator", category: "Electrical", quantity: 12, revenue: 30000 },
          { name: "Shock Absorber", category: "Suspension", quantity: 28, revenue: 25200 },
          { name: "Spark Plugs (Set)", category: "Engine Parts", quantity: 67, revenue: 8710 },
        ],
        staffPerformance: [
          { name: "John (Manager)", quotesHandled: 145, ordersCompleted: 52, avgResponseTime: 1.2, revenue: 98500 },
          { name: "Sarah (Sales)", quotesHandled: 98, ordersCompleted: 38, avgResponseTime: 1.8, revenue: 72300 },
          { name: "Mike (Parts)", quotesHandled: 99, ordersCompleted: 37, avgResponseTime: 2.1, revenue: 74880 },
        ],
        monthlyData: [
          { month: "Jul", revenue: 32500, orders: 18, quotes: 45 },
          { month: "Aug", revenue: 38200, orders: 21, quotes: 52 },
          { month: "Sep", revenue: 35800, orders: 19, quotes: 48 },
          { month: "Oct", revenue: 42100, orders: 24, quotes: 61 },
          { month: "Nov", revenue: 48500, orders: 26, quotes: 68 },
          { month: "Dec", revenue: 48580, orders: 19, quotes: 68 },
        ],
        categoryBreakdown: [
          { category: "Brake System", revenue: 45200, percentage: 18.4 },
          { category: "Electrical", revenue: 52300, percentage: 21.3 },
          { category: "Engine Parts", revenue: 38900, percentage: 15.8 },
          { category: "Suspension", revenue: 42100, percentage: 17.1 },
          { category: "Filters", revenue: 28500, percentage: 11.6 },
          { category: "Other", revenue: 38680, percentage: 15.8 },
        ],
      }

      setAnalytics(mockData)
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
            onClick={loadAnalytics}
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
