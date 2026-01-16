"use client"

import { useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"
import { Store, Clock, Truck, MapPin, Phone, Mail, Save, Loader2 } from "lucide-react"

interface ShopSettings {
  id: string
  name: string
  phone: string
  email: string
  address: string
  street_address: string
  suburb: string
  city: string
  postal_code: string
  description: string
  working_hours: Record<string, { open: string; close: string; closed: boolean }>
  delivery_enabled: boolean
  delivery_radius_km: number
  delivery_fee: number
}

const defaultWorkingHours = {
  monday: { open: "08:00", close: "17:00", closed: false },
  tuesday: { open: "08:00", close: "17:00", closed: false },
  wednesday: { open: "08:00", close: "17:00", closed: false },
  thursday: { open: "08:00", close: "17:00", closed: false },
  friday: { open: "08:00", close: "17:00", closed: false },
  saturday: { open: "08:00", close: "13:00", closed: false },
  sunday: { open: "08:00", close: "13:00", closed: true },
}

export default function SettingsPage() {
  const [settings, setSettings] = useState<ShopSettings>({
    id: "",
    name: "",
    phone: "",
    email: "",
    address: "",
    street_address: "",
    suburb: "",
    city: "",
    postal_code: "",
    description: "",
    working_hours: defaultWorkingHours,
    delivery_enabled: true,
    delivery_radius_km: 20,
    delivery_fee: 50,
  })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [activeTab, setActiveTab] = useState("profile")

  useEffect(() => {
    loadSettings()
  }, [])

  const loadSettings = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: shop } = await supabase
        .from("shops")
        .select("*")
        .eq("owner_id", user.id)
        .single()

      if (shop) {
        setSettings({
          ...settings,
          ...shop,
          working_hours: shop.working_hours || defaultWorkingHours,
        })
      }
    } catch (error) {
      console.error("Error loading settings:", error)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    // Validate suburb is required
    if (!settings.suburb || !settings.suburb.trim()) {
      alert("Suburb is required for mechanics to find your shop!")
      return
    }
    
    setSaving(true)
    try {
      // Get current user for profile update
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        alert("You must be logged in to save settings")
        setSaving(false)
        return
      }

      // Log what we're saving for debugging
      console.log("Saving shop settings:", {
        id: settings.id,
        name: settings.name,
        suburb: settings.suburb,
        working_hours: settings.working_hours,
      })

      // Prepare shop data - handle empty values as null
      const shopData = {
        name: settings.name || null,
        phone: settings.phone || null,
        email: settings.email || null,
        address: settings.address || null,
        street_address: settings.street_address || null,
        suburb: settings.suburb, // Required, already validated
        city: settings.city || null,
        postal_code: settings.postal_code || null,
        description: settings.description || null,
        // Working hours: ensure it's a valid object, use default if empty
        working_hours: settings.working_hours && Object.keys(settings.working_hours).length > 0 
          ? settings.working_hours 
          : defaultWorkingHours,
        // Delivery settings: use defaults if not set
        delivery_enabled: settings.delivery_enabled ?? false,
        delivery_radius_km: settings.delivery_radius_km ?? 0,
        delivery_fee: settings.delivery_fee ?? 0,
        updated_at: new Date().toISOString(),
      }

      // STEP 1: Update the SHOPS table
      const { data: shopResult, error: shopError } = await supabase
        .from("shops")
        .update(shopData)
        .eq("id", settings.id)
        .select()

      if (shopError) {
        console.error("Supabase shop error:", shopError)
        // Check for specific error types
        if (shopError.message.includes("column") && shopError.message.includes("does not exist")) {
          alert(`Database error: Some columns are missing in the shops table. Please run the database migration (add_missing_columns_migration.sql).\n\nError: ${shopError.message}`)
        } else if (shopError.code === "42501" || shopError.message.includes("permission")) {
          alert(`Permission error: You don't have permission to update shop settings.\n\nError: ${shopError.message}`)
        } else {
          alert(`Failed to save shop settings: ${shopError.message}`)
        }
        return
      }

      console.log("Shop save successful:", shopResult)

      // STEP 2: Update the PROFILES table (owner's profile with address info)
      const profileData = {
        phone: settings.phone || null,
        street_address: settings.street_address || null,
        suburb: settings.suburb, // Required
        city: settings.city || null,
        postal_code: settings.postal_code || null,
        updated_at: new Date().toISOString(),
      }

      const { data: profileResult, error: profileError } = await supabase
        .from("profiles")
        .update(profileData)
        .eq("id", user.id)
        .select()

      if (profileError) {
        // Profile update is secondary - log but don't fail the whole save
        console.warn("Profile update warning:", profileError)
        // Still show success since shop was saved
        alert("Shop settings saved! (Note: Profile sync had an issue - this is not critical)")
      } else {
        console.log("Profile save successful:", profileResult)
        alert("Settings saved successfully to both shop and profile!")
      }

    } catch (error: any) {
      console.error("Error saving settings:", error)
      alert(`Failed to save settings: ${error?.message || 'Unknown error'}`)
    } finally {
      setSaving(false)
    }
  }

  const updateWorkingHours = (day: string, field: string, value: string | boolean) => {
    setSettings({
      ...settings,
      working_hours: {
        ...settings.working_hours,
        [day]: { ...settings.working_hours[day], [field]: value }
      }
    })
  }

  const tabs = [
    { id: "profile", label: "Shop Profile", icon: Store },
    { id: "hours", label: "Working Hours", icon: Clock },
    { id: "delivery", label: "Delivery", icon: Truck },
  ]

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Tabs */}
      <div className="flex gap-2 border-b border-gray-800 pb-4">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors ${
              activeTab === tab.id ? "bg-accent text-white" : "text-gray-400 hover:text-white hover:bg-[#1a1a1a]"
            }`}
          >
            <tab.icon className="w-5 h-5" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Profile Tab */}
      {activeTab === "profile" && (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6 space-y-6">
          <div>
            <label className="block text-sm text-gray-400 mb-2">Shop Name</label>
            <input
              type="text"
              value={settings.name}
              onChange={(e) => setSettings({ ...settings, name: e.target.value })}
              className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
            />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Phone</label>
              <div className="relative">
                <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="tel"
                  value={settings.phone}
                  onChange={(e) => setSettings({ ...settings, phone: e.target.value })}
                  className="w-full bg-[#2d2d2d] text-white pl-11 pr-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Email</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="email"
                  value={settings.email || ""}
                  onChange={(e) => setSettings({ ...settings, email: e.target.value })}
                  className="w-full bg-[#2d2d2d] text-white pl-11 pr-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
            </div>
          </div>
          {/* Physical Address Section */}
          <div className="pt-4 border-t border-gray-800">
            <div className="flex items-center gap-2 mb-4">
              <MapPin className="w-5 h-5 text-accent" />
              <h3 className="text-white font-medium">Physical Address</h3>
              <span className="text-xs bg-accent/20 text-accent px-2 py-1 rounded">Required for matching</span>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Street Address</label>
                <input
                  type="text"
                  value={settings.street_address || ""}
                  onChange={(e) => setSettings({ ...settings, street_address: e.target.value })}
                  placeholder="e.g. 123 Main Road"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              
              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Suburb <span className="text-accent">*</span>
                </label>
                <input
                  type="text"
                  value={settings.suburb || ""}
                  onChange={(e) => setSettings({ ...settings, suburb: e.target.value })}
                  placeholder="e.g. Sandton, Rosebank, Midrand"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
                <p className="text-xs text-gray-500 mt-1">This is used to match you with nearby mechanics</p>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">City</label>
                  <input
                    type="text"
                    value={settings.city || ""}
                    onChange={(e) => setSettings({ ...settings, city: e.target.value })}
                    placeholder="e.g. Johannesburg"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Postal Code</label>
                  <input
                    type="text"
                    value={settings.postal_code || ""}
                    onChange={(e) => setSettings({ ...settings, postal_code: e.target.value })}
                    placeholder="e.g. 2000"
                    className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>
            </div>
          </div>
          <div>
            <label className="block text-sm text-gray-400 mb-2">Description</label>
            <textarea
              value={settings.description || ""}
              onChange={(e) => setSettings({ ...settings, description: e.target.value })}
              rows={3}
              placeholder="Tell customers about your shop..."
              className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none resize-none"
            />
          </div>
        </div>
      )}

      {/* Working Hours Tab */}
      {activeTab === "hours" && (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
          <div className="space-y-4">
            {Object.entries(settings.working_hours).map(([day, hours]) => (
              <div key={day} className="flex items-center gap-4 py-3 border-b border-gray-800 last:border-0">
                <div className="w-28">
                  <span className="text-white capitalize font-medium">{day}</span>
                </div>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={!hours.closed}
                    onChange={(e) => updateWorkingHours(day, "closed", !e.target.checked)}
                    className="w-5 h-5 rounded bg-[#2d2d2d] border-gray-700 text-accent focus:ring-accent"
                  />
                  <span className="text-gray-400 text-sm">Open</span>
                </label>
                {!hours.closed && (
                  <>
                    <input
                      type="time"
                      value={hours.open}
                      onChange={(e) => updateWorkingHours(day, "open", e.target.value)}
                      className="bg-[#2d2d2d] text-white px-3 py-2 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                    />
                    <span className="text-gray-500">to</span>
                    <input
                      type="time"
                      value={hours.close}
                      onChange={(e) => updateWorkingHours(day, "close", e.target.value)}
                      className="bg-[#2d2d2d] text-white px-3 py-2 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                    />
                  </>
                )}
                {hours.closed && <span className="text-gray-500">Closed</span>}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Delivery Tab */}
      {activeTab === "delivery" && (
        <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6 space-y-6">
          <div className="flex items-center justify-between p-4 bg-[#2d2d2d] rounded-lg">
            <div>
              <h3 className="text-white font-medium">Enable Delivery</h3>
              <p className="text-gray-400 text-sm">Offer delivery to customers</p>
            </div>
            <button
              onClick={() => setSettings({ ...settings, delivery_enabled: !settings.delivery_enabled })}
              className={`w-14 h-8 rounded-full transition-colors ${settings.delivery_enabled ? "bg-accent" : "bg-gray-600"}`}
            >
              <div className={`w-6 h-6 bg-white rounded-full transition-transform ${settings.delivery_enabled ? "translate-x-7" : "translate-x-1"}`} />
            </button>
          </div>

          {settings.delivery_enabled && (
            <>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Delivery Radius (km)</label>
                <input
                  type="number"
                  value={settings.delivery_radius_km}
                  onChange={(e) => setSettings({ ...settings, delivery_radius_km: parseInt(e.target.value) || 0 })}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Delivery Fee (ZAR)</label>
                <input
                  type="number"
                  value={settings.delivery_fee}
                  onChange={(e) => setSettings({ ...settings, delivery_fee: parseInt(e.target.value) || 0 })}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
            </>
          )}
        </div>
      )}

      {/* Save Button */}
      <button
        onClick={handleSave}
        disabled={saving}
        className="w-full bg-accent hover:bg-accent-hover text-white font-medium py-3 px-4 rounded-xl flex items-center justify-center gap-2 transition-colors disabled:opacity-50"
      >
        {saving ? <Loader2 className="w-5 h-5 animate-spin" /> : <><Save className="w-5 h-5" /> Save Changes</>}
      </button>
    </div>
  )
}
