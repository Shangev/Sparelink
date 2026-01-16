"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { MessageSquare, Clock, Car, User, ChevronRight, Send } from "lucide-react"

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
    part_description: string
    status: string
    mechanic_id: string
  }
  profiles?: {
    full_name: string
    phone: string
  }
}

interface Message {
  id: string
  conversation_id: string
  sender_id: string
  text: string
  sent_at: string
}

export default function ChatsPage() {
  const [chats, setChats] = useState<RequestChat[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedChat, setSelectedChat] = useState<RequestChat | null>(null)
  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState("")
  const [sending, setSending] = useState(false)
  const [shopId, setShopId] = useState<string | null>(null)
  const [userId, setUserId] = useState<string | null>(null)

  useEffect(() => {
    loadChats()
  }, [])

  useEffect(() => {
    if (selectedChat) {
      loadMessages(selectedChat.id)
    }
  }, [selectedChat])

  const loadChats = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      setUserId(user.id)

      const { data: shop } = await supabase
        .from("shops")
        .select("id")
        .eq("owner_id", user.id)
        .single()

      if (!shop) return
      setShopId(shop.id)

      // Get all request_chats for this shop with request and mechanic details
      const { data } = await supabase
        .from("request_chats")
        .select(`
          *,
          part_requests:request_id(
            id, vehicle_make, vehicle_model, vehicle_year, 
            part_category, part_description, status, mechanic_id
          )
        `)
        .eq("shop_id", shop.id)
        .order("updated_at", { ascending: false })

      if (data) {
        // Fetch mechanic profiles for each chat
        const chatsWithProfiles = await Promise.all(
          data.map(async (chat) => {
            if (chat.part_requests?.mechanic_id) {
              const { data: profile } = await supabase
                .from("profiles")
                .select("full_name, phone")
                .eq("id", chat.part_requests.mechanic_id)
                .single()
              return { ...chat, profiles: profile }
            }
            return chat
          })
        )
        setChats(chatsWithProfiles)
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
    if (!newMessage.trim() || !selectedChat || !shopId || !userId) return

    setSending(true)
    try {
      // Get or create conversation
      let conversationId: string

      const { data: existingConv } = await supabase
        .from("conversations")
        .select("id")
        .eq("request_id", selectedChat.request_id)
        .eq("shop_id", shopId)
        .single()

      if (existingConv) {
        conversationId = existingConv.id
      } else {
        const { data: newConv, error } = await supabase
          .from("conversations")
          .insert({
            request_id: selectedChat.request_id,
            mechanic_id: selectedChat.part_requests?.mechanic_id,
            shop_id: shopId
          })
          .select()
          .single()

        if (error || !newConv) throw error
        conversationId = newConv.id
      }

      // Send the message
      const { error: msgError } = await supabase
        .from("messages")
        .insert({
          conversation_id: conversationId,
          sender_id: userId,
          text: newMessage.trim()
        })

      if (msgError) throw msgError

      setNewMessage("")
      loadMessages(selectedChat.id)
    } catch (error) {
      console.error("Error sending message:", error)
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
            chats.map((chat) => (
              <div
                key={chat.id}
                onClick={() => setSelectedChat(chat)}
                className={`p-4 border-b border-gray-800 cursor-pointer hover:bg-[#1a1a1a] transition-colors ${
                  selectedChat?.id === chat.id ? 'bg-[#1a1a1a]' : ''
                }`}
              >
                <div className="flex items-start justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <div className="w-10 h-10 bg-accent/20 rounded-full flex items-center justify-center">
                      <User className="w-5 h-5 text-accent" />
                    </div>
                    <div>
                      <p className="font-medium text-white">
                        {chat.profiles?.full_name || "Mechanic"}
                      </p>
                      <p className="text-xs text-gray-400">
                        {chat.part_requests?.vehicle_year} {chat.part_requests?.vehicle_make} {chat.part_requests?.vehicle_model}
                      </p>
                    </div>
                  </div>
                  <ChevronRight className="w-5 h-5 text-gray-500" />
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-400">{chat.part_requests?.part_category}</span>
                  <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(chat.status)}`}>
                    {chat.status}
                  </span>
                </div>

                {chat.quote_amount && (
                  <p className="text-sm text-accent mt-1">
                    Quoted: {formatPrice(chat.quote_amount)}
                  </p>
                )}

                <p className="text-xs text-gray-500 mt-2">
                  <Clock className="w-3 h-3 inline mr-1" />
                  {formatDate(chat.updated_at)}
                </p>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Chat Detail / Messages */}
      <div className={`flex-1 flex flex-col ${selectedChat ? 'flex' : 'hidden md:flex'}`}>
        {selectedChat ? (
          <>
            {/* Chat Header with Request Details */}
            <div className="p-4 border-b border-gray-800 bg-[#1a1a1a]">
              <button 
                onClick={() => setSelectedChat(null)}
                className="md:hidden text-gray-400 mb-2"
              >
                ← Back
              </button>
              
              {/* Request Summary Card */}
              <div className="bg-[#2d2d2d] rounded-lg p-4">
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-10 h-10 bg-accent/20 rounded-lg flex items-center justify-center">
                    <Car className="w-5 h-5 text-accent" />
                  </div>
                  <div>
                    <h3 className="font-semibold text-white">
                      {selectedChat.part_requests?.vehicle_year} {selectedChat.part_requests?.vehicle_make} {selectedChat.part_requests?.vehicle_model}
                    </h3>
                    <p className="text-sm text-gray-400">{selectedChat.part_requests?.part_category}</p>
                  </div>
                  <span className={`ml-auto text-xs px-3 py-1 rounded-full ${getStatusColor(selectedChat.status)}`}>
                    {selectedChat.status}
                  </span>
                </div>

                {selectedChat.part_requests?.part_description && (
                  <p className="text-sm text-gray-300 mb-3">{selectedChat.part_requests.part_description}</p>
                )}

                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-400">
                    <User className="w-4 h-4 inline mr-1" />
                    {selectedChat.profiles?.full_name || "Mechanic"}
                  </span>
                  {selectedChat.quote_amount && (
                    <span className="text-accent font-medium">
                      Quote: {formatPrice(selectedChat.quote_amount)} + {formatPrice(selectedChat.delivery_fee)} delivery
                    </span>
                  )}
                </div>
              </div>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
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

            {/* Message Input */}
            <div className="p-4 border-t border-gray-800">
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
    </div>
  )
}
