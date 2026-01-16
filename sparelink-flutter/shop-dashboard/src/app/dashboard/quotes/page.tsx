"use client"

import { useEffect, useState, useCallback } from "react"
import { supabase } from "@/lib/supabase"
import { Send, Clock, CheckCircle, XCircle, Car, RefreshCw, Trash2 } from "lucide-react"

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

export default function QuotesPage() {
  const [quotes, setQuotes] = useState<Quote[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState("all")
  const [shopId, setShopId] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)

  // Load quotes and set up real-time subscription
  useEffect(() => {
    loadQuotes()
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

      if (data) setQuotes(data)
      setLastUpdated(new Date())
    } catch (error) {
      console.error("Error loading quotes:", error)
    } finally {
      setLoading(false)
    }
  }

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
      {/* Filter Tabs and Refresh */}
      <div className="flex items-center justify-between">
        <div className="flex gap-2">
          {["all", "pending", "accepted", "rejected"].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-lg font-medium capitalize transition-colors ${
                filter === f ? "bg-accent text-white" : "bg-[#1a1a1a] text-gray-400 hover:text-white"
              }`}
            >
              {f}
            </button>
          ))}
        </div>
        <div className="flex items-center gap-3">
          {lastUpdated && (
            <span className="text-gray-500 text-sm">
              Updated: {lastUpdated.toLocaleTimeString()}
            </span>
          )}
          <button
            onClick={() => loadQuotes()}
            className="p-2 bg-[#1a1a1a] border border-gray-800 rounded-lg hover:border-gray-700 transition-colors"
            title="Refresh quotes"
          >
            <RefreshCw className={`w-5 h-5 text-gray-400 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
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
    </div>
  )
}
