"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { Package, Plus, Search, Edit2, Trash2, X, Save, Upload, AlertCircle, Check, Filter, Download, BarChart3 } from "lucide-react"

interface InventoryItem {
  id: string
  part_number: string
  part_name: string
  category: string
  brand: string
  selling_price: number
  cost_price: number
  stock_quantity: number
  reorder_level: number
  location: string
  condition: 'new' | 'used' | 'refurbished'
  compatible_vehicles: string[]
  description: string
  image_url?: string
  created_at: string
  updated_at: string
}

const PART_CATEGORIES = [
  "Engine Parts", "Brake System", "Suspension", "Transmission", "Electrical",
  "Body Parts", "Interior", "Exhaust", "Cooling System", "Fuel System", "Steering", "Filters", "Other"
]

const initialItem: Omit<InventoryItem, 'id' | 'created_at' | 'updated_at'> = {
  part_number: "",
  part_name: "",
  category: "",
  brand: "",
  selling_price: 0,
  cost_price: 0,
  stock_quantity: 0,
  reorder_level: 5,
  location: "",
  condition: "new",
  compatible_vehicles: [],
  description: "",
}

export default function InventoryPage() {
  const [inventory, setInventory] = useState<InventoryItem[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState("")
  const [filterCategory, setFilterCategory] = useState("")
  const [filterStock, setFilterStock] = useState<"all" | "low" | "out">("all")
  const [showModal, setShowModal] = useState(false)
  const [editingItem, setEditingItem] = useState<InventoryItem | null>(null)
  const [formData, setFormData] = useState(initialItem)
  const [saving, setSaving] = useState(false)
  const [vehicleInput, setVehicleInput] = useState("")
  const [shopId, setShopId] = useState<string | null>(null)

  useEffect(() => {
    initializeAndLoad()
  }, [])

  const initializeAndLoad = async () => {
    try {
      // Get current user and their shop
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        setLoading(false)
        return
      }

      // Get shop ID for this user
      const { data: shop } = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .single()

      if (shop) {
        setShopId(shop.id)
        await loadInventory(shop.id)
      } else {
        // Check if user is staff at a shop
        const { data: staffRecord } = await supabase
          .from('shop_staff')
          .select('shop_id')
          .eq('user_id', user.id)
          .single()
        
        if (staffRecord) {
          setShopId(staffRecord.shop_id)
          await loadInventory(staffRecord.shop_id)
        }
      }
    } catch (error) {
      console.error('Error initializing:', error)
    } finally {
      setLoading(false)
    }
  }

  const loadInventory = async (shopIdParam: string) => {
    try {
      const { data, error } = await supabase
        .from('inventory')
        .select('*')
        .eq('shop_id', shopIdParam)
        .order('created_at', { ascending: false })

      if (error) throw error
      
      // Transform data to match component interface
      const transformedData: InventoryItem[] = (data || []).map(item => ({
        id: item.id,
        part_number: item.part_number || '',
        part_name: item.part_name || '',
        category: item.category || '',
        brand: item.brand || '',
        selling_price: (item.selling_price || 0) / 100, // Convert from cents
        cost_price: (item.cost_price || 0) / 100, // Convert from cents
        stock_quantity: item.stock_quantity || 0,
        reorder_level: item.reorder_level || 5,
        location: item.location || '',
        condition: item.condition || 'new',
        compatible_vehicles: item.compatible_vehicles || [],
        description: item.description || '',
        image_url: item.images?.[0] || '',
        created_at: item.created_at,
        updated_at: item.updated_at,
      }))
      
      setInventory(transformedData)
    } catch (error) {
      console.error('Error loading inventory:', error)
    }
  }

  const handleSaveItem = async () => {
    if (!formData.part_name || !formData.part_number || !formData.category) {
      alert('Please fill in Part Number, Name, and Category')
      return
    }

    if (!shopId) {
      alert('Shop not found. Please try again.')
      return
    }

    setSaving(true)
    try {
      const itemData = {
        shop_id: shopId,
        part_number: formData.part_number,
        part_name: formData.part_name,
        category: formData.category,
        brand: formData.brand,
        selling_price: Math.round(formData.selling_price * 100), // Convert to cents
        cost_price: Math.round(formData.cost_price * 100), // Convert to cents
        stock_quantity: formData.stock_quantity,
        reorder_level: formData.reorder_level,
        location: formData.location,
        condition: formData.condition,
        compatible_vehicles: formData.compatible_vehicles,
        description: formData.description,
        status: formData.stock_quantity > 0 ? 'in_stock' : 'out_of_stock',
        updated_at: new Date().toISOString(),
      }

      if (editingItem) {
        // Update existing item
        const { error } = await supabase
          .from('inventory')
          .update(itemData)
          .eq('id', editingItem.id)
          .eq('shop_id', shopId)

        if (error) throw error
      } else {
        // Create new item
        const { error } = await supabase
          .from('inventory')
          .insert({
            ...itemData,
            created_at: new Date().toISOString(),
          })

        if (error) throw error
      }

      // Reload inventory
      await loadInventory(shopId)
      setShowModal(false)
      setEditingItem(null)
      setFormData(initialItem)
    } catch (error) {
      console.error('Error saving item:', error)
      alert('Failed to save item. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  const handleDeleteItem = async (id: string) => {
    if (!confirm('Delete this inventory item?')) return
    if (!shopId) return

    try {
      const { error } = await supabase
        .from('inventory')
        .delete()
        .eq('id', id)
        .eq('shop_id', shopId)

      if (error) throw error
      
      // Reload inventory
      await loadInventory(shopId)
    } catch (error) {
      console.error('Error deleting item:', error)
      alert('Failed to delete item. Please try again.')
    }
  }

  const addVehicle = () => {
    if (vehicleInput.trim() && !formData.compatible_vehicles.includes(vehicleInput.trim())) {
      setFormData({
        ...formData,
        compatible_vehicles: [...formData.compatible_vehicles, vehicleInput.trim()]
      })
      setVehicleInput("")
    }
  }

  const removeVehicle = (vehicle: string) => {
    setFormData({
      ...formData,
      compatible_vehicles: formData.compatible_vehicles.filter(v => v !== vehicle)
    })
  }

  const exportToCSV = () => {
    const headers = ['Part Number', 'Name', 'Category', 'Brand', 'Price', 'Cost', 'Quantity', 'Location', 'Condition']
    const rows = inventory.map(item => [
      item.part_number, item.part_name, item.category, item.brand,
      item.selling_price, item.cost_price, item.stock_quantity, item.location, item.condition
    ])
    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `inventory-${new Date().toISOString().split('T')[0]}.csv`
    a.click()
  }

  // Filter inventory
  const filteredInventory = inventory.filter(item => {
    const matchesSearch = searchTerm === "" ||
      item.part_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.part_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.brand.toLowerCase().includes(searchTerm.toLowerCase())
    
    const matchesCategory = filterCategory === "" || item.category === filterCategory
    
    const matchesStock = filterStock === "all" ||
      (filterStock === "low" && item.stock_quantity <= item.reorder_level && item.stock_quantity > 0) ||
      (filterStock === "out" && item.stock_quantity === 0)

    return matchesSearch && matchesCategory && matchesStock
  })

  // Stats
  const totalValue = inventory.reduce((sum, item) => sum + (item.selling_price * item.stock_quantity), 0)
  const lowStockCount = inventory.filter(item => item.stock_quantity <= item.reorder_level && item.stock_quantity > 0).length
  const outOfStockCount = inventory.filter(item => item.stock_quantity === 0).length

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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Inventory Management</h1>
          <p className="text-gray-400 text-sm">{inventory.length} items in stock</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={exportToCSV}
            className="px-4 py-2 bg-[#1a1a1a] border border-gray-800 rounded-lg text-gray-300 hover:text-white flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export
          </button>
          <button
            onClick={() => { setEditingItem(null); setFormData(initialItem); setShowModal(true); }}
            className="px-4 py-2 bg-accent hover:bg-accent-hover text-white rounded-lg flex items-center gap-2"
          >
            <Plus className="w-4 h-4" />
            Add Item
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-accent/20 rounded-lg flex items-center justify-center">
              <Package className="w-5 h-5 text-accent" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Total Items</p>
              <p className="text-xl font-bold text-white">{inventory.length}</p>
            </div>
          </div>
        </div>
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
              <BarChart3 className="w-5 h-5 text-green-400" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Stock Value</p>
              <p className="text-xl font-bold text-green-400">R{totalValue.toLocaleString()}</p>
            </div>
          </div>
        </div>
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-yellow-500/20 rounded-lg flex items-center justify-center">
              <AlertCircle className="w-5 h-5 text-yellow-400" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Low Stock</p>
              <p className="text-xl font-bold text-yellow-400">{lowStockCount}</p>
            </div>
          </div>
        </div>
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-red-500/20 rounded-lg flex items-center justify-center">
              <X className="w-5 h-5 text-red-400" />
            </div>
            <div>
              <p className="text-gray-400 text-sm">Out of Stock</p>
              <p className="text-xl font-bold text-red-400">{outOfStockCount}</p>
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
            placeholder="Search by name, part number, or brand..."
            className="w-full bg-[#1a1a1a] text-white pl-10 pr-4 py-3 rounded-lg border border-gray-800 focus:border-accent focus:outline-none"
          />
        </div>
        <select
          value={filterCategory}
          onChange={(e) => setFilterCategory(e.target.value)}
          className="bg-[#1a1a1a] text-white px-4 py-3 rounded-lg border border-gray-800 focus:border-accent focus:outline-none"
        >
          <option value="">All Categories</option>
          {PART_CATEGORIES.map(cat => (
            <option key={cat} value={cat}>{cat}</option>
          ))}
        </select>
        <select
          value={filterStock}
          onChange={(e) => setFilterStock(e.target.value as any)}
          className="bg-[#1a1a1a] text-white px-4 py-3 rounded-lg border border-gray-800 focus:border-accent focus:outline-none"
        >
          <option value="all">All Stock</option>
          <option value="low">Low Stock</option>
          <option value="out">Out of Stock</option>
        </select>
      </div>

      {/* Inventory Table */}
      <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-800">
                <th className="text-left text-gray-400 font-medium p-4">Part #</th>
                <th className="text-left text-gray-400 font-medium p-4">Name</th>
                <th className="text-left text-gray-400 font-medium p-4">Category</th>
                <th className="text-left text-gray-400 font-medium p-4">Brand</th>
                <th className="text-right text-gray-400 font-medium p-4">Price</th>
                <th className="text-right text-gray-400 font-medium p-4">Qty</th>
                <th className="text-left text-gray-400 font-medium p-4">Status</th>
                <th className="text-right text-gray-400 font-medium p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredInventory.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-gray-500">
                    No items found
                  </td>
                </tr>
              ) : (
                filteredInventory.map((item) => (
                  <tr key={item.id} className="border-b border-gray-800 hover:bg-[#2d2d2d]">
                    <td className="p-4 font-mono text-accent">{item.part_number}</td>
                    <td className="p-4">
                      <p className="text-white font-medium">{item.part_name}</p>
                      <p className="text-gray-500 text-sm">{item.condition}</p>
                    </td>
                    <td className="p-4 text-gray-300">{item.category}</td>
                    <td className="p-4 text-gray-300">{item.brand}</td>
                    <td className="p-4 text-right text-white">R{item.selling_price.toLocaleString()}</td>
                    <td className="p-4 text-right text-white">{item.stock_quantity}</td>
                    <td className="p-4">
                      {item.stock_quantity === 0 ? (
                        <span className="px-2 py-1 bg-red-500/20 text-red-400 rounded text-xs">Out of Stock</span>
                      ) : item.stock_quantity <= item.reorder_level ? (
                        <span className="px-2 py-1 bg-yellow-500/20 text-yellow-400 rounded text-xs">Low Stock</span>
                      ) : (
                        <span className="px-2 py-1 bg-green-500/20 text-green-400 rounded text-xs">In Stock</span>
                      )}
                    </td>
                    <td className="p-4 text-right">
                      <div className="flex justify-end gap-2">
                        <button
                          onClick={() => {
                            setEditingItem(item)
                            setFormData(item)
                            setShowModal(true)
                          }}
                          className="p-2 text-gray-400 hover:text-white transition-colors"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDeleteItem(item.id)}
                          className="p-2 text-gray-400 hover:text-red-400 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add/Edit Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-2xl border border-gray-800 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-800 sticky top-0 bg-[#1a1a1a]">
              <h3 className="text-xl font-semibold text-white">
                {editingItem ? 'Edit Inventory Item' : 'Add Inventory Item'}
              </h3>
              <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Part Number *</label>
                  <input
                    type="text"
                    value={formData.part_number}
                    onChange={(e) => setFormData({ ...formData, part_number: e.target.value })}
                    placeholder="e.g., BRK-001"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Name *</label>
                  <input
                    type="text"
                    value={formData.part_name}
                    onChange={(e) => setFormData({ ...formData, part_name: e.target.value })}
                    placeholder="e.g., Brake Pads Set"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Category *</label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  >
                    <option value="">Select category</option>
                    {PART_CATEGORIES.map(cat => (
                      <option key={cat} value={cat}>{cat}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Brand</label>
                  <input
                    type="text"
                    value={formData.brand}
                    onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
                    placeholder="e.g., Bosch"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Selling Price (R)</label>
                  <input
                    type="number"
                    value={formData.selling_price || ''}
                    onChange={(e) => setFormData({ ...formData, selling_price: parseFloat(e.target.value) || 0 })}
                    placeholder="0.00"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Cost Price (R)</label>
                  <input
                    type="number"
                    value={formData.cost_price || ''}
                    onChange={(e) => setFormData({ ...formData, cost_price: parseFloat(e.target.value) || 0 })}
                    placeholder="0.00"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Condition</label>
                  <select
                    value={formData.condition}
                    onChange={(e) => setFormData({ ...formData, condition: e.target.value as any })}
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  >
                    <option value="new">New</option>
                    <option value="used">Used</option>
                    <option value="refurbished">Refurbished</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Quantity</label>
                  <input
                    type="number"
                    value={formData.stock_quantity || ''}
                    onChange={(e) => setFormData({ ...formData, stock_quantity: parseInt(e.target.value) || 0 })}
                    placeholder="0"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Min Stock Alert</label>
                  <input
                    type="number"
                    value={formData.reorder_level || ''}
                    onChange={(e) => setFormData({ ...formData, reorder_level: parseInt(e.target.value) || 0 })}
                    placeholder="5"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Location</label>
                  <input
                    type="text"
                    value={formData.location}
                    onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    placeholder="e.g., Shelf A1"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Compatible Vehicles</label>
                <div className="flex gap-2 mb-2">
                  <input
                    type="text"
                    value={vehicleInput}
                    onChange={(e) => setVehicleInput(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addVehicle())}
                    placeholder="e.g., Toyota Corolla 2018"
                    className="flex-1 bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                  <button
                    type="button"
                    onClick={addVehicle}
                    className="px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg"
                  >
                    Add
                  </button>
                </div>
                <div className="flex flex-wrap gap-2">
                  {formData.compatible_vehicles.map((vehicle) => (
                    <span key={vehicle} className="px-3 py-1 bg-[#2d2d2d] text-gray-300 rounded-full text-sm flex items-center gap-2">
                      {vehicle}
                      <button onClick={() => removeVehicle(vehicle)} className="text-gray-500 hover:text-red-400">
                        <X className="w-3 h-3" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Description</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Additional details about this part..."
                  rows={3}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none resize-none"
                />
              </div>

              {/* Profit Margin Display */}
              {formData.selling_price > 0 && formData.cost_price > 0 && (
                <div className="p-4 bg-green-500/10 border border-green-500/30 rounded-lg">
                  <p className="text-green-400 text-sm">
                    Profit Margin: R{(formData.selling_price - formData.cost_price).toFixed(2)} ({(((formData.selling_price - formData.cost_price) / formData.selling_price) * 100).toFixed(1)}%)
                  </p>
                </div>
              )}
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3 sticky bottom-0 bg-[#1a1a1a]">
              <button
                onClick={() => setShowModal(false)}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveItem}
                disabled={saving}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {saving ? (
                  <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <><Save className="w-5 h-5" /> {editingItem ? 'Update' : 'Add'} Item</>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
