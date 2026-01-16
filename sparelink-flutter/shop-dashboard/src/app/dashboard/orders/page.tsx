"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { Package, Truck, CheckCircle, Clock, MapPin, User, Wrench, RefreshCw, Bell } from "lucide-react"

interface Order {
  id: string
  status: string
  total_cents: number
  total_amount?: number // legacy field
  created_at: string
  delivery_destination: 'user' | 'mechanic' | null
  delivery_address: string | null
  part_requests?: { 
    vehicle_make: string
    vehicle_model: string
    part_category: string
    mechanic_id: string
    profiles?: { full_name: string; phone: string }
  }
  offers?: { shops: { name: string } }
}

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState("all")
  const [shopId, setShopId] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [newOrderAlert, setNewOrderAlert] = useState(false)

  useEffect(() => {
    loadOrders()
  }, [])

  // Set up real-time subscription for new orders when shopId is available
  useEffect(() => {
    if (!shopId) return

    // Subscribe to changes on orders table (via offers with this shop_id)
    const channel = supabase
      .channel('shop-orders-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'orders'
        },
        (payload) => {
          console.log('New order detected:', payload)
          // Show alert and reload orders
          setNewOrderAlert(true)
          loadOrders()
          // Auto-hide alert after 5 seconds
          setTimeout(() => setNewOrderAlert(false), 5000)
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'orders'
        },
        (payload) => {
          console.log('Order updated:', payload)
          loadOrders()
        }
      )
      .subscribe()

    // Cleanup subscription on unmount
    return () => {
      supabase.removeChannel(channel)
    }
  }, [shopId])

  const loadOrders = async () => {
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

      // Get orders through the offers table (offers have shop_id)
      const { data } = await supabase
        .from("orders")
        .select(`
          *,
          offers!inner(
            shop_id,
            shops(name)
          ),
          part_requests(
            vehicle_make,
            vehicle_model,
            part_category,
            mechanic_id,
            profiles(full_name, phone)
          )
        `)
        .eq("offers.shop_id", shop.id)
        .order("created_at", { ascending: false })

      if (data) setOrders(data)
      setLastUpdated(new Date())
    } catch (error) {
      console.error("Error loading orders:", error)
    } finally {
      setLoading(false)
    }
  }

  const updateOrderStatus = async (orderId: string, newStatus: string) => {
    try {
      await supabase
        .from("orders")
        .update({ status: newStatus })
        .eq("id", orderId)

      setOrders(orders.map(o => o.id === orderId ? { ...o, status: newStatus } : o))
    } catch (error) {
      console.error("Error updating order:", error)
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "delivered": return <CheckCircle className="w-5 h-5 text-green-400" />
      case "shipped": return <Truck className="w-5 h-5 text-blue-400" />
      case "processing": return <Package className="w-5 h-5 text-yellow-400" />
      default: return <Clock className="w-5 h-5 text-gray-400" />
    }
  }

  const statusOptions = ["pending", "processing", "shipped", "delivered"]
  const filteredOrders = filter === "all" ? orders : orders.filter(o => o.status === filter)

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* New Order Alert */}
      {newOrderAlert && (
        <div className="bg-green-500/20 border border-green-500/50 rounded-xl p-4 flex items-center gap-3 animate-pulse">
          <Bell className="w-6 h-6 text-green-400" />
          <div className="flex-1">
            <p className="text-green-400 font-semibold">New Order Received!</p>
            <p className="text-green-300 text-sm">A mechanic has accepted your quote</p>
          </div>
          <button 
            onClick={() => setNewOrderAlert(false)}
            className="text-green-400 hover:text-green-300"
          >
            ✕
          </button>
        </div>
      )}

      {/* Filter Tabs and Refresh */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div className="flex gap-2 flex-wrap">
          {["all", ...statusOptions].map((f) => (
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
            onClick={() => loadOrders()}
            className="p-2 bg-[#1a1a1a] border border-gray-800 rounded-lg hover:border-gray-700 transition-colors"
            title="Refresh orders"
          >
            <RefreshCw className={`w-5 h-5 text-gray-400 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Orders List */}
      {filteredOrders.length === 0 ? (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-12 text-center">
          <Package className="w-16 h-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-white mb-2">No Orders</h3>
          <p className="text-gray-400">Orders will appear when mechanics accept your quotes</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {filteredOrders.map((order) => (
            <div key={order.id} className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  {getStatusIcon(order.status)}
                  <div>
                    <h3 className="text-lg font-semibold text-white">Order #{order.id.slice(0, 8)}</h3>
                    <p className="text-gray-400 text-sm">
                      {new Date(order.created_at).toLocaleDateString()}
                    </p>
                    {order.part_requests && (
                      <p className="text-gray-500 text-sm">
                        {order.part_requests.vehicle_make} {order.part_requests.vehicle_model} - {order.part_requests.part_category}
                      </p>
                    )}
                  </div>
                </div>
                <p className="text-xl font-bold text-accent">R{((order.total_cents || 0) / 100).toLocaleString()}</p>
              </div>

              {/* Delivery Destination */}
              <div className="flex items-center gap-4 mb-4 p-3 bg-[#2d2d2d] rounded-lg">
                <div className="flex items-center gap-2">
                  {order.delivery_destination === 'mechanic' ? (
                    <Wrench className="w-4 h-4 text-accent" />
                  ) : (
                    <User className="w-4 h-4 text-accent" />
                  )}
                  <span className="text-sm text-gray-300">
                    {order.delivery_destination === 'mechanic' ? 'Deliver to Mechanic' : 'Deliver to Customer'}
                  </span>
                </div>
                {order.delivery_address && (
                  <div className="flex items-center gap-2 text-gray-400">
                    <MapPin className="w-4 h-4" />
                    <span className="text-sm">{order.delivery_address}</span>
                  </div>
                )}
              </div>

              {/* Customer Info */}
              {order.part_requests?.profiles && (
                <div className="mb-4 text-sm text-gray-400">
                  <span className="text-gray-500">Customer:</span>{" "}
                  {order.part_requests.profiles.full_name} • {order.part_requests.profiles.phone}
                </div>
              )}

              <div className="pt-4 border-t border-gray-800 flex items-center justify-between">
                <span className="text-sm text-gray-400">Update Status:</span>
                <div className="flex gap-2">
                  {statusOptions.map((status) => (
                    <button
                      key={status}
                      onClick={() => updateOrderStatus(order.id, status)}
                      className={`px-3 py-1.5 rounded-lg text-sm capitalize transition-colors ${
                        order.status === status
                          ? "bg-accent text-white"
                          : "bg-[#2d2d2d] text-gray-400 hover:text-white"
                      }`}
                    >
                      {status}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
