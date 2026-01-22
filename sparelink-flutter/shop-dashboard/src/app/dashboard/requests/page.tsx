"use client"

import { useEffect, useState, useMemo } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { Search, Filter, Clock, MapPin, Car, Wrench, X, Send, Loader2, AlertCircle, CheckCircle, MessageCircle, ZoomIn, Star, Download, Archive, ChevronDown, Calendar, CheckSquare, Square } from "lucide-react"

interface PartRequest {
  id: string
  mechanic_id: string
  vehicle_make: string
  vehicle_model: string
  vehicle_year: number
  part_category: string
  part_description: string
  status: string
  created_at: string
  image_url: string | null
  profiles?: { full_name: string; phone: string }
  is_priority?: boolean // Local priority flag
}

interface QuoteFormData {
  price: string
  notes: string
  part_condition: "new" | "used" | "refurbished"
  warranty: "none" | "6_months" | "12_months"
}

interface FilterOptions {
  dateRange: "all" | "today" | "week" | "month"
  vehicleMake: string
  partType: string
  showArchived: boolean
}

// Fixed delivery fee of R140 for all orders (same day delivery)
const DELIVERY_FEE_RANDS = 140

// Auto-archive threshold: requests older than 30 days
const AUTO_ARCHIVE_DAYS = 30

const initialQuoteData: QuoteFormData = {
  price: "",
  notes: "",
  part_condition: "new",
  warranty: "none"
}

const initialFilters: FilterOptions = {
  dateRange: "all",
  vehicleMake: "",
  partType: "",
  showArchived: false
}

// Part categories for filter dropdown
const PART_CATEGORIES = [
  "Engine Parts",
  "Brake System",
  "Suspension",
  "Transmission",
  "Electrical",
  "Body Parts",
  "Interior",
  "Exhaust",
  "Cooling System",
  "Fuel System",
  "Steering",
  "Other"
]

export default function RequestsPage() {
  const router = useRouter()
  const [requests, setRequests] = useState<PartRequest[]>([])
  const [archivedRequests, setArchivedRequests] = useState<Set<string>>(new Set())
  const [priorityRequests, setPriorityRequests] = useState<Set<string>>(new Set())
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState("")
  const [selectedRequest, setSelectedRequest] = useState<PartRequest | null>(null)
  const [quoteModal, setQuoteModal] = useState(false)
  const [quoteData, setQuoteData] = useState<QuoteFormData>(initialQuoteData)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [lightboxImage, setLightboxImage] = useState<string | null>(null)
  const [shopId, setShopId] = useState<string | null>(null)
  
  // New state for advanced features
  const [showFilters, setShowFilters] = useState(false)
  const [filters, setFilters] = useState<FilterOptions>(initialFilters)
  const [selectedRequests, setSelectedRequests] = useState<Set<string>>(new Set())
  const [bulkQuoteModal, setBulkQuoteModal] = useState(false)
  const [bulkQuoteData, setBulkQuoteData] = useState<QuoteFormData>(initialQuoteData)
  const [bulkSending, setBulkSending] = useState(false)

  useEffect(() => {
    loadRequests()
    loadLocalStorage()
  }, [])

  // Load priority and archived status from localStorage
  const loadLocalStorage = () => {
    try {
      const savedPriority = localStorage.getItem('sparelink-priority-requests')
      const savedArchived = localStorage.getItem('sparelink-archived-requests')
      if (savedPriority) setPriorityRequests(new Set(JSON.parse(savedPriority)))
      if (savedArchived) setArchivedRequests(new Set(JSON.parse(savedArchived)))
    } catch (e) {
      console.error('Error loading localStorage:', e)
    }
  }

  // Save priority requests to localStorage
  const savePriorityRequests = (newSet: Set<string>) => {
    localStorage.setItem('sparelink-priority-requests', JSON.stringify([...newSet]))
    setPriorityRequests(newSet)
  }

  // Save archived requests to localStorage
  const saveArchivedRequests = (newSet: Set<string>) => {
    localStorage.setItem('sparelink-archived-requests', JSON.stringify([...newSet]))
    setArchivedRequests(newSet)
  }

  const loadRequests = async () => {
    try {
      // Get authenticated user and their shop
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        setLoading(false)
        return
      }

      const { data: shop } = await supabase
        .from("shops")
        .select("id")
        .eq("owner_id", user.id)
        .single()

      if (!shop) {
        console.error("No shop found for user")
        setLoading(false)
        return
      }
      
      setShopId(shop.id)

      // Get request_chats assigned to THIS shop that are still pending for THIS shop
      // This ensures each shop sees requests independently - one shop's action doesn't affect others
      const { data: assignedChats } = await supabase
        .from("request_chats")
        .select("request_id, status")
        .eq("shop_id", shop.id)
        .eq("status", "pending") // Only show chats where THIS shop hasn't responded yet

      if (!assignedChats || assignedChats.length === 0) {
        setRequests([])
        setLoading(false)
        return
      }

      const requestIds = assignedChats.map(chat => chat.request_id)

      // Fetch part requests - don't filter by part_requests.status since we already filtered by request_chats.status
      // This allows showing requests even if another shop has already quoted
      const { data } = await supabase
        .from("part_requests")
        .select("*, profiles:mechanic_id(full_name, phone)")
        .in("id", requestIds)
        .order("created_at", { ascending: false })

      if (data) setRequests(data)
    } catch (error) {
      console.error("Error loading requests:", error)
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString("en-ZA", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" })
  }

  // Get unique vehicle makes for filter dropdown
  const uniqueVehicleMakes = useMemo(() => {
    const makes = [...new Set(requests.map(r => r.vehicle_make))]
    return makes.sort()
  }, [requests])

  // Toggle priority status for a request
  const togglePriority = (requestId: string) => {
    const newSet = new Set(priorityRequests)
    if (newSet.has(requestId)) {
      newSet.delete(requestId)
    } else {
      newSet.add(requestId)
    }
    savePriorityRequests(newSet)
  }

  // Archive a request
  const archiveRequest = (requestId: string) => {
    const newSet = new Set(archivedRequests)
    newSet.add(requestId)
    saveArchivedRequests(newSet)
    setSelectedRequests(prev => {
      const updated = new Set(prev)
      updated.delete(requestId)
      return updated
    })
  }

  // Unarchive a request
  const unarchiveRequest = (requestId: string) => {
    const newSet = new Set(archivedRequests)
    newSet.delete(requestId)
    saveArchivedRequests(newSet)
  }

  // Auto-archive old requests (called on load)
  useEffect(() => {
    if (requests.length > 0) {
      const now = new Date()
      const archiveThreshold = new Date(now.getTime() - AUTO_ARCHIVE_DAYS * 24 * 60 * 60 * 1000)
      const newArchived = new Set(archivedRequests)
      let changed = false
      
      requests.forEach(req => {
        const reqDate = new Date(req.created_at)
        if (reqDate < archiveThreshold && !newArchived.has(req.id)) {
          newArchived.add(req.id)
          changed = true
        }
      })
      
      if (changed) {
        saveArchivedRequests(newArchived)
      }
    }
  }, [requests])

  // Toggle selection for bulk actions
  const toggleSelection = (requestId: string) => {
    setSelectedRequests(prev => {
      const newSet = new Set(prev)
      if (newSet.has(requestId)) {
        newSet.delete(requestId)
      } else {
        newSet.add(requestId)
      }
      return newSet
    })
  }

  // Select/deselect all visible requests
  const toggleSelectAll = () => {
    if (selectedRequests.size === filteredRequests.length) {
      setSelectedRequests(new Set())
    } else {
      setSelectedRequests(new Set(filteredRequests.map(r => r.id)))
    }
  }

  // Export requests to CSV
  const exportToCSV = () => {
    const dataToExport = selectedRequests.size > 0 
      ? filteredRequests.filter(r => selectedRequests.has(r.id))
      : filteredRequests

    const headers = ['ID', 'Vehicle', 'Year', 'Part Category', 'Description', 'Status', 'Requested By', 'Date']
    const rows = dataToExport.map(req => [
      req.id,
      `${req.vehicle_make} ${req.vehicle_model}`,
      req.vehicle_year,
      req.part_category,
      `"${(req.part_description || '').replace(/"/g, '""')}"`,
      req.status,
      req.profiles?.full_name || 'Unknown',
      new Date(req.created_at).toISOString().split('T')[0]
    ])

    const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)
    link.setAttribute('href', url)
    link.setAttribute('download', `part-requests-${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  // Bulk quote sending
  const handleBulkQuote = async () => {
    if (selectedRequests.size === 0 || !bulkQuoteData.price) {
      setError("Please select requests and enter a price")
      return
    }

    setBulkSending(true)
    setError(null)
    setSuccess(null)

    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error("Not authenticated")

      const { data: shop } = await supabase
        .from("shops")
        .select("id, name")
        .eq("owner_id", user.id)
        .single()

      if (!shop) throw new Error("No shop found")

      const priceInCents = Math.round(parseFloat(bulkQuoteData.price) * 100)
      const deliveryFeeInCents = DELIVERY_FEE_RANDS * 100
      const etaInMinutes = 1 * 24 * 60

      const warrantyText = bulkQuoteData.warranty === "none" 
        ? null 
        : bulkQuoteData.warranty === "6_months" 
          ? "6 months" 
          : "12 months"

      let successCount = 0
      let errorCount = 0

      for (const requestId of selectedRequests) {
        const request = requests.find(r => r.id === requestId)
        if (!request) continue

        try {
          // Create offer
          const { error: offerError } = await supabase
            .from("offers")
            .insert({
              request_id: requestId,
              shop_id: shop.id,
              price_cents: priceInCents,
              delivery_fee_cents: deliveryFeeInCents,
              eta_minutes: etaInMinutes,
              part_condition: bulkQuoteData.part_condition,
              warranty: warrantyText,
              message: bulkQuoteData.notes || null,
              status: "pending"
            })

          if (offerError) {
            errorCount++
            continue
          }

          // Update request_chats status
          await supabase
            .from("request_chats")
            .update({ 
              status: "quoted",
              quote_amount: priceInCents,
              delivery_fee: deliveryFeeInCents,
              updated_at: new Date().toISOString()
            })
            .eq("request_id", requestId)
            .eq("shop_id", shop.id)

          // Send notification
          await supabase.from("notifications").insert({
            user_id: request.mechanic_id,
            type: "quote",
            title: "New Quote Received",
            body: `${shop.name || "A shop"} quoted R${bulkQuoteData.price} for your ${request.part_category} request`,
            reference_id: requestId
          })

          successCount++
        } catch (e) {
          errorCount++
        }
      }

      setSuccess(`Sent ${successCount} quotes successfully${errorCount > 0 ? ` (${errorCount} failed)` : ''}`)
      
      setTimeout(() => {
        setBulkQuoteModal(false)
        setBulkQuoteData(initialQuoteData)
        setSelectedRequests(new Set())
        loadRequests()
      }, 1500)

    } catch (err: any) {
      setError(err.message || "Failed to send bulk quotes")
    } finally {
      setBulkSending(false)
    }
  }

  // Filter logic with date range, vehicle make, part type
  const filteredRequests = useMemo(() => {
    let result = requests

    // Filter by archived status
    if (!filters.showArchived) {
      result = result.filter(r => !archivedRequests.has(r.id))
    } else {
      result = result.filter(r => archivedRequests.has(r.id))
    }

    // Filter by search term
    if (searchTerm) {
      const term = searchTerm.toLowerCase()
      result = result.filter(req =>
        req.vehicle_make.toLowerCase().includes(term) ||
        req.vehicle_model.toLowerCase().includes(term) ||
        req.part_category.toLowerCase().includes(term) ||
        (req.part_description || '').toLowerCase().includes(term)
      )
    }

    // Filter by date range
    if (filters.dateRange !== "all") {
      const now = new Date()
      let cutoff: Date
      switch (filters.dateRange) {
        case "today":
          cutoff = new Date(now.getFullYear(), now.getMonth(), now.getDate())
          break
        case "week":
          cutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
          break
        case "month":
          cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
          break
        default:
          cutoff = new Date(0)
      }
      result = result.filter(r => new Date(r.created_at) >= cutoff)
    }

    // Filter by vehicle make
    if (filters.vehicleMake) {
      result = result.filter(r => r.vehicle_make === filters.vehicleMake)
    }

    // Filter by part type
    if (filters.partType) {
      result = result.filter(r => r.part_category === filters.partType)
    }

    // Sort: priority first, then by date
    result.sort((a, b) => {
      const aPriority = priorityRequests.has(a.id) ? 1 : 0
      const bPriority = priorityRequests.has(b.id) ? 1 : 0
      if (bPriority !== aPriority) return bPriority - aPriority
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    })

    return result
  }, [requests, searchTerm, filters, archivedRequests, priorityRequests])

  const handleSendQuote = async () => {
    if (!selectedRequest || !quoteData.price) {
      setError("Please enter a price for the quote")
      return
    }
    
    // Clear any previous messages
    setError(null)
    setSuccess(null)
    setSending(true)
    
    try {
      // Step 1: Get authenticated user
      const { data: { user }, error: authError } = await supabase.auth.getUser()
      if (authError) {
        throw new Error(`Authentication error: ${authError.message}`)
      }
      if (!user) {
        throw new Error("You must be logged in to send a quote")
      }

      // Step 2: Get shop details
      const { data: shop, error: shopError } = await supabase
        .from("shops")
        .select("id, name")
        .eq("owner_id", user.id)
        .single()

      if (shopError) {
        throw new Error(`Shop lookup error: ${shopError.message}`)
      }
      if (!shop) {
        throw new Error("No shop found for your account. Please set up your shop in Settings first.")
      }

      // Step 3: Create or get conversation (for chat functionality)
      const { data: existingConversation } = await supabase
        .from("conversations")
        .select("id")
        .eq("request_id", selectedRequest.id)
        .eq("shop_id", shop.id)
        .single()

      if (!existingConversation) {
        const { error: convError } = await supabase
          .from("conversations")
          .insert({
            request_id: selectedRequest.id,
            mechanic_id: selectedRequest.mechanic_id,
            shop_id: shop.id
          })
        
        if (convError) {
          console.warn("Conversation creation warning:", convError.message)
          // Don't throw - conversation is optional for quote to work
        }
      }

      // Step 4: Create the offer with CORRECT column names matching the database schema
      const priceInCents = Math.round(parseFloat(quoteData.price) * 100)
      const deliveryFeeInCents = DELIVERY_FEE_RANDS * 100 // Fixed R140 delivery fee
      const etaInMinutes = 1 * 24 * 60 // Same day delivery = 1 day in minutes

      // Convert warranty selection to readable text
      const warrantyText = quoteData.warranty === "none" 
        ? null 
        : quoteData.warranty === "6_months" 
          ? "6 months" 
          : "12 months"

      const offerPayload = {
        request_id: selectedRequest.id,
        shop_id: shop.id,
        price_cents: priceInCents,
        delivery_fee_cents: deliveryFeeInCents,
        eta_minutes: etaInMinutes,
        part_condition: quoteData.part_condition,
        warranty: warrantyText,
        message: quoteData.notes || null,
        status: "pending"
      }

      console.log("Inserting offer with payload:", offerPayload)

      const { data: offerData, error: offerError } = await supabase
        .from("offers")
        .insert(offerPayload)
        .select()
        .single()

      if (offerError) {
        console.error("Offer insert error details:", offerError)
        throw new Error(`Failed to create offer: ${offerError.message}${offerError.details ? ` - ${offerError.details}` : ""}${offerError.hint ? ` (Hint: ${offerError.hint})` : ""}`)
      }

      console.log("Offer created successfully:", offerData)

      // Step 5: Update request_chats status to 'quoted' for this shop
      const { error: chatUpdateError } = await supabase
        .from("request_chats")
        .update({ 
          status: "quoted",
          quote_amount: priceInCents,
          delivery_fee: deliveryFeeInCents,
          updated_at: new Date().toISOString()
        })
        .eq("request_id", selectedRequest.id)
        .eq("shop_id", shop.id)

      if (chatUpdateError) {
        console.warn("Request chat update warning:", chatUpdateError.message)
      }

      // Step 6: Send notification to mechanic
      const { error: notifError } = await supabase.from("notifications").insert({
        user_id: selectedRequest.mechanic_id,
        type: "quote",
        title: "New Quote Received",
        body: `${shop.name || "A shop"} quoted R${quoteData.price} for your ${selectedRequest.part_category} request`,
        reference_id: selectedRequest.id
      })

      if (notifError) {
        console.warn("Notification creation warning:", notifError.message)
        // Don't throw - notification failure shouldn't fail the whole quote
      }

      // Success!
      setSuccess("Quote sent successfully! The mechanic has been notified.")
      
      // Close modal after a short delay so user sees success message
      setTimeout(() => {
        setQuoteModal(false)
        setQuoteData(initialQuoteData)
        setSelectedRequest(null)
        setSuccess(null)
      }, 1500)

    } catch (error) {
      console.error("Error sending quote:", error)
      const errorMessage = error instanceof Error ? error.message : "An unexpected error occurred"
      setError(errorMessage)
    } finally {
      setSending(false)
    }
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
      {/* Header with title and actions */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Part Requests</h1>
          <p className="text-gray-400 text-sm mt-1">
            {filteredRequests.length} request{filteredRequests.length !== 1 ? 's' : ''} 
            {filters.showArchived ? ' (archived)' : ''}
            {selectedRequests.size > 0 && ` • ${selectedRequests.size} selected`}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {/* Export Button */}
          <button
            onClick={exportToCSV}
            className="px-4 py-2 bg-[#1a1a1a] border border-gray-800 rounded-lg hover:border-gray-700 transition-colors flex items-center gap-2 text-gray-300 hover:text-white"
            title="Export to CSV"
          >
            <Download className="w-4 h-4" />
            <span className="hidden sm:inline">Export</span>
          </button>
          {/* Toggle Archived View */}
          <button
            onClick={() => setFilters(f => ({ ...f, showArchived: !f.showArchived }))}
            className={`px-4 py-2 rounded-lg border transition-colors flex items-center gap-2 ${
              filters.showArchived 
                ? 'bg-yellow-500/20 border-yellow-500/50 text-yellow-400' 
                : 'bg-[#1a1a1a] border-gray-800 text-gray-300 hover:border-gray-700'
            }`}
          >
            <Archive className="w-4 h-4" />
            <span className="hidden sm:inline">{filters.showArchived ? 'Viewing Archived' : 'Archive'}</span>
          </button>
        </div>
      </div>

      {/* Search and Filter Bar */}
      <div className="flex items-center gap-4">
        <div className="flex-1 relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
          <input
            type="text"
            placeholder="Search by vehicle, part, or description..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-[#1a1a1a] text-white pl-12 pr-4 py-3 rounded-xl border border-gray-800 focus:border-accent focus:outline-none"
          />
        </div>
        <button 
          onClick={() => setShowFilters(!showFilters)}
          className={`p-3 rounded-xl border transition-colors flex items-center gap-2 ${
            showFilters || filters.dateRange !== 'all' || filters.vehicleMake || filters.partType
              ? 'bg-accent/20 border-accent/50 text-accent'
              : 'bg-[#1a1a1a] border-gray-800 hover:border-gray-700 text-gray-400'
          }`}
        >
          <Filter className="w-5 h-5" />
          <ChevronDown className={`w-4 h-4 transition-transform ${showFilters ? 'rotate-180' : ''}`} />
        </button>
      </div>

      {/* Advanced Filters Panel */}
      {showFilters && (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {/* Date Range Filter */}
            <div>
              <label className="block text-gray-400 text-sm mb-2">Date Range</label>
              <select
                value={filters.dateRange}
                onChange={(e) => setFilters(f => ({ ...f, dateRange: e.target.value as FilterOptions['dateRange'] }))}
                className="w-full bg-[#2d2d2d] text-white px-4 py-2.5 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">Last 7 Days</option>
                <option value="month">Last 30 Days</option>
              </select>
            </div>

            {/* Vehicle Make Filter */}
            <div>
              <label className="block text-gray-400 text-sm mb-2">Vehicle Make</label>
              <select
                value={filters.vehicleMake}
                onChange={(e) => setFilters(f => ({ ...f, vehicleMake: e.target.value }))}
                className="w-full bg-[#2d2d2d] text-white px-4 py-2.5 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
              >
                <option value="">All Makes</option>
                {uniqueVehicleMakes.map(make => (
                  <option key={make} value={make}>{make}</option>
                ))}
              </select>
            </div>

            {/* Part Type Filter */}
            <div>
              <label className="block text-gray-400 text-sm mb-2">Part Type</label>
              <select
                value={filters.partType}
                onChange={(e) => setFilters(f => ({ ...f, partType: e.target.value }))}
                className="w-full bg-[#2d2d2d] text-white px-4 py-2.5 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
              >
                <option value="">All Types</option>
                {PART_CATEGORIES.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Clear Filters */}
          {(filters.dateRange !== 'all' || filters.vehicleMake || filters.partType) && (
            <button
              onClick={() => setFilters({ ...initialFilters, showArchived: filters.showArchived })}
              className="mt-4 text-sm text-accent hover:text-accent-hover transition-colors"
            >
              Clear all filters
            </button>
          )}
        </div>
      )}

      {/* Bulk Actions Toolbar */}
      {selectedRequests.size > 0 && !filters.showArchived && (
        <div className="bg-accent/10 border border-accent/30 rounded-xl p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={toggleSelectAll}
              className="text-accent hover:text-accent-hover transition-colors"
            >
              {selectedRequests.size === filteredRequests.length ? (
                <CheckSquare className="w-5 h-5" />
              ) : (
                <Square className="w-5 h-5" />
              )}
            </button>
            <span className="text-white font-medium">{selectedRequests.size} selected</span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setBulkQuoteModal(true)}
              className="px-4 py-2 bg-accent hover:bg-accent-hover text-white font-medium rounded-lg transition-colors flex items-center gap-2"
            >
              <Send className="w-4 h-4" />
              Send Bulk Quote
            </button>
            <button
              onClick={() => {
                selectedRequests.forEach(id => archiveRequest(id))
                setSelectedRequests(new Set())
              }}
              className="px-4 py-2 bg-yellow-500/20 hover:bg-yellow-500/30 text-yellow-400 font-medium rounded-lg transition-colors flex items-center gap-2"
            >
              <Archive className="w-4 h-4" />
              Archive Selected
            </button>
          </div>
        </div>
      )}

      {/* Requests List */}
      {filteredRequests.length === 0 ? (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-12 text-center">
          <Car className="w-16 h-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-white mb-2">
            {filters.showArchived ? 'No Archived Requests' : 'No Part Requests'}
          </h3>
          <p className="text-gray-400">
            {filters.showArchived 
              ? 'Archived requests will appear here'
              : 'New requests from mechanics will appear here'}
          </p>
        </div>
      ) : (
        <div className="grid gap-4">
          {filteredRequests.map((request) => (
            <div 
              key={request.id} 
              className={`bg-[#1a1a1a] rounded-xl border overflow-hidden transition-colors ${
                selectedRequests.has(request.id) 
                  ? 'border-accent' 
                  : priorityRequests.has(request.id)
                    ? 'border-yellow-500/50'
                    : 'border-gray-800 hover:border-gray-700'
              }`}
            >
              <div className="p-6">
                <div className="flex items-start gap-4">
                  {/* Checkbox for bulk selection */}
                  {!filters.showArchived && (
                    <button
                      onClick={() => toggleSelection(request.id)}
                      className="flex-shrink-0 mt-1"
                    >
                      {selectedRequests.has(request.id) ? (
                        <CheckSquare className="w-5 h-5 text-accent" />
                      ) : (
                        <Square className="w-5 h-5 text-gray-600 hover:text-gray-400" />
                      )}
                    </button>
                  )}

                  {/* Part Image - Clickable for Lightbox */}
                  <div className="flex-shrink-0">
                    {request.image_url ? (
                      <div 
                        onClick={() => setLightboxImage(request.image_url)}
                        className="relative w-24 h-24 rounded-lg overflow-hidden cursor-pointer group"
                      >
                        <img 
                          src={request.image_url} 
                          alt={request.part_category}
                          className="w-full h-full object-cover transition-transform group-hover:scale-110"
                        />
                        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                          <ZoomIn className="w-6 h-6 text-white" />
                        </div>
                      </div>
                    ) : (
                      <div className="w-24 h-24 bg-[#2d2d2d] rounded-lg flex items-center justify-center">
                        <Car className="w-8 h-8 text-gray-600" />
                      </div>
                    )}
                  </div>

                  {/* Request Details */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-3 mb-2">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <h3 className="text-lg font-semibold text-white">
                            {request.vehicle_year} {request.vehicle_make} {request.vehicle_model}
                          </h3>
                          {priorityRequests.has(request.id) && (
                            <span className="px-2 py-0.5 bg-yellow-500/20 text-yellow-400 rounded text-xs font-medium">
                              Priority
                            </span>
                          )}
                        </div>
                        <p className="text-gray-400 text-sm flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          {formatDate(request.created_at)}
                        </p>
                      </div>
                    </div>
                    
                    <div className="flex items-center gap-2 mb-3">
                      <span className="px-3 py-1 bg-blue-500/20 text-blue-400 rounded-full text-sm font-medium">
                        {request.part_category}
                      </span>
                      <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-sm">
                        {request.status}
                      </span>
                    </div>

                    {request.part_description && (
                      <p className="text-gray-300 mb-3 line-clamp-2">{request.part_description}</p>
                    )}

                    {request.profiles && (
                      <p className="text-gray-500 text-sm">
                        Requested by: {request.profiles.full_name}
                      </p>
                    )}
                  </div>

                  {/* Action Buttons */}
                  <div className="flex flex-col gap-2 flex-shrink-0">
                    {!filters.showArchived ? (
                      <>
                        <button
                          onClick={() => { setSelectedRequest(request); setQuoteModal(true); }}
                          className="px-6 py-3 bg-accent hover:bg-accent-hover text-white font-medium rounded-lg transition-colors flex items-center gap-2"
                        >
                          <Send className="w-4 h-4" />
                          Send Quote
                        </button>
                        
                        {/* Chat Button */}
                        <button
                          onClick={() => router.push(`/dashboard/chats?request=${request.id}`)}
                          className="px-6 py-2.5 bg-[#2d2d2d] hover:bg-[#3d3d3d] text-gray-300 hover:text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2 border border-gray-700"
                          title="Chat with mechanic"
                        >
                          <MessageCircle className="w-4 h-4" />
                          Chat
                        </button>

                        {/* Priority & Archive Row */}
                        <div className="flex gap-2">
                          <button
                            onClick={() => togglePriority(request.id)}
                            className={`flex-1 px-3 py-2 rounded-lg transition-colors flex items-center justify-center gap-1 ${
                              priorityRequests.has(request.id)
                                ? 'bg-yellow-500/20 text-yellow-400 border border-yellow-500/50'
                                : 'bg-[#2d2d2d] text-gray-400 hover:text-yellow-400 border border-gray-700'
                            }`}
                            title={priorityRequests.has(request.id) ? 'Remove priority' : 'Mark as priority'}
                          >
                            <Star className={`w-4 h-4 ${priorityRequests.has(request.id) ? 'fill-current' : ''}`} />
                          </button>
                          <button
                            onClick={() => archiveRequest(request.id)}
                            className="flex-1 px-3 py-2 bg-[#2d2d2d] text-gray-400 hover:text-white rounded-lg transition-colors flex items-center justify-center gap-1 border border-gray-700"
                            title="Archive request"
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                        </div>
                      </>
                    ) : (
                      <button
                        onClick={() => unarchiveRequest(request.id)}
                        className="px-6 py-3 bg-yellow-500/20 hover:bg-yellow-500/30 text-yellow-400 font-medium rounded-lg transition-colors flex items-center gap-2"
                      >
                        <Archive className="w-4 h-4" />
                        Unarchive
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Quote Modal */}
      {quoteModal && selectedRequest && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-lg border border-gray-800 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-800 sticky top-0 bg-[#1a1a1a]">
              <h3 className="text-xl font-semibold text-white">Send Quote</h3>
              <button onClick={() => { setQuoteModal(false); setError(null); setSuccess(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              {/* Error Message */}
              {error && (
                <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-4 flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-red-400 font-medium">Error</p>
                    <p className="text-red-300 text-sm">{error}</p>
                  </div>
                </div>
              )}

              {/* Success Message */}
              {success && (
                <div className="bg-green-500/10 border border-green-500/50 rounded-lg p-4 flex items-start gap-3">
                  <CheckCircle className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-green-400 font-medium">Success</p>
                    <p className="text-green-300 text-sm">{success}</p>
                  </div>
                </div>
              )}

              {/* Request Info */}
              <div className="bg-[#2d2d2d] rounded-lg p-4">
                <p className="text-white font-medium">
                  {selectedRequest.vehicle_year} {selectedRequest.vehicle_make} {selectedRequest.vehicle_model}
                </p>
                <p className="text-gray-400 text-sm">{selectedRequest.part_category}</p>
                {selectedRequest.part_description && (
                  <p className="text-gray-500 text-sm mt-2">{selectedRequest.part_description}</p>
                )}
              </div>

              {/* Part Price */}
              <div>
                <label className="block text-sm text-gray-400 mb-2">Part Price (ZAR) *</label>
                <input
                  type="number"
                  value={quoteData.price}
                  onChange={(e) => setQuoteData({ ...quoteData, price: e.target.value })}
                  placeholder="0.00"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>

              {/* Part Condition and Warranty - Side by Side */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Part Condition</label>
                  <select
                    value={quoteData.part_condition}
                    onChange={(e) => setQuoteData({ ...quoteData, part_condition: e.target.value as QuoteFormData["part_condition"] })}
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
                    value={quoteData.warranty}
                    onChange={(e) => setQuoteData({ ...quoteData, warranty: e.target.value as QuoteFormData["warranty"] })}
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  >
                    <option value="none">No Warranty</option>
                    <option value="6_months">6 Months</option>
                    <option value="12_months">12 Months</option>
                  </select>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block text-sm text-gray-400 mb-2">Message / Notes (Optional)</label>
                <textarea
                  value={quoteData.notes}
                  onChange={(e) => setQuoteData({ ...quoteData, notes: e.target.value })}
                  placeholder="Add any additional details about the part..."
                  rows={3}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none resize-none"
                />
              </div>

              {/* Total Preview - Auto-adds R140 delivery */}
              {quoteData.price && (
                <div className="bg-accent/10 border border-accent/30 rounded-lg p-4">
                  <div className="flex justify-between text-sm text-gray-400 mb-1">
                    <span>Part Price:</span>
                    <span>R {parseFloat(quoteData.price || "0").toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-sm text-gray-400 mb-2">
                    <span>Delivery Fee (Same Day):</span>
                    <span>R {DELIVERY_FEE_RANDS.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-white font-semibold border-t border-gray-700 pt-2">
                    <span>Total Quote:</span>
                    <span>R {(parseFloat(quoteData.price || "0") + DELIVERY_FEE_RANDS).toFixed(2)}</span>
                  </div>
                </div>
              )}
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3 sticky bottom-0 bg-[#1a1a1a]">
              <button
                onClick={() => { setQuoteModal(false); setError(null); setSuccess(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
                disabled={sending}
              >
                Cancel
              </button>
              <button
                onClick={handleSendQuote}
                disabled={!quoteData.price || sending || !!success}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {sending ? (
                  <><Loader2 className="w-5 h-5 animate-spin" /> Sending...</>
                ) : success ? (
                  <><CheckCircle className="w-5 h-5" /> Sent!</>
                ) : (
                  <><Send className="w-5 h-5" /> Send Quote</>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Image Lightbox Modal */}
      {lightboxImage && (
        <div 
          className="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-4"
          onClick={() => setLightboxImage(null)}
        >
          <button 
            onClick={() => setLightboxImage(null)}
            className="absolute top-4 right-4 text-white hover:text-gray-300 p-2"
          >
            <X className="w-8 h-8" />
          </button>
          <img 
            src={lightboxImage} 
            alt="Part image"
            className="max-w-full max-h-[90vh] object-contain rounded-lg"
            onClick={(e) => e.stopPropagation()}
          />
        </div>
      )}

      {/* Bulk Quote Modal */}
      {bulkQuoteModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-lg border border-gray-800 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-800 sticky top-0 bg-[#1a1a1a]">
              <div>
                <h3 className="text-xl font-semibold text-white">Send Bulk Quote</h3>
                <p className="text-gray-400 text-sm mt-1">{selectedRequests.size} requests selected</p>
              </div>
              <button onClick={() => { setBulkQuoteModal(false); setError(null); setSuccess(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              {/* Error Message */}
              {error && (
                <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-4 flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-red-400 font-medium">Error</p>
                    <p className="text-red-300 text-sm">{error}</p>
                  </div>
                </div>
              )}

              {/* Success Message */}
              {success && (
                <div className="bg-green-500/10 border border-green-500/50 rounded-lg p-4 flex items-start gap-3">
                  <CheckCircle className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-green-400 font-medium">Success</p>
                    <p className="text-green-300 text-sm">{success}</p>
                  </div>
                </div>
              )}

              {/* Selected Requests Summary */}
              <div className="bg-[#2d2d2d] rounded-lg p-4 max-h-32 overflow-y-auto">
                <p className="text-gray-400 text-sm mb-2">Selected requests:</p>
                <div className="space-y-1">
                  {[...selectedRequests].map(id => {
                    const req = requests.find(r => r.id === id)
                    return req ? (
                      <p key={id} className="text-white text-sm">
                        • {req.vehicle_year} {req.vehicle_make} {req.vehicle_model} - {req.part_category}
                      </p>
                    ) : null
                  })}
                </div>
              </div>

              {/* Part Price */}
              <div>
                <label className="block text-sm text-gray-400 mb-2">Price per Part (ZAR) *</label>
                <input
                  type="number"
                  value={bulkQuoteData.price}
                  onChange={(e) => setBulkQuoteData({ ...bulkQuoteData, price: e.target.value })}
                  placeholder="0.00"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
                <p className="text-gray-500 text-xs mt-1">Same price will be applied to all selected requests</p>
              </div>

              {/* Part Condition and Warranty */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Part Condition</label>
                  <select
                    value={bulkQuoteData.part_condition}
                    onChange={(e) => setBulkQuoteData({ ...bulkQuoteData, part_condition: e.target.value as QuoteFormData["part_condition"] })}
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
                    value={bulkQuoteData.warranty}
                    onChange={(e) => setBulkQuoteData({ ...bulkQuoteData, warranty: e.target.value as QuoteFormData["warranty"] })}
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  >
                    <option value="none">No Warranty</option>
                    <option value="6_months">6 Months</option>
                    <option value="12_months">12 Months</option>
                  </select>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block text-sm text-gray-400 mb-2">Message / Notes (Optional)</label>
                <textarea
                  value={bulkQuoteData.notes}
                  onChange={(e) => setBulkQuoteData({ ...bulkQuoteData, notes: e.target.value })}
                  placeholder="Add any additional details..."
                  rows={2}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none resize-none"
                />
              </div>

              {/* Total Preview */}
              {bulkQuoteData.price && (
                <div className="bg-accent/10 border border-accent/30 rounded-lg p-4 space-y-2 text-sm">
                  <div className="flex justify-between text-gray-400">
                    <span>Part Price × {selectedRequests.size}:</span>
                    <span>R {(parseFloat(bulkQuoteData.price || "0") * selectedRequests.size).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-gray-400">
                    <span>Delivery Fee × {selectedRequests.size}:</span>
                    <span>R {(DELIVERY_FEE_RANDS * selectedRequests.size).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-white font-semibold border-t border-accent/30 pt-2">
                    <span>Total (all quotes):</span>
                    <span>R {((parseFloat(bulkQuoteData.price || "0") + DELIVERY_FEE_RANDS) * selectedRequests.size).toFixed(2)}</span>
                  </div>
                </div>
              )}
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3 sticky bottom-0 bg-[#1a1a1a]">
              <button
                onClick={() => { setBulkQuoteModal(false); setError(null); setSuccess(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
                disabled={bulkSending}
              >
                Cancel
              </button>
              <button
                onClick={handleBulkQuote}
                disabled={!bulkQuoteData.price || bulkSending || !!success}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {bulkSending ? (
                  <><Loader2 className="w-5 h-5 animate-spin" /> Sending {selectedRequests.size} quotes...</>
                ) : success ? (
                  <><CheckCircle className="w-5 h-5" /> Sent!</>
                ) : (
                  <><Send className="w-5 h-5" /> Send {selectedRequests.size} Quotes</>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
