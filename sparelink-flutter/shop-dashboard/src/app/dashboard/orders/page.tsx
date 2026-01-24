"use client"

import { useEffect, useState, useRef } from "react"
import { supabase } from "@/lib/supabase"
import { Package, Truck, CheckCircle, Clock, MapPin, User, Wrench, RefreshCw, Bell, Printer, Hash, UserCheck, CheckSquare, Square, X, Save, ChevronDown, FileText, AlertCircle, CreditCard, Receipt, DollarSign, ExternalLink } from "lucide-react"

// =============================================================================
// UNIFIED ORDER STATUS (CS-15 FIX)
// Synchronized across Flutter, Next.js Dashboard, and Supabase
// =============================================================================

type OrderStatusType = 
  | "pending"         // Dashboard initial
  | "confirmed"       // Flutter initial
  | "preparing"       // Both use
  | "processing"      // Dashboard alias for preparing
  | "shipped"         // Dashboard uses
  | "out_for_delivery" // Flutter uses
  | "delivered"       // Both use
  | "cancelled";      // Both use

// Status display labels (unified with Flutter)
const STATUS_LABELS: Record<OrderStatusType, string> = {
  "pending": "Pending",
  "confirmed": "Order Confirmed",
  "preparing": "Being Prepared",
  "processing": "Being Prepared",
  "shipped": "Shipped",
  "out_for_delivery": "Out for Delivery",
  "delivered": "Delivered",
  "cancelled": "Cancelled"
};

// Valid status transitions (for future state machine validation)
const VALID_TRANSITIONS: Record<OrderStatusType, OrderStatusType[]> = {
  "pending": ["confirmed", "cancelled"],
  "confirmed": ["preparing", "cancelled"],
  "preparing": ["processing", "shipped", "cancelled"],
  "processing": ["shipped", "cancelled"],
  "shipped": ["out_for_delivery", "delivered"],
  "out_for_delivery": ["delivered"],
  "delivered": [],
  "cancelled": []
};

// Get display label for status
const getStatusLabel = (status: string): string => {
  return STATUS_LABELS[status as OrderStatusType] || status;
};

// Check if status transition is valid
const canTransitionTo = (currentStatus: string, newStatus: string): boolean => {
  const allowed = VALID_TRANSITIONS[currentStatus as OrderStatusType] || [];
  return allowed.includes(newStatus as OrderStatusType);
};

// Get available next statuses for an order
const getAvailableStatuses = (currentStatus: string): OrderStatusType[] => {
  return VALID_TRANSITIONS[currentStatus as OrderStatusType] || [];
};

interface Order {
  id: string
  status: OrderStatusType
  total_cents: number
  total_amount?: number // legacy field
  created_at: string
  delivery_destination: 'user' | 'mechanic' | null
  delivery_address: string | null
  tracking_number?: string | null
  assigned_driver?: string | null
  payment_status?: 'pending' | 'paid' | 'failed'
  payment_reference?: string | null
  invoice_number?: string | null
  part_requests?: { 
    vehicle_make: string
    vehicle_model: string
    part_category: string
    part_description?: string
    mechanic_id: string
    profiles?: { full_name: string; phone: string; email?: string }
  }
  offers?: { 
    shops: { name: string; address?: string; phone?: string }
    price_cents?: number
    delivery_fee_cents?: number
  }
}

// Paystack configuration (test keys - replace with live in production)
const PAYSTACK_PUBLIC_KEY = 'pk_test_xxxxx' // Replace with actual key

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
  const invoiceRef = useRef<HTMLDivElement>(null)
  
  // Payment and Invoice state
  const [showPaymentModal, setShowPaymentModal] = useState(false)
  const [paymentOrder, setPaymentOrder] = useState<Order | null>(null)
  const [processingPayment, setProcessingPayment] = useState(false)
  const [showInvoiceModal, setShowInvoiceModal] = useState(false)
  const [invoiceOrder, setInvoiceOrder] = useState<Order | null>(null)

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

  // CS-16 FIX: Update order status with transition validation error handling
  const updateOrderStatus = async (orderId: string, newStatus: string) => {
    // Find the order to check current status
    const order = orders.find(o => o.id === orderId)
    if (!order) return
    
    // Client-side validation (CS-16)
    if (!canTransitionTo(order.status, newStatus)) {
      alert(`Invalid status transition: Cannot change from "${getStatusLabel(order.status)}" to "${getStatusLabel(newStatus)}"`)
      return
    }
    
    try {
      const { error } = await supabase
        .from("orders")
        .update({ status: newStatus })
        .eq("id", orderId)

      if (error) {
        // CS-16: Handle database trigger errors
        if (error.message?.includes('INVALID_STATUS_TRANSITION') || error.code === 'P0010') {
          alert(`Invalid status transition. The database rejected this change.`)
        } else {
          alert(`Failed to update order: ${error.message}`)
        }
        return
      }

      setOrders(orders.map(o => o.id === orderId ? { ...o, status: newStatus as OrderStatusType } : o))
    } catch (error) {
      console.error("Error updating order:", error)
      alert("Failed to update order status")
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

  // CS-16 FIX: Batch update order status with transition validation
  const handleBatchStatusUpdate = async (newStatus: string) => {
    if (selectedOrders.size === 0) return
    
    // Filter orders that can transition to the new status (CS-16)
    const validOrders = Array.from(selectedOrders).filter(orderId => {
      const order = orders.find(o => o.id === orderId)
      return order && canTransitionTo(order.status, newStatus)
    })
    
    if (validOrders.length === 0) {
      alert(`None of the selected orders can transition to "${getStatusLabel(newStatus)}"`)
      return
    }
    
    if (validOrders.length < selectedOrders.size) {
      const skipped = selectedOrders.size - validOrders.length
      if (!confirm(`${skipped} order(s) cannot transition to "${getStatusLabel(newStatus)}" and will be skipped. Continue with ${validOrders.length} order(s)?`)) {
        return
      }
    }
    
    setBatchUpdating(true)
    let successCount = 0
    let failCount = 0
    
    try {
      // Update only valid orders
      for (const orderId of validOrders) {
        const { error } = await supabase
          .from("orders")
          .update({ status: newStatus })
          .eq("id", orderId)
        
        if (error) {
          console.error(`Failed to update order ${orderId}:`, error)
          failCount++
        } else {
          successCount++
        }
      }

      // Update local state for successful updates
      setOrders(orders.map(o => 
        validOrders.includes(o.id) && !failCount ? { ...o, status: newStatus as OrderStatusType } : o
      ))
      setSelectedOrders(new Set())
      
      if (failCount > 0) {
        alert(`Updated ${successCount} orders. ${failCount} failed due to validation errors.`)
      }
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

  // Generate invoice number
  const generateInvoiceNumber = () => {
    const date = new Date()
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const random = Math.random().toString(36).substring(2, 6).toUpperCase()
    return `INV-${year}${month}-${random}`
  }

  // Process payment via Paystack
  const handleProcessPayment = async () => {
    if (!paymentOrder) return
    
    setProcessingPayment(true)
    try {
      // In production, this would integrate with Paystack's API
      // For demo, we simulate a payment flow
      const reference = `PAY-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`
      
      // Simulate payment processing
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // Update order with payment info
      const invoiceNum = generateInvoiceNumber()
      await supabase
        .from("orders")
        .update({ 
          payment_status: 'paid',
          payment_reference: reference,
          invoice_number: invoiceNum
        })
        .eq("id", paymentOrder.id)
      
      setOrders(orders.map(o => 
        o.id === paymentOrder.id 
          ? { ...o, payment_status: 'paid' as const, payment_reference: reference, invoice_number: invoiceNum }
          : o
      ))
      
      alert(`Payment successful!\nReference: ${reference}\nInvoice: ${invoiceNum}`)
      setShowPaymentModal(false)
      setPaymentOrder(null)
    } catch (error) {
      console.error("Payment error:", error)
      alert("Payment failed. Please try again.")
    } finally {
      setProcessingPayment(false)
    }
  }

  // Generate and print invoice
  const handlePrintInvoice = () => {
    if (!invoiceRef.current || !invoiceOrder) return
    
    const printContent = invoiceRef.current.innerHTML
    const printWindow = window.open('', '_blank', 'width=800,height=600')
    if (!printWindow) {
      alert("Please allow pop-ups to print invoices")
      return
    }

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Invoice ${invoiceOrder.invoice_number || generateInvoiceNumber()}</title>
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: Arial, sans-serif; padding: 40px; color: #333; }
            .invoice { max-width: 800px; margin: 0 auto; }
            .header { display: flex; justify-content: space-between; margin-bottom: 40px; padding-bottom: 20px; border-bottom: 2px solid #10b981; }
            .company { font-size: 24px; font-weight: bold; color: #10b981; }
            .invoice-title { font-size: 32px; font-weight: bold; color: #333; }
            .invoice-details { text-align: right; }
            .invoice-number { font-size: 14px; color: #666; margin-top: 5px; }
            .parties { display: flex; justify-content: space-between; margin-bottom: 30px; }
            .party { width: 45%; }
            .party-title { font-size: 12px; color: #666; text-transform: uppercase; margin-bottom: 10px; }
            .party-name { font-size: 18px; font-weight: bold; margin-bottom: 5px; }
            .party-details { font-size: 14px; color: #666; line-height: 1.6; }
            .items { margin-bottom: 30px; }
            .items table { width: 100%; border-collapse: collapse; }
            .items th { background: #f5f5f5; padding: 12px; text-align: left; font-size: 12px; text-transform: uppercase; color: #666; }
            .items td { padding: 12px; border-bottom: 1px solid #eee; }
            .items .amount { text-align: right; }
            .totals { margin-left: auto; width: 300px; }
            .totals table { width: 100%; }
            .totals td { padding: 8px 0; }
            .totals .label { color: #666; }
            .totals .value { text-align: right; font-weight: 500; }
            .totals .grand-total { font-size: 18px; font-weight: bold; border-top: 2px solid #333; padding-top: 12px; }
            .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; text-align: center; }
            .paid-stamp { position: absolute; top: 50%; right: 50px; transform: rotate(-15deg); font-size: 48px; font-weight: bold; color: rgba(16, 185, 129, 0.3); border: 4px solid rgba(16, 185, 129, 0.3); padding: 10px 20px; }
            @media print { body { padding: 20px; } }
          </style>
        </head>
        <body>
          ${printContent}
          <script>
            window.onload = function() { window.print(); }
          </script>
        </body>
      </html>
    `)
    printWindow.document.close()
  }

  // Get payment status badge
  const getPaymentBadge = (status?: string) => {
    switch (status) {
      case 'paid':
        return <span className="px-2 py-1 bg-green-500/20 text-green-400 rounded text-xs flex items-center gap-1"><CheckCircle className="w-3 h-3" /> Paid</span>
      case 'failed':
        return <span className="px-2 py-1 bg-red-500/20 text-red-400 rounded text-xs">Failed</span>
      default:
        return <span className="px-2 py-1 bg-yellow-500/20 text-yellow-400 rounded text-xs">Pending</span>
    }
  }

  // Get status icon based on unified status (CS-15 FIX)
  const getStatusIcon = (status: string) => {
    switch (status) {
      case "delivered": return <CheckCircle className="w-5 h-5 text-green-400" />
      case "shipped": 
      case "out_for_delivery": return <Truck className="w-5 h-5 text-blue-400" />
      case "processing":
      case "preparing": return <Package className="w-5 h-5 text-yellow-400" />
      case "confirmed": return <CheckCircle className="w-5 h-5 text-accent" />
      case "cancelled": return <X className="w-5 h-5 text-red-400" />
      default: return <Clock className="w-5 h-5 text-gray-400" />
    }
  }

  // Unified status options (CS-15 FIX) - synced with Flutter OrderStatus enum
  const statusOptions: OrderStatusType[] = ["confirmed", "preparing", "shipped", "out_for_delivery", "delivered"]
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
                <div className="flex items-center gap-2 flex-wrap">
                  <button
                    onClick={() => { setLabelOrder(order); setShowLabelModal(true); }}
                    className="px-3 py-1.5 bg-blue-500/20 hover:bg-blue-500/30 text-blue-400 rounded-lg text-sm flex items-center gap-1 transition-colors"
                  >
                    <Printer className="w-4 h-4" />
                    Label
                  </button>
                  <button
                    onClick={() => { setInvoiceOrder(order); setShowInvoiceModal(true); }}
                    className="px-3 py-1.5 bg-purple-500/20 hover:bg-purple-500/30 text-purple-400 rounded-lg text-sm flex items-center gap-1 transition-colors"
                  >
                    <Receipt className="w-4 h-4" />
                    Invoice
                  </button>
                  {order.payment_status !== 'paid' && (
                    <button
                      onClick={() => { setPaymentOrder(order); setShowPaymentModal(true); }}
                      className="px-3 py-1.5 bg-green-500/20 hover:bg-green-500/30 text-green-400 rounded-lg text-sm flex items-center gap-1 transition-colors"
                    >
                      <CreditCard className="w-4 h-4" />
                      Payment
                    </button>
                  )}
                  {getPaymentBadge(order.payment_status)}
                </div>

                {/* Status Buttons (CS-16 FIX) - Only show valid transitions */}
                <div className="flex gap-2 flex-wrap items-center">
                  {/* Current status indicator */}
                  <span className="px-3 py-1.5 rounded-lg text-sm bg-accent text-white">
                    {getStatusLabel(order.status)}
                  </span>
                  
                  {/* Valid transition buttons */}
                  {getAvailableStatuses(order.status).length > 0 ? (
                    <>
                      <span className="text-gray-500 text-sm">→</span>
                      {getAvailableStatuses(order.status).map((status) => (
                        <button
                          key={status}
                          onClick={() => updateOrderStatus(order.id, status)}
                          className={`px-3 py-1.5 rounded-lg text-sm transition-colors ${
                            status === 'cancelled'
                              ? "bg-red-500/20 text-red-400 hover:bg-red-500/30"
                              : "bg-[#2d2d2d] text-gray-400 hover:text-white hover:bg-[#3d3d3d]"
                          }`}
                        >
                          {getStatusLabel(status)}
                        </button>
                      ))}
                    </>
                  ) : (
                    <span className="text-gray-500 text-sm italic">
                      {order.status === 'delivered' ? '✓ Completed' : order.status === 'cancelled' ? '✗ Cancelled' : ''}
                    </span>
                  )}
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

      {/* Payment Modal */}
      {showPaymentModal && paymentOrder && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-md border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <div>
                <h3 className="text-xl font-semibold text-white">Process Payment</h3>
                <p className="text-gray-400 text-sm">Order #{paymentOrder.id.slice(0, 8)}</p>
              </div>
              <button onClick={() => { setShowPaymentModal(false); setPaymentOrder(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              {/* Order Summary */}
              <div className="bg-[#2d2d2d] rounded-lg p-4">
                <h4 className="text-white font-medium mb-3">Order Summary</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-400">Part</span>
                    <span className="text-white">{paymentOrder.part_requests?.part_category || 'Auto Part'}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Vehicle</span>
                    <span className="text-white">{paymentOrder.part_requests?.vehicle_make} {paymentOrder.part_requests?.vehicle_model}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Customer</span>
                    <span className="text-white">{paymentOrder.part_requests?.profiles?.full_name || 'Customer'}</span>
                  </div>
                </div>
              </div>

              {/* Amount */}
              <div className="bg-accent/10 border border-accent/30 rounded-lg p-4">
                <div className="flex justify-between items-center">
                  <span className="text-gray-300">Amount to Collect</span>
                  <span className="text-2xl font-bold text-accent">R{((paymentOrder.total_cents || 0) / 100).toLocaleString()}</span>
                </div>
              </div>

              {/* Payment Methods */}
              <div>
                <label className="block text-sm text-gray-400 mb-3">Payment Method</label>
                <div className="grid grid-cols-2 gap-3">
                  <button className="p-4 bg-[#2d2d2d] border-2 border-accent rounded-lg text-center hover:bg-[#3d3d3d] transition-colors">
                    <CreditCard className="w-8 h-8 text-accent mx-auto mb-2" />
                    <span className="text-white text-sm font-medium">Card Payment</span>
                    <span className="text-gray-500 text-xs block">via Paystack</span>
                  </button>
                  <button className="p-4 bg-[#2d2d2d] border border-gray-700 rounded-lg text-center hover:bg-[#3d3d3d] hover:border-gray-600 transition-colors">
                    <DollarSign className="w-8 h-8 text-green-400 mx-auto mb-2" />
                    <span className="text-white text-sm font-medium">Cash/EFT</span>
                    <span className="text-gray-500 text-xs block">Manual entry</span>
                  </button>
                </div>
              </div>

              {/* Paystack Info */}
              <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-3 flex items-start gap-2">
                <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <div className="text-sm">
                  <p className="text-blue-300">Secure payment processing by Paystack.</p>
                  <p className="text-blue-400/70 text-xs mt-1">Cards, bank transfers, and mobile money accepted.</p>
                </div>
              </div>
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => { setShowPaymentModal(false); setPaymentOrder(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleProcessPayment}
                disabled={processingPayment}
                className="flex-1 px-4 py-3 bg-green-500 hover:bg-green-600 text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {processingPayment ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    Processing...
                  </>
                ) : (
                  <>
                    <CreditCard className="w-5 h-5" />
                    Process Payment
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Invoice Modal */}
      {showInvoiceModal && invoiceOrder && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-3xl border border-gray-800 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-800 sticky top-0 bg-[#1a1a1a]">
              <div>
                <h3 className="text-xl font-semibold text-white">Invoice</h3>
                <p className="text-gray-400 text-sm">Order #{invoiceOrder.id.slice(0, 8)}</p>
              </div>
              <button onClick={() => { setShowInvoiceModal(false); setInvoiceOrder(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            {/* Invoice Preview */}
            <div className="p-6">
              <div ref={invoiceRef} className="bg-white text-black rounded-lg p-8">
                <div className="invoice" style={{position: 'relative'}}>
                  {/* Paid Stamp */}
                  {invoiceOrder.payment_status === 'paid' && (
                    <div className="paid-stamp">PAID</div>
                  )}
                  
                  {/* Header */}
                  <div className="header" style={{display: 'flex', justifyContent: 'space-between', marginBottom: '40px', paddingBottom: '20px', borderBottom: '2px solid #10b981'}}>
                    <div>
                      <div className="company" style={{fontSize: '24px', fontWeight: 'bold', color: '#10b981'}}>{shopName}</div>
                      <div style={{color: '#666', fontSize: '14px', marginTop: '5px'}}>Auto Parts Supplier</div>
                    </div>
                    <div className="invoice-details" style={{textAlign: 'right'}}>
                      <div className="invoice-title" style={{fontSize: '32px', fontWeight: 'bold', color: '#333'}}>INVOICE</div>
                      <div className="invoice-number" style={{fontSize: '14px', color: '#666', marginTop: '5px'}}>
                        {invoiceOrder.invoice_number || generateInvoiceNumber()}
                      </div>
                      <div style={{fontSize: '14px', color: '#666'}}>
                        Date: {new Date(invoiceOrder.created_at).toLocaleDateString('en-ZA')}
                      </div>
                    </div>
                  </div>

                  {/* Parties */}
                  <div className="parties" style={{display: 'flex', justifyContent: 'space-between', marginBottom: '30px'}}>
                    <div className="party" style={{width: '45%'}}>
                      <div className="party-title" style={{fontSize: '12px', color: '#666', textTransform: 'uppercase', marginBottom: '10px'}}>Bill To</div>
                      <div className="party-name" style={{fontSize: '18px', fontWeight: 'bold', marginBottom: '5px'}}>
                        {invoiceOrder.part_requests?.profiles?.full_name || 'Customer'}
                      </div>
                      <div className="party-details" style={{fontSize: '14px', color: '#666', lineHeight: '1.6'}}>
                        {invoiceOrder.delivery_address || 'Address not provided'}<br />
                        {invoiceOrder.part_requests?.profiles?.phone || ''}
                        {invoiceOrder.part_requests?.profiles?.email && <><br />{invoiceOrder.part_requests.profiles.email}</>}
                      </div>
                    </div>
                    <div className="party" style={{width: '45%'}}>
                      <div className="party-title" style={{fontSize: '12px', color: '#666', textTransform: 'uppercase', marginBottom: '10px'}}>Ship To</div>
                      <div className="party-details" style={{fontSize: '14px', color: '#666', lineHeight: '1.6'}}>
                        {invoiceOrder.delivery_destination === 'mechanic' ? 'Mechanic Workshop' : 'Customer Address'}<br />
                        {invoiceOrder.delivery_address || 'Address not provided'}
                      </div>
                    </div>
                  </div>

                  {/* Items Table */}
                  <div className="items" style={{marginBottom: '30px'}}>
                    <table style={{width: '100%', borderCollapse: 'collapse'}}>
                      <thead>
                        <tr>
                          <th style={{background: '#f5f5f5', padding: '12px', textAlign: 'left', fontSize: '12px', textTransform: 'uppercase', color: '#666'}}>Description</th>
                          <th style={{background: '#f5f5f5', padding: '12px', textAlign: 'left', fontSize: '12px', textTransform: 'uppercase', color: '#666'}}>Vehicle</th>
                          <th style={{background: '#f5f5f5', padding: '12px', textAlign: 'right', fontSize: '12px', textTransform: 'uppercase', color: '#666'}}>Qty</th>
                          <th style={{background: '#f5f5f5', padding: '12px', textAlign: 'right', fontSize: '12px', textTransform: 'uppercase', color: '#666'}}>Amount</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr>
                          <td style={{padding: '12px', borderBottom: '1px solid #eee'}}>
                            <div style={{fontWeight: '500'}}>{invoiceOrder.part_requests?.part_category || 'Auto Part'}</div>
                            {invoiceOrder.part_requests?.part_description && (
                              <div style={{fontSize: '12px', color: '#666'}}>{invoiceOrder.part_requests.part_description}</div>
                            )}
                          </td>
                          <td style={{padding: '12px', borderBottom: '1px solid #eee'}}>
                            {invoiceOrder.part_requests?.vehicle_make} {invoiceOrder.part_requests?.vehicle_model}
                          </td>
                          <td style={{padding: '12px', borderBottom: '1px solid #eee', textAlign: 'right'}}>1</td>
                          <td style={{padding: '12px', borderBottom: '1px solid #eee', textAlign: 'right', fontWeight: '500'}}>
                            R{((invoiceOrder.total_cents || 0) / 100).toLocaleString()}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  {/* Totals */}
                  <div className="totals" style={{marginLeft: 'auto', width: '300px'}}>
                    <table style={{width: '100%'}}>
                      <tbody>
                        <tr>
                          <td style={{padding: '8px 0', color: '#666'}}>Subtotal</td>
                          <td style={{padding: '8px 0', textAlign: 'right', fontWeight: '500'}}>R{((invoiceOrder.total_cents || 0) / 100).toLocaleString()}</td>
                        </tr>
                        <tr>
                          <td style={{padding: '8px 0', color: '#666'}}>VAT (15%)</td>
                          <td style={{padding: '8px 0', textAlign: 'right', fontWeight: '500'}}>R{(((invoiceOrder.total_cents || 0) / 100) * 0.15).toFixed(2)}</td>
                        </tr>
                        <tr className="grand-total">
                          <td style={{padding: '12px 0', fontSize: '18px', fontWeight: 'bold', borderTop: '2px solid #333'}}>Total</td>
                          <td style={{padding: '12px 0', textAlign: 'right', fontSize: '18px', fontWeight: 'bold', borderTop: '2px solid #333'}}>
                            R{(((invoiceOrder.total_cents || 0) / 100) * 1.15).toFixed(2)}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  {/* Payment Info */}
                  {invoiceOrder.payment_status === 'paid' && invoiceOrder.payment_reference && (
                    <div style={{marginTop: '30px', padding: '15px', background: '#f0fdf4', borderRadius: '8px', border: '1px solid #bbf7d0'}}>
                      <div style={{color: '#166534', fontWeight: '500', marginBottom: '5px'}}>Payment Received</div>
                      <div style={{color: '#15803d', fontSize: '14px'}}>
                        Reference: {invoiceOrder.payment_reference}
                      </div>
                    </div>
                  )}

                  {/* Footer */}
                  <div className="footer" style={{marginTop: '40px', paddingTop: '20px', borderTop: '1px solid #eee', fontSize: '12px', color: '#666', textAlign: 'center'}}>
                    <p>Thank you for your business!</p>
                    <p style={{marginTop: '5px'}}>For queries, contact us at support@sparelink.co.za</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3 sticky bottom-0 bg-[#1a1a1a]">
              <button
                onClick={() => { setShowInvoiceModal(false); setInvoiceOrder(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Close
              </button>
              <button
                onClick={handlePrintInvoice}
                className="flex-1 px-4 py-3 bg-purple-500 hover:bg-purple-600 text-white rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                <Printer className="w-5 h-5" />
                Print / Download PDF
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
