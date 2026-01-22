"use client"

import { useEffect, useState, useRef } from "react"
import { supabase } from "@/lib/supabase"
import { Package, Truck, CheckCircle, Clock, MapPin, User, Wrench, RefreshCw, Bell, Printer, Hash, UserCheck, CheckSquare, Square, X, Save, ChevronDown, FileText, AlertCircle } from "lucide-react"

interface Order {
  id: string
  status: string
  total_cents: number
  total_amount?: number // legacy field
  created_at: string
  delivery_destination: 'user' | 'mechanic' | null
  delivery_address: string | null
  tracking_number?: string | null
  assigned_driver?: string | null
  part_requests?: { 
    vehicle_make: string
    vehicle_model: string
    part_category: string
    mechanic_id: string
    profiles?: { full_name: string; phone: string }
  }
  offers?: { shops: { name: string } }
}

interface Driver {
  id: string
  name: string
  type: 'internal' | 'external'
  phone?: string
}

// Pre-configured drivers (in real app, would come from database)
const AVAILABLE_DRIVERS: Driver[] = [
  { id: 'driver1', name: 'John Mokoena', type: 'internal', phone: '082 123 4567' },
  { id: 'driver2', name: 'Thabo Nkosi', type: 'internal', phone: '083 234 5678' },
  { id: 'driver3', name: 'Sipho Dlamini', type: 'internal', phone: '084 345 6789' },
  { id: 'courier1', name: 'The Courier Guy', type: 'external' },
  { id: 'courier2', name: 'RAM Hand-to-Hand', type: 'external' },
  { id: 'courier3', name: 'Fastway Couriers', type: 'external' },
]

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState("all")
  const [shopId, setShopId] = useState<string | null>(null)
  const [shopName, setShopName] = useState<string>("")
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [newOrderAlert, setNewOrderAlert] = useState(false)
  
  // New state for features
  const [selectedOrders, setSelectedOrders] = useState<Set<string>>(new Set())
  const [showLabelModal, setShowLabelModal] = useState(false)
  const [labelOrder, setLabelOrder] = useState<Order | null>(null)
  const [showTrackingModal, setShowTrackingModal] = useState(false)
  const [trackingOrder, setTrackingOrder] = useState<Order | null>(null)
  const [trackingNumber, setTrackingNumber] = useState("")
  const [showDriverModal, setShowDriverModal] = useState(false)
  const [driverOrder, setDriverOrder] = useState<Order | null>(null)
  const [selectedDriver, setSelectedDriver] = useState<string>("")
  const [batchUpdating, setBatchUpdating] = useState(false)
  const labelRef = useRef<HTMLDivElement>(null)

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
        .select("id, name")
        .eq("owner_id", user.id)
        .single()

      if (!shop) return

      // Save shopId and name for real-time subscription
      if (!shopId) {
        setShopId(shop.id)
        setShopName(shop.name || "My Shop")
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

  // Toggle selection for batch actions
  const toggleSelection = (orderId: string) => {
    setSelectedOrders(prev => {
      const newSet = new Set(prev)
      if (newSet.has(orderId)) {
        newSet.delete(orderId)
      } else {
        newSet.add(orderId)
      }
      return newSet
    })
  }

  // Select/deselect all visible orders
  const toggleSelectAll = () => {
    if (selectedOrders.size === filteredOrders.length) {
      setSelectedOrders(new Set())
    } else {
      setSelectedOrders(new Set(filteredOrders.map(o => o.id)))
    }
  }

  // Batch update order status
  const handleBatchStatusUpdate = async (newStatus: string) => {
    if (selectedOrders.size === 0) return
    
    setBatchUpdating(true)
    try {
      // Update all selected orders
      for (const orderId of selectedOrders) {
        await supabase
          .from("orders")
          .update({ status: newStatus })
          .eq("id", orderId)
      }

      // Update local state
      setOrders(orders.map(o => 
        selectedOrders.has(o.id) ? { ...o, status: newStatus } : o
      ))
      setSelectedOrders(new Set())
    } catch (error) {
      console.error("Error batch updating orders:", error)
      alert("Failed to update some orders")
    } finally {
      setBatchUpdating(false)
    }
  }

  // Save tracking number
  const handleSaveTracking = async () => {
    if (!trackingOrder || !trackingNumber.trim()) return

    try {
      await supabase
        .from("orders")
        .update({ 
          tracking_number: trackingNumber.trim(),
          status: trackingOrder.status === 'processing' ? 'shipped' : trackingOrder.status
        })
        .eq("id", trackingOrder.id)

      setOrders(orders.map(o => 
        o.id === trackingOrder.id 
          ? { ...o, tracking_number: trackingNumber.trim(), status: o.status === 'processing' ? 'shipped' : o.status } 
          : o
      ))
      setShowTrackingModal(false)
      setTrackingOrder(null)
      setTrackingNumber("")
    } catch (error) {
      console.error("Error saving tracking:", error)
      alert("Failed to save tracking number")
    }
  }

  // Assign driver to order
  const handleAssignDriver = async () => {
    if (!driverOrder || !selectedDriver) return

    try {
      await supabase
        .from("orders")
        .update({ assigned_driver: selectedDriver })
        .eq("id", driverOrder.id)

      setOrders(orders.map(o => 
        o.id === driverOrder.id ? { ...o, assigned_driver: selectedDriver } : o
      ))
      setShowDriverModal(false)
      setDriverOrder(null)
      setSelectedDriver("")
    } catch (error) {
      console.error("Error assigning driver:", error)
      alert("Failed to assign driver")
    }
  }

  // Generate and print shipping label
  const handlePrintLabel = () => {
    if (!labelRef.current) return
    
    const printContent = labelRef.current.innerHTML
    const printWindow = window.open('', '_blank', 'width=400,height=600')
    if (!printWindow) {
      alert("Please allow pop-ups to print labels")
      return
    }

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Shipping Label - Order #${labelOrder?.id.slice(0, 8)}</title>
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: Arial, sans-serif; padding: 20px; }
            .label { border: 3px solid #000; padding: 20px; max-width: 400px; }
            .header { border-bottom: 2px solid #000; padding-bottom: 15px; margin-bottom: 15px; }
            .shop-name { font-size: 24px; font-weight: bold; }
            .order-id { font-size: 14px; color: #666; margin-top: 5px; }
            .section { margin-bottom: 15px; }
            .section-title { font-size: 12px; color: #666; text-transform: uppercase; margin-bottom: 5px; }
            .section-content { font-size: 16px; font-weight: 500; }
            .address { font-size: 18px; font-weight: bold; line-height: 1.4; }
            .barcode { text-align: center; margin: 20px 0; padding: 15px; background: #f0f0f0; }
            .barcode-text { font-family: monospace; font-size: 20px; letter-spacing: 3px; }
            .footer { border-top: 2px solid #000; padding-top: 15px; margin-top: 15px; font-size: 12px; }
            .part-info { background: #f5f5f5; padding: 10px; margin: 10px 0; }
            @media print {
              body { padding: 0; }
              .label { border-width: 2px; }
            }
          </style>
        </head>
        <body>
          ${printContent}
          <script>
            window.onload = function() { window.print(); window.close(); }
          </script>
        </body>
      </html>
    `)
    printWindow.document.close()
  }

  // Get driver name by ID
  const getDriverName = (driverId: string | null | undefined) => {
    if (!driverId) return null
    const driver = AVAILABLE_DRIVERS.find(d => d.id === driverId)
    return driver?.name || driverId
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

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Orders</h1>
          <p className="text-gray-400 text-sm">
            {filteredOrders.length} order{filteredOrders.length !== 1 ? 's' : ''}
            {selectedOrders.size > 0 && ` • ${selectedOrders.size} selected`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          {lastUpdated && (
            <span className="text-gray-500 text-sm hidden md:block">
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

      {/* Filter Tabs */}
      <div className="flex gap-2 flex-wrap">
        {["all", ...statusOptions].map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-lg font-medium capitalize transition-colors ${
              filter === f ? "bg-accent text-white" : "bg-[#1a1a1a] text-gray-400 hover:text-white"
            }`}
          >
            {f} {f !== "all" && `(${orders.filter(o => o.status === f).length})`}
          </button>
        ))}
      </div>

      {/* Batch Actions Toolbar */}
      {selectedOrders.size > 0 && (
        <div className="bg-accent/10 border border-accent/30 rounded-xl p-4 flex items-center justify-between flex-wrap gap-4">
          <div className="flex items-center gap-3">
            <button
              onClick={toggleSelectAll}
              className="text-accent hover:text-accent-hover transition-colors"
            >
              {selectedOrders.size === filteredOrders.length ? (
                <CheckSquare className="w-5 h-5" />
              ) : (
                <Square className="w-5 h-5" />
              )}
            </button>
            <span className="text-white font-medium">{selectedOrders.size} selected</span>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-gray-400 text-sm">Batch update to:</span>
            {statusOptions.map((status) => (
              <button
                key={status}
                onClick={() => handleBatchStatusUpdate(status)}
                disabled={batchUpdating}
                className="px-3 py-1.5 bg-[#2d2d2d] hover:bg-[#3d3d3d] text-white rounded-lg text-sm capitalize transition-colors disabled:opacity-50"
              >
                {batchUpdating ? "..." : status}
              </button>
            ))}
            <button
              onClick={() => setSelectedOrders(new Set())}
              className="px-3 py-1.5 bg-red-500/20 hover:bg-red-500/30 text-red-400 rounded-lg text-sm transition-colors"
            >
              Clear
            </button>
          </div>
        </div>
      )}

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
            <div 
              key={order.id} 
              className={`bg-[#1a1a1a] rounded-xl border p-6 transition-colors ${
                selectedOrders.has(order.id) ? 'border-accent' : 'border-gray-800'
              }`}
            >
              <div className="flex items-start gap-4 mb-4">
                {/* Checkbox */}
                <button
                  onClick={() => toggleSelection(order.id)}
                  className="flex-shrink-0 mt-1"
                >
                  {selectedOrders.has(order.id) ? (
                    <CheckSquare className="w-5 h-5 text-accent" />
                  ) : (
                    <Square className="w-5 h-5 text-gray-600 hover:text-gray-400" />
                  )}
                </button>

                <div className="flex-1">
                  <div className="flex items-start justify-between">
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
                </div>
              </div>

              {/* Tracking & Driver Info */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
                {/* Tracking Number */}
                <div className="p-3 bg-[#2d2d2d] rounded-lg">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Hash className="w-4 h-4 text-blue-400" />
                      <span className="text-sm text-gray-400">Tracking:</span>
                      {order.tracking_number ? (
                        <span className="text-white font-mono text-sm">{order.tracking_number}</span>
                      ) : (
                        <span className="text-gray-500 text-sm">Not set</span>
                      )}
                    </div>
                    <button
                      onClick={() => { setTrackingOrder(order); setTrackingNumber(order.tracking_number || ""); setShowTrackingModal(true); }}
                      className="text-xs text-accent hover:text-accent-hover"
                    >
                      {order.tracking_number ? "Edit" : "Add"}
                    </button>
                  </div>
                </div>

                {/* Assigned Driver */}
                <div className="p-3 bg-[#2d2d2d] rounded-lg">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <UserCheck className="w-4 h-4 text-green-400" />
                      <span className="text-sm text-gray-400">Driver:</span>
                      {order.assigned_driver ? (
                        <span className="text-white text-sm">{getDriverName(order.assigned_driver)}</span>
                      ) : (
                        <span className="text-gray-500 text-sm">Unassigned</span>
                      )}
                    </div>
                    <button
                      onClick={() => { setDriverOrder(order); setSelectedDriver(order.assigned_driver || ""); setShowDriverModal(true); }}
                      className="text-xs text-accent hover:text-accent-hover"
                    >
                      {order.assigned_driver ? "Change" : "Assign"}
                    </button>
                  </div>
                </div>
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
                  <div className="flex items-center gap-2 text-gray-400 flex-1">
                    <MapPin className="w-4 h-4 flex-shrink-0" />
                    <span className="text-sm truncate">{order.delivery_address}</span>
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

              <div className="pt-4 border-t border-gray-800 flex items-center justify-between flex-wrap gap-4">
                {/* Action Buttons */}
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => { setLabelOrder(order); setShowLabelModal(true); }}
                    className="px-3 py-1.5 bg-blue-500/20 hover:bg-blue-500/30 text-blue-400 rounded-lg text-sm flex items-center gap-1 transition-colors"
                  >
                    <Printer className="w-4 h-4" />
                    Print Label
                  </button>
                </div>

                {/* Status Buttons */}
                <div className="flex gap-2 flex-wrap">
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

      {/* Tracking Number Modal */}
      {showTrackingModal && trackingOrder && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-md border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <div>
                <h3 className="text-xl font-semibold text-white">Add Tracking Number</h3>
                <p className="text-gray-400 text-sm">Order #{trackingOrder.id.slice(0, 8)}</p>
              </div>
              <button onClick={() => { setShowTrackingModal(false); setTrackingOrder(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Tracking Number</label>
                <input
                  type="text"
                  value={trackingNumber}
                  onChange={(e) => setTrackingNumber(e.target.value)}
                  placeholder="e.g., TCG123456789"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none font-mono"
                />
              </div>
              <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-3 flex items-start gap-2">
                <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <p className="text-blue-300 text-sm">Adding a tracking number will automatically update the order status to "Shipped" if it's currently "Processing".</p>
              </div>
            </div>
            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => { setShowTrackingModal(false); setTrackingOrder(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveTracking}
                disabled={!trackingNumber.trim()}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                <Save className="w-5 h-5" />
                Save Tracking
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Driver Assignment Modal */}
      {showDriverModal && driverOrder && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-md border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <div>
                <h3 className="text-xl font-semibold text-white">Assign Driver</h3>
                <p className="text-gray-400 text-sm">Order #{driverOrder.id.slice(0, 8)}</p>
              </div>
              <button onClick={() => { setShowDriverModal(false); setDriverOrder(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-3">Select Driver or Courier</label>
                <div className="space-y-2">
                  <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">Internal Drivers</p>
                  {AVAILABLE_DRIVERS.filter(d => d.type === 'internal').map(driver => (
                    <button
                      key={driver.id}
                      onClick={() => setSelectedDriver(driver.id)}
                      className={`w-full p-3 rounded-lg text-left transition-colors flex items-center justify-between ${
                        selectedDriver === driver.id 
                          ? 'bg-accent/20 border border-accent' 
                          : 'bg-[#2d2d2d] border border-gray-700 hover:border-gray-600'
                      }`}
                    >
                      <div>
                        <p className="text-white font-medium">{driver.name}</p>
                        {driver.phone && <p className="text-gray-400 text-sm">{driver.phone}</p>}
                      </div>
                      {selectedDriver === driver.id && <CheckCircle className="w-5 h-5 text-accent" />}
                    </button>
                  ))}
                  
                  <p className="text-xs text-gray-500 uppercase tracking-wider mb-2 mt-4">External Couriers</p>
                  {AVAILABLE_DRIVERS.filter(d => d.type === 'external').map(driver => (
                    <button
                      key={driver.id}
                      onClick={() => setSelectedDriver(driver.id)}
                      className={`w-full p-3 rounded-lg text-left transition-colors flex items-center justify-between ${
                        selectedDriver === driver.id 
                          ? 'bg-accent/20 border border-accent' 
                          : 'bg-[#2d2d2d] border border-gray-700 hover:border-gray-600'
                      }`}
                    >
                      <div>
                        <p className="text-white font-medium">{driver.name}</p>
                        <p className="text-gray-400 text-sm">External Courier</p>
                      </div>
                      {selectedDriver === driver.id && <CheckCircle className="w-5 h-5 text-accent" />}
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => { setShowDriverModal(false); setDriverOrder(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleAssignDriver}
                disabled={!selectedDriver}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                <UserCheck className="w-5 h-5" />
                Assign Driver
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Shipping Label Modal */}
      {showLabelModal && labelOrder && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-lg border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <div>
                <h3 className="text-xl font-semibold text-white">Shipping Label</h3>
                <p className="text-gray-400 text-sm">Order #{labelOrder.id.slice(0, 8)}</p>
              </div>
              <button onClick={() => { setShowLabelModal(false); setLabelOrder(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            {/* Label Preview */}
            <div className="p-6">
              <div ref={labelRef} className="bg-white text-black rounded-lg p-6">
                <div className="label">
                  <div className="header">
                    <div className="shop-name">{shopName}</div>
                    <div className="order-id">Order #{labelOrder.id.slice(0, 8)} • {new Date(labelOrder.created_at).toLocaleDateString()}</div>
                  </div>
                  
                  <div className="section">
                    <div className="section-title">Ship To</div>
                    <div className="address">
                      {labelOrder.part_requests?.profiles?.full_name || "Customer"}<br />
                      {labelOrder.delivery_address || "Address not provided"}<br />
                      {labelOrder.part_requests?.profiles?.phone || ""}
                    </div>
                  </div>

                  <div className="part-info">
                    <div className="section-title">Contents</div>
                    <div className="section-content">
                      {labelOrder.part_requests?.part_category || "Auto Part"}<br />
                      <span style={{fontSize: '14px', color: '#666'}}>
                        {labelOrder.part_requests?.vehicle_make} {labelOrder.part_requests?.vehicle_model}
                      </span>
                    </div>
                  </div>

                  {labelOrder.tracking_number && (
                    <div className="barcode">
                      <div className="section-title">Tracking Number</div>
                      <div className="barcode-text">{labelOrder.tracking_number}</div>
                    </div>
                  )}

                  <div className="footer">
                    <div style={{display: 'flex', justifyContent: 'space-between'}}>
                      <span>Delivery: {labelOrder.delivery_destination === 'mechanic' ? 'Mechanic' : 'Customer'}</span>
                      <span>Value: R{((labelOrder.total_cents || 0) / 100).toLocaleString()}</span>
                    </div>
                    {labelOrder.assigned_driver && (
                      <div style={{marginTop: '8px'}}>
                        Driver: {getDriverName(labelOrder.assigned_driver)}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => { setShowLabelModal(false); setLabelOrder(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handlePrintLabel}
                className="flex-1 px-4 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                <Printer className="w-5 h-5" />
                Print Label
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
