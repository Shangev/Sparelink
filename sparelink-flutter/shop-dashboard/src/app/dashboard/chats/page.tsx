"use client"

import { useEffect, useState, useRef } from "react"
import { useSearchParams } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { MessageSquare, Clock, Car, User, ChevronRight, Send, ArrowUp, Tag, Package, Truck, ZoomIn, X, Image as ImageIcon, Check, CheckCheck } from "lucide-react"

interface RequestChat {
  id: string
  request_id: string
  shop_id: string
  status: string
  quote_amount: number | null
  delivery_fee: number | null
  created_at: string
  updated_at: string
  part_requests?: {
    id: string
    vehicle_make: string
    vehicle_model: string
    vehicle_year: number
    part_category: string
    status: string
    mechanic_id: string
    image_url?: string | null
  }
  profiles?: {
    full_name: string
    phone: string
  }
  offers?: {
    id: string
    price_cents: number
    delivery_fee_cents: number
    part_condition: string
    warranty: string | null
    message: string | null
    status: string
  }
  // WhatsApp-style fields
  last_message_text?: string | null
  last_message_at?: string | null
  last_message_is_mine?: boolean
  last_message_is_read?: boolean
  unread_count?: number
}

interface Message {
  id: string
  conversation_id: string
  sender_id: string
  text: string
  sent_at: string
}

export default function ChatsPage() {
  const searchParams = useSearchParams()
  const requestIdFromUrl = searchParams.get("request")
  
  const [chats, setChats] = useState<RequestChat[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedChat, setSelectedChat] = useState<RequestChat | null>(null)
  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState("")
  const [sending, setSending] = useState(false)
  const [shopId, setShopId] = useState<string | null>(null)
  const [userId, setUserId] = useState<string | null>(null)
  const [showJumpToTop, setShowJumpToTop] = useState(false)
  const [lightboxImage, setLightboxImage] = useState<string | null>(null)
  
  const messagesContainerRef = useRef<HTMLDivElement>(null)
  const pinnedOfferRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    loadChats()
  }, [])
  
  // Auto-select chat if request ID is in URL
  useEffect(() => {
    if (requestIdFromUrl && chats.length > 0 && !selectedChat) {
      const chatToSelect = chats.find(c => c.request_id === requestIdFromUrl)
      if (chatToSelect) {
        setSelectedChat(chatToSelect)
      }
    }
  }, [requestIdFromUrl, chats, selectedChat])

  useEffect(() => {
    if (selectedChat) {
      loadMessages(selectedChat.id)
    }
  }, [selectedChat])

  const loadChats = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        console.error("❌ No authenticated user found")
        return
      }

      console.log("👤 User ID:", user.id)
      setUserId(user.id)

      const { data: shop, error: shopError } = await supabase
        .from("shops")
        .select("id, name, owner_id")
        .eq("owner_id", user.id)
        .single()

      if (shopError) {
        console.error("❌ Error fetching shop:", shopError.message)
        return
      }
      
      if (!shop) {
        console.error("❌ No shop found for user:", user.id)
        return
      }
      
      console.log("🏪 Shop found:", shop.id, shop.name)
      setShopId(shop.id)

      // Get all request_chats for this shop with request, mechanic details, and offer
      const { data, error: chatsError } = await supabase
        .from("request_chats")
        .select(`
          *,
          part_requests:request_id(
            id, vehicle_make, vehicle_model, vehicle_year, 
            part_category, status, mechanic_id, image_url
          )
        `)
        .eq("shop_id", shop.id)
        .order("updated_at", { ascending: false })
      
      if (chatsError) {
        console.error("❌ Error fetching request_chats:", chatsError.message)
        console.error("❌ Error details:", chatsError)
      }
      
      console.log("💬 Request chats found:", data?.length || 0)
      if (data) {
        console.log("💬 Chat IDs:", data.map(c => c.id))
      }

      if (data) {
        // Fetch mechanic profiles, offers, and last message for each chat
        const chatsWithDetails = await Promise.all(
          data.map(async (chat) => {
            let enrichedChat: RequestChat = { ...chat }
            
            // Fetch mechanic profile
            if (chat.part_requests?.mechanic_id) {
              const { data: profile } = await supabase
                .from("profiles")
                .select("full_name, phone")
                .eq("id", chat.part_requests.mechanic_id)
                .single()
              enrichedChat.profiles = profile || undefined
            }
            
            // Fetch offer if quote was sent
            if (chat.status === "quoted" || chat.status === "accepted") {
              const { data: offer } = await supabase
                .from("offers")
                .select("id, price_cents, delivery_fee_cents, part_condition, warranty, message, status")
                .eq("request_id", chat.request_id)
                .eq("shop_id", shop.id)
                .single()
              if (offer) {
                enrichedChat.offers = offer
              }
            }
            
            // Fetch last message for WhatsApp-style display
            try {
              const { data: conversation } = await supabase
                .from("conversations")
                .select("id")
                .eq("request_id", chat.request_id)
                .eq("shop_id", shop.id)
                .single()
              
              if (conversation) {
                // Get last message
                const { data: lastMsg } = await supabase
                  .from("messages")
                  .select("text, sent_at, sender_id, is_read")
                  .eq("conversation_id", conversation.id)
                  .order("sent_at", { ascending: false })
                  .limit(1)
                  .single()
                
                if (lastMsg) {
                  enrichedChat.last_message_text = lastMsg.text
                  enrichedChat.last_message_at = lastMsg.sent_at
                  enrichedChat.last_message_is_mine = lastMsg.sender_id === user.id
                  enrichedChat.last_message_is_read = lastMsg.is_read || false
                }
                
                // Get unread count
                const { data: unreadMsgs } = await supabase
                  .from("messages")
                  .select("id")
                  .eq("conversation_id", conversation.id)
                  .neq("sender_id", user.id)
                  .eq("is_read", false)
                
                enrichedChat.unread_count = unreadMsgs?.length || 0
              }
            } catch (e) {
              console.log("No conversation yet for chat:", chat.id)
            }
            
            return enrichedChat
          })
        )
        
        // Sort by last message time (newest first)
        chatsWithDetails.sort((a, b) => {
          const aTime = a.last_message_at || a.updated_at
          const bTime = b.last_message_at || b.updated_at
          return new Date(bTime).getTime() - new Date(aTime).getTime()
        })
        
        setChats(chatsWithDetails)
      }
    } catch (error) {
      console.error("Error loading chats:", error)
    } finally {
      setLoading(false)
    }
  }

  const loadMessages = async (requestChatId: string) => {
    try {
      // Get or create conversation based on request_chat
      const chat = chats.find(c => c.id === requestChatId)
      if (!chat || !shopId) return

      const { data: conversation } = await supabase
        .from("conversations")
        .select("id")
        .eq("request_id", chat.request_id)
        .eq("shop_id", shopId)
        .single()

      if (conversation) {
        const { data: msgs } = await supabase
          .from("messages")
          .select("*")
          .eq("conversation_id", conversation.id)
          .order("sent_at", { ascending: true })

        if (msgs) setMessages(msgs)
      } else {
        setMessages([])
      }
    } catch (error) {
      console.error("Error loading messages:", error)
      setMessages([])
    }
  }

  const sendMessage = async () => {
    if (!newMessage.trim() || !selectedChat || !shopId || !userId) {
      console.error("❌ Missing required data:", { 
        hasMessage: !!newMessage.trim(), 
        hasSelectedChat: !!selectedChat, 
        shopId, 
        userId 
      })
      return
    }

    console.log("📤 Sending message...")
    console.log("📤 Request ID:", selectedChat.request_id)
    console.log("📤 Shop ID:", shopId)
    console.log("📤 User ID:", userId)
    console.log("📤 Mechanic ID:", selectedChat.part_requests?.mechanic_id)

    setSending(true)
    try {
      // Get or create conversation
      let conversationId: string

      const { data: existingConv, error: convError } = await supabase
        .from("conversations")
        .select("id")
        .eq("request_id", selectedChat.request_id)
        .eq("shop_id", shopId)
        .single()

      console.log("🔍 Existing conversation:", existingConv, "Error:", convError?.message)

      if (existingConv) {
        conversationId = existingConv.id
        console.log("✅ Using existing conversation:", conversationId)
      } else {
        console.log("📝 Creating new conversation...")
        const { data: newConv, error } = await supabase
          .from("conversations")
          .insert({
            request_id: selectedChat.request_id,
            mechanic_id: selectedChat.part_requests?.mechanic_id,
            shop_id: shopId
          })
          .select()
          .single()

        if (error) {
          console.error("❌ Error creating conversation:", error.message)
          console.error("❌ Error details:", error)
          throw error
        }
        if (!newConv) {
          console.error("❌ No conversation returned after insert")
          throw new Error("Failed to create conversation")
        }
        conversationId = newConv.id
        console.log("✅ Created new conversation:", conversationId)
      }

      // Send the message
      console.log("📤 Inserting message into conversation:", conversationId)
      const { error: msgError } = await supabase
        .from("messages")
        .insert({
          conversation_id: conversationId,
          sender_id: userId,
          text: newMessage.trim()
        })

      if (msgError) {
        console.error("❌ Error inserting message:", msgError.message)
        console.error("❌ Message error details:", msgError)
        throw msgError
      }

      console.log("✅ Message sent successfully!")
      setNewMessage("")
      loadMessages(selectedChat.id)
    } catch (error) {
      console.error("❌ Error sending message:", error)
    } finally {
      setSending(false)
    }
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString("en-ZA", { 
      day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" 
    })
  }

  const formatPrice = (cents: number | null) => {
    if (!cents) return "—"
    return `R ${(cents / 100).toFixed(2)}`
  }

  // Handle scroll to show/hide jump-to-top button
  const handleScroll = () => {
    if (messagesContainerRef.current) {
      const scrollTop = messagesContainerRef.current.scrollTop
      setShowJumpToTop(scrollTop > 200)
    }
  }

  // Jump to top (to see pinned offer)
  const jumpToTop = () => {
    if (pinnedOfferRef.current) {
      pinnedOfferRef.current.scrollIntoView({ behavior: "smooth" })
    } else if (messagesContainerRef.current) {
      messagesContainerRef.current.scrollTo({ top: 0, behavior: "smooth" })
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "pending": return "bg-yellow-500/20 text-yellow-400"
      case "quoted": return "bg-blue-500/20 text-blue-400"
      case "accepted": return "bg-green-500/20 text-green-400"
      case "rejected": return "bg-red-500/20 text-red-400"
      default: return "bg-gray-500/20 text-gray-400"
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
    <div className="flex h-[calc(100vh-140px)] bg-[#0a0a0a] rounded-xl overflow-hidden border border-gray-800">
      {/* Chat List */}
      <div className={`w-full md:w-96 border-r border-gray-800 flex flex-col ${selectedChat ? 'hidden md:flex' : 'flex'}`}>
        <div className="p-4 border-b border-gray-800">
          <h2 className="text-lg font-semibold text-white">Conversations</h2>
          <p className="text-sm text-gray-400">{chats.length} chat{chats.length !== 1 ? 's' : ''}</p>
        </div>

        <div className="flex-1 overflow-y-auto">
          {chats.length === 0 ? (
            <div className="p-8 text-center">
              <MessageSquare className="w-12 h-12 text-gray-600 mx-auto mb-3" />
              <p className="text-gray-400">No conversations yet</p>
              <p className="text-sm text-gray-500">Chats will appear when you receive part requests</p>
            </div>
          ) : (
            chats.map((chat) => {
              const hasUnread = (chat.unread_count || 0) > 0
              const messagePreview = chat.last_message_text 
                ? (chat.last_message_text.length > 35 
                    ? chat.last_message_text.substring(0, 35) + "..." 
                    : chat.last_message_text)
                : "No messages yet"
              
              // Format timestamp for WhatsApp style
              const formatTimestamp = (dateStr: string | null | undefined) => {
                if (!dateStr) return ""
                const date = new Date(dateStr)
                const now = new Date()
                const isToday = date.toDateString() === now.toDateString()
                const yesterday = new Date(now)
                yesterday.setDate(yesterday.getDate() - 1)
                const isYesterday = date.toDateString() === yesterday.toDateString()
                
                if (isToday) {
                  return date.toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" })
                } else if (isYesterday) {
                  return "Yesterday"
                } else {
                  return date.toLocaleDateString("en-ZA", { day: "numeric", month: "short" })
                }
              }
              
              return (
                <div
                  key={chat.id}
                  onClick={() => setSelectedChat(chat)}
                  className={`p-4 border-b border-gray-800 cursor-pointer hover:bg-[#1a1a1a] transition-colors ${
                    selectedChat?.id === chat.id ? 'bg-[#1a1a1a]' : ''
                  }`}
                >
                  <div className="flex items-center gap-3">
                    {/* Avatar */}
                    <div className="w-12 h-12 bg-accent/20 rounded-full flex items-center justify-center flex-shrink-0">
                      <User className="w-6 h-6 text-accent" />
                    </div>
                    
                    {/* Middle: Name + Message Preview */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <p className={`font-medium truncate ${hasUnread ? 'text-white' : 'text-gray-200'}`}>
                          {chat.profiles?.full_name || "Mechanic"}
                        </p>
                        {/* Timestamp */}
                        <span className={`text-xs flex-shrink-0 ml-2 ${hasUnread ? 'text-green-400 font-semibold' : 'text-gray-500'}`}>
                          {formatTimestamp(chat.last_message_at || chat.updated_at)}
                        </span>
                      </div>
                      
                      {/* Message preview with status ticks */}
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-1 min-w-0 flex-1">
                          {/* Status ticks for own messages */}
                          {chat.last_message_is_mine && (
                            <CheckCheck 
                              className={`w-4 h-4 flex-shrink-0 ${
                                chat.last_message_is_read ? 'text-blue-400' : 'text-gray-500'
                              }`} 
                            />
                          )}
                          <p className={`text-sm truncate ${hasUnread ? 'text-white font-medium' : 'text-gray-400'}`}>
                            {messagePreview}
                          </p>
                        </div>
                        
                        {/* Unread badge */}
                        {hasUnread && (
                          <span className="bg-green-500 text-white text-xs font-bold px-2 py-0.5 rounded-full ml-2 flex-shrink-0">
                            {chat.unread_count! > 99 ? "99+" : chat.unread_count}
                          </span>
                        )}
                      </div>
                      
                      {/* Vehicle + Part info - smaller secondary line */}
                      <p className="text-xs text-gray-500 mt-1 truncate">
                        {chat.part_requests?.part_category} • {chat.part_requests?.vehicle_make} {chat.part_requests?.vehicle_model}
                      </p>
                    </div>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>

      {/* Chat Detail / Messages */}
      <div className={`flex-1 flex flex-col relative ${selectedChat ? 'flex' : 'hidden md:flex'}`}>
        {selectedChat ? (
          <>
            {/* Chat Header - Back button only */}
            <div className="p-4 border-b border-gray-800 bg-[#1a1a1a] flex items-center gap-3">
              <button 
                onClick={() => setSelectedChat(null)}
                className="md:hidden text-gray-400 hover:text-white"
              >
                ← Back
              </button>
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 bg-accent/20 rounded-full flex items-center justify-center">
                  <User className="w-4 h-4 text-accent" />
                </div>
                <div>
                  <p className="font-medium text-white">{selectedChat.profiles?.full_name || "Mechanic"}</p>
                  <p className="text-xs text-gray-400">
                    {selectedChat.part_requests?.vehicle_year} {selectedChat.part_requests?.vehicle_make} {selectedChat.part_requests?.vehicle_model}
                  </p>
                </div>
              </div>
            </div>

            {/* Scrollable area with Pinned Offer + Messages */}
            <div 
              ref={messagesContainerRef}
              onScroll={handleScroll}
              className="flex-1 overflow-y-auto"
            >
              {/* REQUEST CARD - Scrolls with messages */}
              <div ref={pinnedOfferRef} className="p-4">
                <div className="bg-gradient-to-r from-[#1a1a1a] to-[#2d2d2d] rounded-xl border border-gray-700 overflow-hidden">
                  {/* Image + Request Info Row */}
                  <div className="p-4 flex gap-4">
                    {/* Part Image */}
                    {selectedChat.part_requests?.image_url ? (
                      <div 
                        onClick={() => setLightboxImage(selectedChat.part_requests!.image_url!)}
                        className="relative w-20 h-20 rounded-lg overflow-hidden cursor-pointer group flex-shrink-0"
                      >
                        <img 
                          src={selectedChat.part_requests.image_url} 
                          alt="Part"
                          className="w-full h-full object-cover"
                        />
                        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                          <ZoomIn className="w-5 h-5 text-white" />
                        </div>
                      </div>
                    ) : (
                      <div className="w-20 h-20 bg-[#2d2d2d] rounded-lg flex items-center justify-center flex-shrink-0">
                        <ImageIcon className="w-8 h-8 text-gray-600" />
                      </div>
                    )}

                    {/* Request Details */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between mb-1">
                        <h3 className="font-semibold text-white">
                          {selectedChat.part_requests?.part_category}
                        </h3>
                        <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(selectedChat.status)}`}>
                          {selectedChat.status}
                        </span>
                      </div>
                      <p className="text-sm text-gray-400 mb-1">
                        {selectedChat.part_requests?.vehicle_year} {selectedChat.part_requests?.vehicle_make} {selectedChat.part_requests?.vehicle_model}
                      </p>
                    </div>
                  </div>

                  {/* Quote/Offer Details - Only show if quoted */}
                  {(selectedChat.status === "quoted" || selectedChat.status === "accepted") && selectedChat.offers && (
                    <div className="px-4 pb-4">
                      <div className="bg-[#1a1a1a] rounded-lg p-3 border border-accent/30">
                        <div className="flex items-center gap-2 mb-3">
                          <Tag className="w-4 h-4 text-accent" />
                          <span className="text-sm font-medium text-accent">Your Quote</span>
                        </div>
                        
                        <div className="grid grid-cols-3 gap-3 text-sm">
                          <div>
                            <p className="text-gray-500 text-xs">Part Price</p>
                            <p className="text-white font-medium">{formatPrice(selectedChat.offers.price_cents)}</p>
                          </div>
                          <div>
                            <p className="text-gray-500 text-xs">Delivery</p>
                            <p className="text-white font-medium">{formatPrice(selectedChat.offers.delivery_fee_cents)}</p>
                          </div>
                          <div>
                            <p className="text-gray-500 text-xs">Total</p>
                            <p className="text-accent font-bold">
                              {formatPrice((selectedChat.offers.price_cents || 0) + (selectedChat.offers.delivery_fee_cents || 0))}
                            </p>
                          </div>
                        </div>

                        {/* Additional offer details */}
                        <div className="flex items-center gap-4 mt-3 pt-3 border-t border-gray-700 text-xs">
                          {selectedChat.offers.part_condition && (
                            <span className="flex items-center gap-1 text-gray-400">
                              <Package className="w-3 h-3" />
                              {selectedChat.offers.part_condition}
                            </span>
                          )}
                          {selectedChat.offers.warranty && (
                            <span className="flex items-center gap-1 text-gray-400">
                              <Truck className="w-3 h-3" />
                              {selectedChat.offers.warranty} warranty
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Awaiting Quote State */}
                  {selectedChat.status === "pending" && (
                    <div className="px-4 pb-4">
                      <div className="bg-yellow-500/10 rounded-lg p-3 border border-yellow-500/30 text-center">
                        <p className="text-yellow-400 text-sm">Awaiting your quote</p>
                        <p className="text-gray-500 text-xs mt-1">Send a quote from the Requests page</p>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Messages */}
              <div className="p-4 space-y-4">
              {messages.length === 0 ? (
                <div className="text-center py-12">
                  <MessageSquare className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                  <p className="text-gray-400">No messages yet</p>
                  <p className="text-sm text-gray-500">Start the conversation with the mechanic</p>
                </div>
              ) : (
                messages.map((msg) => (
                  <div
                    key={msg.id}
                    className={`flex ${msg.sender_id === userId ? 'justify-end' : 'justify-start'}`}
                  >
                    <div
                      className={`max-w-[70%] rounded-lg px-4 py-2 ${
                        msg.sender_id === userId
                          ? 'bg-accent text-white'
                          : 'bg-[#2d2d2d] text-white'
                      }`}
                    >
                      <p>{msg.text}</p>
                      <p className={`text-xs mt-1 ${msg.sender_id === userId ? 'text-white/70' : 'text-gray-500'}`}>
                        {formatDate(msg.sent_at)}
                      </p>
                    </div>
                  </div>
                ))
              )}
              </div>
            </div>

            {/* Jump to Top Button - Shows when scrolled down */}
            {showJumpToTop && (
              <button
                onClick={jumpToTop}
                className="absolute bottom-24 right-8 bg-accent hover:bg-accent-hover text-white p-3 rounded-full shadow-lg transition-all transform hover:scale-105 z-20"
                title="Jump to offer"
              >
                <ArrowUp className="w-5 h-5" />
              </button>
            )}

            {/* Message Input */}
            <div className="p-4 border-t border-gray-800 bg-[#0a0a0a]">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
                  placeholder="Type a message..."
                  className="flex-1 bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
                <button
                  onClick={sendMessage}
                  disabled={!newMessage.trim() || sending}
                  className="px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50"
                >
                  <Send className="w-5 h-5" />
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <MessageSquare className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-white mb-2">Select a conversation</h3>
              <p className="text-gray-400">Choose a chat from the list to view messages</p>
            </div>
          </div>
        )}
      </div>

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
