"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { Users, Search, Phone, Mail, DollarSign, ShoppingCart, Calendar, Star, TrendingUp, ChevronRight, X, MessageSquare, FileText } from "lucide-react"

interface Customer {
  id: string
  name: string
  phone: string
  email?: string
  total_orders: number
  total_spent: number
  avg_order_value: number
  first_order: string
  last_order: string
  loyalty_tier: 'bronze' | 'silver' | 'gold' | 'platinum'
  notes?: string
  orders: CustomerOrder[]
}

interface CustomerOrder {
  id: string
  date: string
  part: string
  amount: number
  status: string
}

const LOYALTY_TIERS = {
  bronze: { min: 0, color: 'text-orange-400', bg: 'bg-orange-500/20' },
  silver: { min: 5000, color: 'text-gray-300', bg: 'bg-gray-500/20' },
  gold: { min: 15000, color: 'text-yellow-400', bg: 'bg-yellow-500/20' },
  platinum: { min: 50000, color: 'text-purple-400', bg: 'bg-purple-500/20' },
}

function getLoyaltyTier(totalSpent: number): Customer['loyalty_tier'] {
  if (totalSpent >= 50000) return 'platinum'
  if (totalSpent >= 15000) return 'gold'
  if (totalSpent >= 5000) return 'silver'
  return 'bronze'
}

export default function CustomersPage() {
  const [customers, setCustomers] = useState<Customer[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState("")
  const [filterTier, setFilterTier] = useState("")
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
  const [sortBy, setSortBy] = useState<"spent" | "orders" | "recent">("spent")

  useEffect(() => {
    loadCustomers()
  }, [])

  const loadCustomers = async () => {
    setLoading(true)
    try {
      // Load from localStorage or generate sample data
      const saved = localStorage.getItem('sparelink-customers')
      if (saved) {
        setCustomers(JSON.parse(saved))
      } else {
        // Generate sample customer data
        const sampleCustomers: Customer[] = [
          {
            id: '1', name: 'John Mokoena', phone: '+27 82 123 4567', email: 'john@autofix.co.za',
            total_orders: 23, total_spent: 67500, avg_order_value: 2935,
            first_order: '2024-03-15', last_order: '2025-01-18',
            loyalty_tier: 'platinum',
            notes: 'Preferred mechanic for German cars',
            orders: [
              { id: 'o1', date: '2025-01-18', part: 'BMW Brake Pads', amount: 2800, status: 'delivered' },
              { id: 'o2', date: '2025-01-05', part: 'Oil Filter Set', amount: 450, status: 'delivered' },
              { id: 'o3', date: '2024-12-20', part: 'Alternator', amount: 4500, status: 'delivered' },
            ]
          },
          {
            id: '2', name: 'Sarah Nkosi', phone: '+27 83 234 5678', email: 'sarah@quickrepairs.com',
            total_orders: 15, total_spent: 34200, avg_order_value: 2280,
            first_order: '2024-06-01', last_order: '2025-01-15',
            loyalty_tier: 'gold',
            notes: 'Toyota specialist',
            orders: [
              { id: 'o4', date: '2025-01-15', part: 'Shock Absorbers (Pair)', amount: 3200, status: 'shipped' },
              { id: 'o5', date: '2025-01-02', part: 'Spark Plugs', amount: 680, status: 'delivered' },
            ]
          },
          {
            id: '3', name: 'Mike Dlamini', phone: '+27 84 345 6789',
            total_orders: 8, total_spent: 12500, avg_order_value: 1563,
            first_order: '2024-09-10', last_order: '2025-01-10',
            loyalty_tier: 'silver',
            orders: [
              { id: 'o6', date: '2025-01-10', part: 'Air Filter', amount: 350, status: 'delivered' },
            ]
          },
          {
            id: '4', name: 'Thabo Ndlovu', phone: '+27 79 456 7890', email: 'thabo@gmail.com',
            total_orders: 3, total_spent: 4200, avg_order_value: 1400,
            first_order: '2024-11-20', last_order: '2025-01-08',
            loyalty_tier: 'bronze',
            orders: [
              { id: 'o7', date: '2025-01-08', part: 'Windscreen Wipers', amount: 280, status: 'delivered' },
            ]
          },
          {
            id: '5', name: 'Linda Mthembu', phone: '+27 82 567 8901', email: 'linda@automasters.co.za',
            total_orders: 31, total_spent: 89500, avg_order_value: 2887,
            first_order: '2024-01-05', last_order: '2025-01-20',
            loyalty_tier: 'platinum',
            notes: 'VIP customer - priority service',
            orders: [
              { id: 'o8', date: '2025-01-20', part: 'Transmission Kit', amount: 8500, status: 'processing' },
              { id: 'o9', date: '2025-01-12', part: 'Radiator', amount: 3200, status: 'delivered' },
            ]
          },
        ]
        setCustomers(sampleCustomers)
        localStorage.setItem('sparelink-customers', JSON.stringify(sampleCustomers))
      }
    } catch (e) {
      console.error('Error loading customers:', e)
    } finally {
      setLoading(false)
    }
  }

  const updateCustomerNotes = (customerId: string, notes: string) => {
    const updated = customers.map(c =>
      c.id === customerId ? { ...c, notes } : c
    )
    setCustomers(updated)
    localStorage.setItem('sparelink-customers', JSON.stringify(updated))
    if (selectedCustomer?.id === customerId) {
      setSelectedCustomer({ ...selectedCustomer, notes })
    }
  }

  // Filter and sort customers
  const filteredCustomers = customers
    .filter(customer => {
      const matchesSearch = searchTerm === "" ||
        customer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        customer.phone.includes(searchTerm) ||
        customer.email?.toLowerCase().includes(searchTerm.toLowerCase())
      
      const matchesTier = filterTier === "" || customer.loyalty_tier === filterTier
      
      return matchesSearch && matchesTier
    })
    .sort((a, b) => {
      if (sortBy === "spent") return b.total_spent - a.total_spent
      if (sortBy === "orders") return b.total_orders - a.total_orders
      return new Date(b.last_order).getTime() - new Date(a.last_order).getTime()
    })

  // Stats
  const totalCustomers = customers.length
  const totalRevenue = customers.reduce((sum, c) => sum + c.total_spent, 0)
  const avgCustomerValue = totalCustomers > 0 ? Math.round(totalRevenue / totalCustomers) : 0
  const platinumCount = customers.filter(c => c.loyalty_tier === 'platinum').length

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-white">Customer Database</h1>
        <p className="text-gray-400 text-sm">Track mechanic loyalty, spend, and order history</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
              <Users className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Total Customers</p>
              <p className="text-xl font-bold text-white">{totalCustomers}</p>
            </div>
          </div>
        </div>
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
              <DollarSign className="w-5 h-5 text-green-400" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Total Revenue</p>
              <p className="text-xl font-bold text-green-400">R{totalRevenue.toLocaleString()}</p>
            </div>
          </div>
        </div>
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-accent/20 rounded-lg flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-accent" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Avg Customer Value</p>
              <p className="text-xl font-bold text-white">R{avgCustomerValue.toLocaleString()}</p>
            </div>
          </div>
        </div>
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-purple-500/20 rounded-lg flex items-center justify-center">
              <Star className="w-5 h-5 text-purple-400" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Platinum Members</p>
              <p className="text-xl font-bold text-purple-400">{platinumCount}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="flex flex-wrap gap-4">
        <div className="flex-1 relative min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by name, phone, or email..."
            className="w-full bg-[#1a1a1a] text-white pl-10 pr-4 py-3 rounded-lg border border-gray-800 focus:border-accent focus:outline-none"
          />
        </div>
        <select
          value={filterTier}
          onChange={(e) => setFilterTier(e.target.value)}
          className="bg-[#1a1a1a] text-white px-4 py-3 rounded-lg border border-gray-800"
        >
          <option value="">All Tiers</option>
          <option value="platinum">Platinum</option>
          <option value="gold">Gold</option>
          <option value="silver">Silver</option>
          <option value="bronze">Bronze</option>
        </select>
        <select
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value as any)}
          className="bg-[#1a1a1a] text-white px-4 py-3 rounded-lg border border-gray-800"
        >
          <option value="spent">Sort by Total Spent</option>
          <option value="orders">Sort by Orders</option>
          <option value="recent">Sort by Recent Activity</option>
        </select>
      </div>

      {/* Customers List */}
      <div className="bg-[#1a1a1a] rounded-xl border border-gray-800">
        {filteredCustomers.length === 0 ? (
          <div className="text-center py-12">
            <Users className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No customers found</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-800">
            {filteredCustomers.map((customer) => (
              <div
                key={customer.id}
                onClick={() => setSelectedCustomer(customer)}
                className="p-4 hover:bg-[#2d2d2d] cursor-pointer transition-colors flex items-center justify-between"
              >
                <div className="flex items-center gap-4">
                  <div className={`w-12 h-12 rounded-full flex items-center justify-center ${LOYALTY_TIERS[customer.loyalty_tier].bg}`}>
                    <span className={`text-lg font-bold ${LOYALTY_TIERS[customer.loyalty_tier].color}`}>
                      {customer.name.charAt(0)}
                    </span>
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-white font-medium">{customer.name}</p>
                      <span className={`px-2 py-0.5 rounded text-xs capitalize ${LOYALTY_TIERS[customer.loyalty_tier].bg} ${LOYALTY_TIERS[customer.loyalty_tier].color}`}>
                        {customer.loyalty_tier}
                      </span>
                    </div>
                    <p className="text-gray-500 text-sm">{customer.phone}</p>
                  </div>
                </div>
                <div className="flex items-center gap-8">
                  <div className="text-right">
                    <p className="text-white font-medium">R{customer.total_spent.toLocaleString()}</p>
                    <p className="text-gray-500 text-sm">{customer.total_orders} orders</p>
                  </div>
                  <ChevronRight className="w-5 h-5 text-gray-600" />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Customer Detail Modal */}
      {selectedCustomer && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-2xl border border-gray-800 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-800 sticky top-0 bg-[#1a1a1a]">
              <div className="flex items-center gap-4">
                <div className={`w-14 h-14 rounded-full flex items-center justify-center ${LOYALTY_TIERS[selectedCustomer.loyalty_tier].bg}`}>
                  <span className={`text-2xl font-bold ${LOYALTY_TIERS[selectedCustomer.loyalty_tier].color}`}>
                    {selectedCustomer.name.charAt(0)}
                  </span>
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-xl font-semibold text-white">{selectedCustomer.name}</h3>
                    <span className={`px-2 py-0.5 rounded text-xs capitalize ${LOYALTY_TIERS[selectedCustomer.loyalty_tier].bg} ${LOYALTY_TIERS[selectedCustomer.loyalty_tier].color}`}>
                      {selectedCustomer.loyalty_tier}
                    </span>
                  </div>
                  <p className="text-gray-400 text-sm">Customer since {new Date(selectedCustomer.first_order).toLocaleDateString('en-ZA', { month: 'long', year: 'numeric' })}</p>
                </div>
              </div>
              <button onClick={() => setSelectedCustomer(null)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="p-6 space-y-6">
              {/* Contact Info */}
              <div className="grid grid-cols-2 gap-4">
                <div className="flex items-center gap-3 p-3 bg-[#2d2d2d] rounded-lg">
                  <Phone className="w-5 h-5 text-accent" />
                  <div>
                    <p className="text-gray-500 text-xs">Phone</p>
                    <p className="text-white">{selectedCustomer.phone}</p>
                  </div>
                </div>
                <div className="flex items-center gap-3 p-3 bg-[#2d2d2d] rounded-lg">
                  <Mail className="w-5 h-5 text-accent" />
                  <div>
                    <p className="text-gray-500 text-xs">Email</p>
                    <p className="text-white">{selectedCustomer.email || 'Not provided'}</p>
                  </div>
                </div>
              </div>

              {/* Stats */}
              <div className="grid grid-cols-4 gap-4">
                <div className="text-center p-4 bg-[#2d2d2d] rounded-lg">
                  <p className="text-2xl font-bold text-green-400">R{selectedCustomer.total_spent.toLocaleString()}</p>
                  <p className="text-gray-500 text-sm">Total Spent</p>
                </div>
                <div className="text-center p-4 bg-[#2d2d2d] rounded-lg">
                  <p className="text-2xl font-bold text-white">{selectedCustomer.total_orders}</p>
                  <p className="text-gray-500 text-sm">Orders</p>
                </div>
                <div className="text-center p-4 bg-[#2d2d2d] rounded-lg">
                  <p className="text-2xl font-bold text-white">R{selectedCustomer.avg_order_value.toLocaleString()}</p>
                  <p className="text-gray-500 text-sm">Avg Order</p>
                </div>
                <div className="text-center p-4 bg-[#2d2d2d] rounded-lg">
                  <p className="text-2xl font-bold text-accent">
                    {Math.ceil((new Date().getTime() - new Date(selectedCustomer.first_order).getTime()) / (1000 * 60 * 60 * 24 * 30))}
                  </p>
                  <p className="text-gray-500 text-sm">Months</p>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block text-sm text-gray-400 mb-2">Notes</label>
                <textarea
                  value={selectedCustomer.notes || ''}
                  onChange={(e) => updateCustomerNotes(selectedCustomer.id, e.target.value)}
                  placeholder="Add notes about this customer..."
                  rows={2}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none resize-none"
                />
              </div>

              {/* Order History */}
              <div>
                <h4 className="text-white font-medium mb-3 flex items-center gap-2">
                  <ShoppingCart className="w-4 h-4 text-accent" />
                  Recent Orders
                </h4>
                <div className="space-y-2">
                  {selectedCustomer.orders.map((order) => (
                    <div key={order.id} className="flex items-center justify-between p-3 bg-[#2d2d2d] rounded-lg">
                      <div>
                        <p className="text-white">{order.part}</p>
                        <p className="text-gray-500 text-sm">{new Date(order.date).toLocaleDateString()}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-white font-medium">R{order.amount.toLocaleString()}</p>
                        <span className={`text-xs px-2 py-0.5 rounded ${
                          order.status === 'delivered' ? 'bg-green-500/20 text-green-400' :
                          order.status === 'shipped' ? 'bg-blue-500/20 text-blue-400' :
                          'bg-yellow-500/20 text-yellow-400'
                        }`}>
                          {order.status}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Quick Actions */}
              <div className="flex gap-3 pt-4 border-t border-gray-800">
                <button className="flex-1 px-4 py-3 bg-[#2d2d2d] hover:bg-[#3d3d3d] text-white rounded-lg flex items-center justify-center gap-2 transition-colors">
                  <MessageSquare className="w-5 h-5" />
                  Send Message
                </button>
                <button className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg flex items-center justify-center gap-2 transition-colors">
                  <FileText className="w-5 h-5" />
                  View All Orders
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
