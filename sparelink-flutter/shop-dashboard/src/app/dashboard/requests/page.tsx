"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { Search, Filter, Clock, MapPin, Car, Wrench, X, Send, Loader2, AlertCircle, CheckCircle, MessageCircle, ZoomIn } from "lucide-react"

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
  image_url: string | null  // Primary part image stored in image_url column
  profiles?: { full_name: string; phone: string }
}

interface QuoteFormData {
  price: string
  notes: string
  part_condition: "new" | "used" | "refurbished"
  warranty: "none" | "6_months" | "12_months"
}

// Fixed delivery fee of R140 for all orders (same day delivery)
const DELIVERY_FEE_RANDS = 140

const initialQuoteData: QuoteFormData = {
  price: "",
  notes: "",
  part_condition: "new",
  warranty: "none"
}

export default function RequestsPage() {
  const router = useRouter()
  const [requests, setRequests] = useState<PartRequest[]>([])
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

  useEffect(() => {
    loadRequests()
  }, [])

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

  const filteredRequests = requests.filter(req =>
    req.vehicle_make.toLowerCase().includes(searchTerm.toLowerCase()) ||
    req.vehicle_model.toLowerCase().includes(searchTerm.toLowerCase()) ||
    req.part_category.toLowerCase().includes(searchTerm.toLowerCase())
  )

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Search Bar */}
      <div className="flex items-center gap-4">
        <div className="flex-1 relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
          <input
            type="text"
            placeholder="Search by vehicle or part..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-[#1a1a1a] text-white pl-12 pr-4 py-3 rounded-xl border border-gray-800 focus:border-accent focus:outline-none"
          />
        </div>
        <button className="p-3 bg-[#1a1a1a] border border-gray-800 rounded-xl hover:border-gray-700 transition-colors">
          <Filter className="w-5 h-5 text-gray-400" />
        </button>
      </div>

      {/* Requests List */}
      {filteredRequests.length === 0 ? (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-12 text-center">
          <Car className="w-16 h-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-white mb-2">No Part Requests</h3>
          <p className="text-gray-400">New requests from mechanics will appear here</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {filteredRequests.map((request) => (
            <div key={request.id} className="bg-[#1a1a1a] rounded-xl border border-gray-800 overflow-hidden hover:border-gray-700 transition-colors">
              <div className="p-6">
                <div className="flex items-start gap-4">
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
                      <div>
                        <h3 className="text-lg font-semibold text-white">
                          {request.vehicle_year} {request.vehicle_make} {request.vehicle_model}
                        </h3>
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
                    <button
                      onClick={() => { setSelectedRequest(request); setQuoteModal(true); }}
                      className="px-6 py-3 bg-accent hover:bg-accent-hover text-white font-medium rounded-lg transition-colors flex items-center gap-2"
                    >
                      <Send className="w-4 h-4" />
                      Send Quote
                    </button>
                    
                    {/* Chat Icon - Direct link to conversation */}
                    <button
                      onClick={() => router.push(`/dashboard/chats?request=${request.id}`)}
                      className="px-6 py-2.5 bg-[#2d2d2d] hover:bg-[#3d3d3d] text-gray-300 hover:text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2 border border-gray-700"
                      title="Chat with mechanic"
                    >
                      <MessageCircle className="w-4 h-4" />
                      Chat
                    </button>
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
    </div>
  )
}
