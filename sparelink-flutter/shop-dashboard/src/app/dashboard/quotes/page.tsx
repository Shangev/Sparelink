"use client"

import { useEffect, useState, useMemo } from "react"
import { supabase } from "@/lib/supabase"
import { Send, Clock, CheckCircle, XCircle, Car, RefreshCw, Trash2, FileText, History, BarChart3, TrendingUp, TrendingDown, DollarSign, Search, Plus, X, Save, Bookmark, AlertCircle, ChevronDown, ChevronUp, PieChart } from "lucide-react"

interface Quote {
  id: string
  request_id: string
  price_cents: number
  delivery_fee_cents: number
  eta_minutes: number
  message: string | null
  part_condition: string | null
  warranty: string | null
  status: string
  created_at: string
  part_requests?: { vehicle_make: string; vehicle_model: string; vehicle_year: number; part_category: string }
}

interface QuoteTemplate {
  id: string
  name: string
  part_category: string
  price: number
  part_condition: "new" | "used" | "refurbished"
  warranty: string
  message: string
}

interface PricingHistoryEntry {
  date: string
  part_category: string
  vehicle: string
  price: number
  status: string
}

interface QuoteAnalytics {
  totalSent: number
  accepted: number
  rejected: number
  pending: number
  withdrawn: number
  winRate: number
  avgQuoteValue: number
  totalRevenue: number
  avgResponseTime: number
}

interface MarketData {
  partCategory: string
  yourAvgPrice: number
  marketAvgPrice: number
  marketLow: number
  marketHigh: number
  yourQuoteCount: number
  competitiveness: "below" | "average" | "above"
}

export default function QuotesPage() {
  const [quotes, setQuotes] = useState<Quote[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState("all")
  const [shopId, setShopId] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  
  // New state for features
  const [activeTab, setActiveTab] = useState<"quotes" | "templates" | "analytics" | "insights">("quotes")
  const [templates, setTemplates] = useState<QuoteTemplate[]>([])
  const [showTemplateModal, setShowTemplateModal] = useState(false)
  const [editingTemplate, setEditingTemplate] = useState<QuoteTemplate | null>(null)
  const [templateForm, setTemplateForm] = useState<Omit<QuoteTemplate, 'id'>>({
    name: "",
    part_category: "",
    price: 0,
    part_condition: "new",
    warranty: "none",
    message: ""
  })
  const [historySearch, setHistorySearch] = useState("")
  const [showHistoryPanel, setShowHistoryPanel] = useState(false)
  const [analytics, setAnalytics] = useState<QuoteAnalytics | null>(null)
  const [marketData, setMarketData] = useState<MarketData[]>([])

  // Load quotes and set up real-time subscription
  useEffect(() => {
    loadQuotes()
    loadTemplates()
  }, [])

  // Set up real-time subscription when shopId is available
  useEffect(() => {
    if (!shopId) return

    // Subscribe to changes on offers table for this shop
    const channel = supabase
      .channel('shop-quotes-changes')
      .on(
        'postgres_changes',
        {
          event: '*', // Listen to all changes (INSERT, UPDATE, DELETE)
          schema: 'public',
          table: 'offers',
          filter: `shop_id=eq.${shopId}`
        },
        (payload) => {
          console.log('Offer changed:', payload)
          // Reload quotes when any change happens
          loadQuotes()
        }
      )
      .subscribe()

    // Cleanup subscription on unmount
    return () => {
      supabase.removeChannel(channel)
    }
  }, [shopId])

  const loadQuotes = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: shop } = await supabase
        .from("shops")
        .select("id")
        .eq("owner_id", user.id)
        .single()

      if (!shop) return

      // Save shopId for real-time subscription
      if (!shopId) {
        setShopId(shop.id)
      }

      const { data } = await supabase
        .from("offers")
        .select("*, part_requests:request_id(vehicle_make, vehicle_model, vehicle_year, part_category)")
        .eq("shop_id", shop.id)
        .order("created_at", { ascending: false })

      if (data) {
        setQuotes(data)
        calculateAnalytics(data)
        calculateMarketData(data)
      }
      setLastUpdated(new Date())
    } catch (error) {
      console.error("Error loading quotes:", error)
    } finally {
      setLoading(false)
    }
  }

  // Load templates from localStorage
  const loadTemplates = () => {
    try {
      const saved = localStorage.getItem('sparelink-quote-templates')
      if (saved) {
        setTemplates(JSON.parse(saved))
      }
    } catch (e) {
      console.error('Error loading templates:', e)
    }
  }

  // Save templates to localStorage
  const saveTemplates = (newTemplates: QuoteTemplate[]) => {
    localStorage.setItem('sparelink-quote-templates', JSON.stringify(newTemplates))
    setTemplates(newTemplates)
  }

  // Add or update template
  const handleSaveTemplate = () => {
    if (!templateForm.name || !templateForm.part_category || !templateForm.price) {
      alert("Please fill in Name, Part Category, and Price")
      return
    }

    if (editingTemplate) {
      // Update existing
      const updated = templates.map(t => 
        t.id === editingTemplate.id ? { ...templateForm, id: editingTemplate.id } : t
      )
      saveTemplates(updated)
    } else {
      // Add new
      const newTemplate: QuoteTemplate = {
        ...templateForm,
        id: Date.now().toString()
      }
      saveTemplates([...templates, newTemplate])
    }

    setShowTemplateModal(false)
    setEditingTemplate(null)
    setTemplateForm({
      name: "",
      part_category: "",
      price: 0,
      part_condition: "new",
      warranty: "none",
      message: ""
    })
  }

  // Delete template
  const handleDeleteTemplate = (id: string) => {
    if (confirm("Delete this template?")) {
      saveTemplates(templates.filter(t => t.id !== id))
    }
  }

  // Calculate analytics from quotes
  const calculateAnalytics = (quotesData: Quote[]) => {
    const totalSent = quotesData.length
    const accepted = quotesData.filter(q => q.status === "accepted").length
    const rejected = quotesData.filter(q => q.status === "rejected").length
    const pending = quotesData.filter(q => q.status === "pending").length
    const withdrawn = quotesData.filter(q => q.status === "withdrawn").length
    
    const decidedQuotes = accepted + rejected
    const winRate = decidedQuotes > 0 ? Math.round((accepted / decidedQuotes) * 100) : 0
    
    const totalValue = quotesData.reduce((sum, q) => sum + (q.price_cents || 0), 0)
    const avgQuoteValue = totalSent > 0 ? Math.round(totalValue / totalSent / 100) : 0
    
    const acceptedQuotes = quotesData.filter(q => q.status === "accepted")
    const totalRevenue = acceptedQuotes.reduce((sum, q) => sum + (q.price_cents || 0) + (q.delivery_fee_cents || 0), 0) / 100
    
    // Calculate average response time (mock - would need order timestamps in real app)
    const avgResponseTime = 2.5 // hours

    setAnalytics({
      totalSent,
      accepted,
      rejected,
      pending,
      withdrawn,
      winRate,
      avgQuoteValue,
      totalRevenue,
      avgResponseTime
    })
  }

  // Calculate market data (simulated competitor insights)
  const calculateMarketData = (quotesData: Quote[]) => {
    // Group quotes by part category
    const categoryGroups: { [key: string]: Quote[] } = {}
    quotesData.forEach(q => {
      const cat = q.part_requests?.part_category || "Other"
      if (!categoryGroups[cat]) categoryGroups[cat] = []
      categoryGroups[cat].push(q)
    })

    const marketInsights: MarketData[] = Object.entries(categoryGroups).map(([category, catQuotes]) => {
      const yourAvg = catQuotes.reduce((sum, q) => sum + (q.price_cents || 0), 0) / catQuotes.length / 100
      
      // Simulated market data (in real app, would come from aggregated anonymous data)
      const variance = 0.15 + Math.random() * 0.2 // 15-35% variance
      const marketAvg = yourAvg * (0.9 + Math.random() * 0.2) // Market avg within 10% of yours
      const marketLow = marketAvg * (1 - variance)
      const marketHigh = marketAvg * (1 + variance)
      
      let competitiveness: "below" | "average" | "above" = "average"
      if (yourAvg < marketAvg * 0.95) competitiveness = "below"
      else if (yourAvg > marketAvg * 1.05) competitiveness = "above"

      return {
        partCategory: category,
        yourAvgPrice: Math.round(yourAvg),
        marketAvgPrice: Math.round(marketAvg),
        marketLow: Math.round(marketLow),
        marketHigh: Math.round(marketHigh),
        yourQuoteCount: catQuotes.length,
        competitiveness
      }
    })

    setMarketData(marketInsights.sort((a, b) => b.yourQuoteCount - a.yourQuoteCount))
  }

  // Get pricing history for a specific part category
  const getPricingHistory = useMemo(() => {
    if (!historySearch) return []
    
    const searchLower = historySearch.toLowerCase()
    return quotes
      .filter(q => 
        q.part_requests?.part_category?.toLowerCase().includes(searchLower) ||
        q.part_requests?.vehicle_make?.toLowerCase().includes(searchLower) ||
        q.part_requests?.vehicle_model?.toLowerCase().includes(searchLower)
      )
      .map(q => ({
        date: new Date(q.created_at).toLocaleDateString(),
        part_category: q.part_requests?.part_category || "Unknown",
        vehicle: `${q.part_requests?.vehicle_year} ${q.part_requests?.vehicle_make} ${q.part_requests?.vehicle_model}`,
        price: (q.price_cents || 0) / 100,
        status: q.status
      }))
      .slice(0, 20)
  }, [quotes, historySearch])

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "accepted":
        return <span className="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-sm flex items-center gap-1"><CheckCircle className="w-4 h-4" />Accepted</span>
      case "rejected":
        return <span className="px-3 py-1 bg-red-500/20 text-red-400 rounded-full text-sm flex items-center gap-1"><XCircle className="w-4 h-4" />Declined</span>
      case "withdrawn":
        return <span className="px-3 py-1 bg-gray-500/20 text-gray-400 rounded-full text-sm flex items-center gap-1"><XCircle className="w-4 h-4" />Withdrawn</span>
      default:
        return <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-sm flex items-center gap-1"><Clock className="w-4 h-4" />Pending</span>
    }
  }

  const [withdrawing, setWithdrawing] = useState<string | null>(null)

  const handleWithdrawQuote = async (quoteId: string, requestId: string) => {
    if (!confirm("Are you sure you want to withdraw this quote? This cannot be undone.")) {
      return
    }

    setWithdrawing(quoteId)
    try {
      // Update offer status to withdrawn
      await supabase
        .from("offers")
        .update({ status: "withdrawn" })
        .eq("id", quoteId)

      // Also update the request_chat status if exists
      if (shopId) {
        await supabase
          .from("request_chats")
          .update({ status: "withdrawn" })
          .eq("shop_id", shopId)
          .eq("request_id", requestId)
      }

      // Reload quotes
      loadQuotes()
    } catch (error) {
      console.error("Error withdrawing quote:", error)
      alert("Failed to withdraw quote. Please try again.")
    } finally {
      setWithdrawing(null)
    }
  }

  const filteredQuotes = filter === "all" ? quotes : quotes.filter(q => q.status === filter)

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Main Navigation Tabs */}
      <div className="flex items-center justify-between">
        <div className="flex gap-2 bg-[#1a1a1a] p-1 rounded-xl">
          {[
            { id: "quotes", label: "My Quotes", icon: Send },
            { id: "templates", label: "Templates", icon: Bookmark },
            { id: "analytics", label: "Analytics", icon: BarChart3 },
            { id: "insights", label: "Market Insights", icon: TrendingUp },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as typeof activeTab)}
              className={`px-4 py-2 rounded-lg font-medium transition-colors flex items-center gap-2 ${
                activeTab === tab.id ? "bg-accent text-white" : "text-gray-400 hover:text-white"
              }`}
            >
              <tab.icon className="w-4 h-4" />
              <span className="hidden sm:inline">{tab.label}</span>
            </button>
          ))}
        </div>
        <div className="flex items-center gap-3">
          {lastUpdated && (
            <span className="text-gray-500 text-sm hidden md:block">
              Updated: {lastUpdated.toLocaleTimeString()}
            </span>
          )}
          <button
            onClick={() => loadQuotes()}
            className="p-2 bg-[#1a1a1a] border border-gray-800 rounded-lg hover:border-gray-700 transition-colors"
            title="Refresh"
          >
            <RefreshCw className={`w-5 h-5 text-gray-400 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* QUOTES TAB */}
      {activeTab === "quotes" && (
        <>
          {/* Pricing History Search */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
            <div className="flex items-center gap-3">
              <History className="w-5 h-5 text-accent" />
              <span className="text-white font-medium">Pricing History</span>
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                <input
                  type="text"
                  placeholder="Search past quotes by part or vehicle..."
                  value={historySearch}
                  onChange={(e) => setHistorySearch(e.target.value)}
                  className="w-full bg-[#2d2d2d] text-white pl-10 pr-4 py-2 rounded-lg border border-gray-700 focus:border-accent focus:outline-none text-sm"
                />
              </div>
            </div>
            {historySearch && getPricingHistory.length > 0 && (
              <div className="mt-3 max-h-48 overflow-y-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-gray-400 text-left">
                      <th className="pb-2">Date</th>
                      <th className="pb-2">Part</th>
                      <th className="pb-2">Vehicle</th>
                      <th className="pb-2 text-right">Price</th>
                      <th className="pb-2 text-right">Result</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getPricingHistory.map((entry, i) => (
                      <tr key={i} className="border-t border-gray-800">
                        <td className="py-2 text-gray-400">{entry.date}</td>
                        <td className="py-2 text-white">{entry.part_category}</td>
                        <td className="py-2 text-gray-300">{entry.vehicle}</td>
                        <td className="py-2 text-right text-white">R{entry.price.toLocaleString()}</td>
                        <td className="py-2 text-right">
                          <span className={`px-2 py-0.5 rounded text-xs ${
                            entry.status === 'accepted' ? 'bg-green-500/20 text-green-400' :
                            entry.status === 'rejected' ? 'bg-red-500/20 text-red-400' :
                            'bg-yellow-500/20 text-yellow-400'
                          }`}>
                            {entry.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {historySearch && getPricingHistory.length === 0 && (
              <p className="mt-3 text-gray-500 text-sm">No matching quotes found</p>
            )}
          </div>

          {/* Filter Tabs */}
          <div className="flex gap-2">
            {["all", "pending", "accepted", "rejected"].map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-4 py-2 rounded-lg font-medium capitalize transition-colors ${
                  filter === f ? "bg-accent text-white" : "bg-[#1a1a1a] text-gray-400 hover:text-white"
                }`}
              >
                {f} {f !== "all" && `(${quotes.filter(q => q.status === f).length})`}
              </button>
            ))}
          </div>

          {/* Quotes List */}
          {filteredQuotes.length === 0 ? (
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-12 text-center">
              <Send className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-white mb-2">No Quotes Yet</h3>
              <p className="text-gray-400">Quotes you send will appear here</p>
            </div>
          ) : (
            <div className="grid gap-4">
              {filteredQuotes.map((quote) => (
                <div key={quote.id} className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 bg-accent/20 rounded-lg flex items-center justify-center">
                        <Car className="w-6 h-6 text-accent" />
                      </div>
                      <div>
                        {quote.part_requests && (
                          <h3 className="text-lg font-semibold text-white">
                            {quote.part_requests.vehicle_year} {quote.part_requests.vehicle_make} {quote.part_requests.vehicle_model}
                          </h3>
                        )}
                        <p className="text-gray-400 text-sm">{quote.part_requests?.part_category}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-2xl font-bold text-white">R{(((quote.price_cents || 0) + (quote.delivery_fee_cents || 14000)) / 100).toLocaleString()}</p>
                      <p className="text-gray-500 text-sm">Incl. R{((quote.delivery_fee_cents || 14000) / 100).toFixed(0)} delivery</p>
                    </div>
                  </div>
                  <div className="mt-4 pt-4 border-t border-gray-800 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      {getStatusBadge(quote.status)}
                      {quote.status === "pending" && (
                        <button
                          onClick={() => handleWithdrawQuote(quote.id, quote.request_id)}
                          disabled={withdrawing === quote.id}
                          className="px-3 py-1 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-full text-sm flex items-center gap-1 transition-colors disabled:opacity-50"
                        >
                          <Trash2 className="w-4 h-4" />
                          {withdrawing === quote.id ? "Withdrawing..." : "Withdraw"}
                        </button>
                      )}
                    </div>
                    <span className="text-gray-500 text-sm">
                      {new Date(quote.created_at).toLocaleDateString()}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* TEMPLATES TAB */}
      {activeTab === "templates" && (
        <>
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-bold text-white">Quote Templates</h2>
              <p className="text-gray-400 text-sm">Save common parts for quick quoting</p>
            </div>
            <button
              onClick={() => { setEditingTemplate(null); setShowTemplateModal(true); }}
              className="px-4 py-2 bg-accent hover:bg-accent-hover text-white rounded-lg flex items-center gap-2 transition-colors"
            >
              <Plus className="w-4 h-4" />
              New Template
            </button>
          </div>

          {templates.length === 0 ? (
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-12 text-center">
              <FileText className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-white mb-2">No Templates Yet</h3>
              <p className="text-gray-400 mb-4">Create templates for common parts to speed up quoting</p>
              <button
                onClick={() => setShowTemplateModal(true)}
                className="px-6 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg inline-flex items-center gap-2"
              >
                <Plus className="w-5 h-5" />
                Create First Template
              </button>
            </div>
          ) : (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {templates.map((template) => (
                <div key={template.id} className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-5">
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <h3 className="text-lg font-semibold text-white">{template.name}</h3>
                      <p className="text-accent text-sm">{template.part_category}</p>
                    </div>
                    <span className="text-2xl font-bold text-white">R{template.price.toLocaleString()}</span>
                  </div>
                  <div className="flex gap-2 mb-3">
                    <span className="px-2 py-1 bg-blue-500/20 text-blue-400 rounded text-xs capitalize">{template.part_condition}</span>
                    {template.warranty !== "none" && (
                      <span className="px-2 py-1 bg-green-500/20 text-green-400 rounded text-xs">{template.warranty}</span>
                    )}
                  </div>
                  {template.message && (
                    <p className="text-gray-400 text-sm mb-3 line-clamp-2">{template.message}</p>
                  )}
                  <div className="flex gap-2 pt-3 border-t border-gray-800">
                    <button
                      onClick={() => {
                        setEditingTemplate(template)
                        setTemplateForm(template)
                        setShowTemplateModal(true)
                      }}
                      className="flex-1 px-3 py-2 bg-[#2d2d2d] hover:bg-[#3d3d3d] text-white rounded-lg text-sm transition-colors"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => handleDeleteTemplate(template.id)}
                      className="px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg text-sm transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* ANALYTICS TAB */}
      {activeTab === "analytics" && analytics && (
        <>
          <div>
            <h2 className="text-xl font-bold text-white">Quote Analytics</h2>
            <p className="text-gray-400 text-sm">Track your quote performance and win rate</p>
          </div>

          {/* Win/Loss Stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-5">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
                  <Send className="w-5 h-5 text-blue-400" />
                </div>
                <span className="text-gray-400 text-sm">Total Sent</span>
              </div>
              <p className="text-3xl font-bold text-white">{analytics.totalSent}</p>
            </div>
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-5">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
                  <CheckCircle className="w-5 h-5 text-green-400" />
                </div>
                <span className="text-gray-400 text-sm">Accepted</span>
              </div>
              <p className="text-3xl font-bold text-green-400">{analytics.accepted}</p>
            </div>
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-5">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-red-500/20 rounded-lg flex items-center justify-center">
                  <XCircle className="w-5 h-5 text-red-400" />
                </div>
                <span className="text-gray-400 text-sm">Rejected</span>
              </div>
              <p className="text-3xl font-bold text-red-400">{analytics.rejected}</p>
            </div>
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-5">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-yellow-500/20 rounded-lg flex items-center justify-center">
                  <Clock className="w-5 h-5 text-yellow-400" />
                </div>
                <span className="text-gray-400 text-sm">Pending</span>
              </div>
              <p className="text-3xl font-bold text-yellow-400">{analytics.pending}</p>
            </div>
          </div>

          {/* Win Rate & Revenue */}
          <div className="grid md:grid-cols-2 gap-4">
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <PieChart className="w-5 h-5 text-accent" />
                Win Rate
              </h3>
              <div className="flex items-center gap-6">
                <div className="relative w-32 h-32">
                  <svg className="w-full h-full transform -rotate-90">
                    <circle cx="64" cy="64" r="56" stroke="#2d2d2d" strokeWidth="12" fill="none" />
                    <circle 
                      cx="64" cy="64" r="56" 
                      stroke="#10b981" 
                      strokeWidth="12" 
                      fill="none"
                      strokeDasharray={`${analytics.winRate * 3.52} 352`}
                      strokeLinecap="round"
                    />
                  </svg>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <span className="text-3xl font-bold text-white">{analytics.winRate}%</span>
                  </div>
                </div>
                <div className="space-y-2">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                    <span className="text-gray-400">Won: {analytics.accepted}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 bg-red-500 rounded-full"></div>
                    <span className="text-gray-400">Lost: {analytics.rejected}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
                    <span className="text-gray-400">Pending: {analytics.pending}</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <DollarSign className="w-5 h-5 text-accent" />
                Revenue from Quotes
              </h3>
              <div className="space-y-4">
                <div>
                  <p className="text-gray-400 text-sm">Total Revenue (Accepted)</p>
                  <p className="text-3xl font-bold text-green-400">R{analytics.totalRevenue.toLocaleString()}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-sm">Average Quote Value</p>
                  <p className="text-2xl font-bold text-white">R{analytics.avgQuoteValue.toLocaleString()}</p>
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* MARKET INSIGHTS TAB */}
      {activeTab === "insights" && (
        <>
          <div>
            <h2 className="text-xl font-bold text-white">Market Insights</h2>
            <p className="text-gray-400 text-sm">See how your pricing compares to market averages</p>
          </div>

          {marketData.length === 0 ? (
            <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-12 text-center">
              <TrendingUp className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-white mb-2">No Data Yet</h3>
              <p className="text-gray-400">Send some quotes to see market comparisons</p>
            </div>
          ) : (
            <div className="space-y-4">
              {marketData.map((data) => (
                <div key={data.partCategory} className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-5">
                  <div className="flex items-center justify-between mb-4">
                    <div>
                      <h3 className="text-lg font-semibold text-white">{data.partCategory}</h3>
                      <p className="text-gray-500 text-sm">{data.yourQuoteCount} quotes sent</p>
                    </div>
                    <div className={`px-3 py-1 rounded-full text-sm flex items-center gap-1 ${
                      data.competitiveness === "below" ? "bg-green-500/20 text-green-400" :
                      data.competitiveness === "above" ? "bg-red-500/20 text-red-400" :
                      "bg-yellow-500/20 text-yellow-400"
                    }`}>
                      {data.competitiveness === "below" ? (
                        <><TrendingDown className="w-4 h-4" /> Below Market</>
                      ) : data.competitiveness === "above" ? (
                        <><TrendingUp className="w-4 h-4" /> Above Market</>
                      ) : (
                        <>Market Average</>
                      )}
                    </div>
                  </div>
                  
                  {/* Price Comparison Bar */}
                  <div className="mb-3">
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-gray-400">Market Range</span>
                      <span className="text-gray-400">R{data.marketLow} - R{data.marketHigh}</span>
                    </div>
                    <div className="relative h-8 bg-[#2d2d2d] rounded-lg overflow-hidden">
                      {/* Market range bar */}
                      <div 
                        className="absolute h-full bg-gray-600/50"
                        style={{
                          left: '10%',
                          width: '80%'
                        }}
                      />
                      {/* Your price marker */}
                      <div 
                        className="absolute top-0 bottom-0 w-1 bg-accent"
                        style={{
                          left: `${Math.min(90, Math.max(10, ((data.yourAvgPrice - data.marketLow) / (data.marketHigh - data.marketLow)) * 80 + 10))}%`
                        }}
                      />
                      {/* Market average marker */}
                      <div 
                        className="absolute top-0 bottom-0 w-0.5 bg-white/50"
                        style={{
                          left: '50%'
                        }}
                      />
                    </div>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <p className="text-gray-400">Your Avg Price</p>
                      <p className="text-xl font-bold text-accent">R{data.yourAvgPrice.toLocaleString()}</p>
                    </div>
                    <div>
                      <p className="text-gray-400">Market Avg Price</p>
                      <p className="text-xl font-bold text-white">R{data.marketAvgPrice.toLocaleString()}</p>
                    </div>
                  </div>
                </div>
              ))}
              
              <div className="bg-blue-500/10 border border-blue-500/30 rounded-xl p-4 flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-blue-400 font-medium">About Market Data</p>
                  <p className="text-blue-300/70 text-sm">Market averages are calculated from anonymized quote data across all shops. Your individual pricing is never shared with competitors.</p>
                </div>
              </div>
            </div>
          )}
        </>
      )}

      {/* Template Modal */}
      {showTemplateModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-md border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <h3 className="text-xl font-semibold text-white">
                {editingTemplate ? "Edit Template" : "New Template"}
              </h3>
              <button onClick={() => { setShowTemplateModal(false); setEditingTemplate(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Template Name *</label>
                <input
                  type="text"
                  value={templateForm.name}
                  onChange={(e) => setTemplateForm({ ...templateForm, name: e.target.value })}
                  placeholder="e.g., Standard Brake Kit"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Part Category *</label>
                <input
                  type="text"
                  value={templateForm.part_category}
                  onChange={(e) => setTemplateForm({ ...templateForm, part_category: e.target.value })}
                  placeholder="e.g., Brake System"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Price (ZAR) *</label>
                <input
                  type="number"
                  value={templateForm.price || ""}
                  onChange={(e) => setTemplateForm({ ...templateForm, price: parseFloat(e.target.value) || 0 })}
                  placeholder="0.00"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Condition</label>
                  <select
                    value={templateForm.part_condition}
                    onChange={(e) => setTemplateForm({ ...templateForm, part_condition: e.target.value as QuoteTemplate["part_condition"] })}
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  >
                    <option value="new">New</option>
                    <option value="used">Used</option>
                    <option value="refurbished">Refurbished</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Warranty</label>
                  <select
                    value={templateForm.warranty}
                    onChange={(e) => setTemplateForm({ ...templateForm, warranty: e.target.value })}
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  >
                    <option value="none">No Warranty</option>
                    <option value="6 months">6 Months</option>
                    <option value="12 months">12 Months</option>
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Default Message</label>
                <textarea
                  value={templateForm.message}
                  onChange={(e) => setTemplateForm({ ...templateForm, message: e.target.value })}
                  placeholder="Optional notes to include with quotes..."
                  rows={2}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none resize-none"
                />
              </div>
            </div>
            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => { setShowTemplateModal(false); setEditingTemplate(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveTemplate}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                <Save className="w-5 h-5" />
                {editingTemplate ? "Update" : "Save"} Template
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
