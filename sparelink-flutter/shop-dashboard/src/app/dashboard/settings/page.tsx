"use client"

import { useEffect, useState, useRef } from "react"
import { 
  supabase, 
  getDeviceSessions, 
  revokeDeviceSession, 
  revokeAllOtherSessions,
  DeviceSession 
} from "@/lib/supabase"
import { Store, Clock, Truck, MapPin, Phone, Mail, Save, Loader2, Search, ShieldCheck, Lock, Shield, Smartphone, Monitor, Tablet, Trash2, LogOut } from "lucide-react"

// Google Places API routes (proxied to avoid CORS)

interface PlacePrediction {
  place_id: string
  description: string
  structured_formatting: {
    main_text: string
    secondary_text: string
  }
}

interface PlaceDetails {
  formatted_address: string
  street_number?: string
  street_name?: string
  suburb?: string
  city?: string
  province?: string
  postal_code?: string
}

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
  
  // Device sessions state (multi-device management)
  const [deviceSessions, setDeviceSessions] = useState<DeviceSession[]>([])
  const [loadingSessions, setLoadingSessions] = useState(false)
  const [revokingSession, setRevokingSession] = useState<string | null>(null)
  
  // Google Places state
  const [addressSearch, setAddressSearch] = useState("")
  const [predictions, setPredictions] = useState<PlacePrediction[]>([])
  const [showPredictions, setShowPredictions] = useState(false)
  const [searchingPlaces, setSearchingPlaces] = useState(false)
  const [addressVerified, setAddressVerified] = useState(false)
  const searchTimeoutRef = useRef<NodeJS.Timeout | null>(null)

  useEffect(() => {
    loadSettings()
  }, [])
  
  // Google Places search with debounce (using local API proxy)
  const searchPlaces = async (query: string) => {
    if (query.length < 3) {
      setPredictions([])
      setShowPredictions(false)
      return
    }
    
    setSearchingPlaces(true)
    try {
      const response = await fetch(`/api/places/autocomplete?input=${encodeURIComponent(query)}`)
      const data = await response.json()
      if (data.predictions) {
        setPredictions(data.predictions)
        setShowPredictions(true)
      }
    } catch (error) {
      console.error("Places search error:", error)
    } finally {
      setSearchingPlaces(false)
    }
  }
  
  // Handle address search input
  const handleAddressSearchChange = (value: string) => {
    setAddressSearch(value)
    setAddressVerified(false) // Reset verification on new search
    
    // Debounce the search
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchPlaces(value)
    }, 400)
  }
  
  // Get place details and extract address components (using local API proxy)
  const selectPlace = async (placeId: string, description: string) => {
    setAddressSearch(description)
    setShowPredictions(false)
    setSearchingPlaces(true)
    
    try {
      const response = await fetch(`/api/places/details?place_id=${placeId}`)
      const data = await response.json()
      
      if (data.result) {
        const components = data.result.address_components || []
        let streetNumber = ""
        let streetName = ""
        let suburb = ""
        let city = ""
        let province = ""
        let postalCode = ""
        
        for (const component of components) {
          const types = component.types || []
          if (types.includes("street_number")) {
            streetNumber = component.long_name
          } else if (types.includes("route")) {
            streetName = component.long_name
          } else if (types.includes("sublocality") || types.includes("sublocality_level_1") || types.includes("neighborhood")) {
            suburb = component.long_name
          } else if (types.includes("locality")) {
            city = component.long_name
          } else if (types.includes("administrative_area_level_1")) {
            province = component.long_name
          } else if (types.includes("postal_code")) {
            postalCode = component.long_name
          }
        }
        
        // Fallback for suburb
        if (!suburb) {
          for (const component of components) {
            if (component.types.includes("administrative_area_level_2")) {
              suburb = component.long_name
              break
            }
          }
        }
        
        // Update settings with verified data
        setSettings(prev => ({
          ...prev,
          address: data.result.formatted_address,
          street_address: streetNumber ? `${streetNumber} ${streetName}` : streetName,
          suburb: suburb,
          city: city,
          postal_code: postalCode,
        }))
        
        setAddressVerified(suburb !== "" || city !== "")
      }
    } catch (error) {
      console.error("Place details error:", error)
    } finally {
      setSearchingPlaces(false)
    }
  }

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
    { id: "security", label: "Security", icon: Shield },
  ]
  
  // Load device sessions when security tab is active
  useEffect(() => {
    if (activeTab === "security") {
      loadDeviceSessions()
    }
  }, [activeTab])
  
  const loadDeviceSessions = async () => {
    setLoadingSessions(true)
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (user) {
        const sessions = await getDeviceSessions(user.id)
        setDeviceSessions(sessions)
      }
    } catch (error) {
      console.error("Error loading sessions:", error)
    } finally {
      setLoadingSessions(false)
    }
  }
  
  const handleRevokeSession = async (sessionId: string) => {
    setRevokingSession(sessionId)
    try {
      const success = await revokeDeviceSession(sessionId)
      if (success) {
        setDeviceSessions(prev => prev.filter(s => s.id !== sessionId))
      }
    } catch (error) {
      console.error("Error revoking session:", error)
    } finally {
      setRevokingSession(null)
    }
  }
  
  const handleRevokeAllOther = async () => {
    if (!confirm("Are you sure you want to sign out all other devices?")) return
    
    setLoadingSessions(true)
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (user) {
        const success = await revokeAllOtherSessions(user.id)
        if (success) {
          setDeviceSessions(prev => prev.filter(s => s.is_current))
        }
      }
    } catch (error) {
      console.error("Error revoking sessions:", error)
    } finally {
      setLoadingSessions(false)
    }
  }
  
  const getDeviceIcon = (deviceType: string) => {
    switch (deviceType) {
      case 'mobile': return Smartphone
      case 'tablet': return Tablet
      default: return Monitor
    }
  }
  
  const formatLastActive = (dateStr: string) => {
    const date = new Date(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)
    
    if (diffMins < 1) return "Just now"
    if (diffMins < 60) return `${diffMins} min ago`
    if (diffHours < 24) return `${diffHours} hours ago`
    if (diffDays < 7) return `${diffDays} days ago`
    return date.toLocaleDateString()
  }

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
              {/* Google Places Search */}
              <div className="relative">
                <label className="block text-sm text-gray-400 mb-2">Search Address</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                  <input
                    type="text"
                    value={addressSearch}
                    onChange={(e) => handleAddressSearchChange(e.target.value)}
                    onFocus={() => predictions.length > 0 && setShowPredictions(true)}
                    placeholder="Start typing your address..."
                    className="w-full bg-[#2d2d2d] text-white pl-11 pr-10 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                  {searchingPlaces && (
                    <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-accent animate-spin" />
                  )}
                </div>
                
                {/* Predictions Dropdown */}
                {showPredictions && predictions.length > 0 && (
                  <div className="absolute z-10 w-full mt-1 bg-[#2d2d2d] border border-gray-700 rounded-lg shadow-xl max-h-64 overflow-y-auto">
                    {predictions.map((prediction) => (
                      <button
                        key={prediction.place_id}
                        onClick={() => selectPlace(prediction.place_id, prediction.description)}
                        className="w-full px-4 py-3 text-left hover:bg-[#3d3d3d] border-b border-gray-700 last:border-0 transition-colors"
                      >
                        <p className="text-white font-medium">{prediction.structured_formatting.main_text}</p>
                        <p className="text-gray-500 text-sm">{prediction.structured_formatting.secondary_text}</p>
                      </button>
                    ))}
                  </div>
                )}
              </div>
              
              {/* Verified Location Badge */}
              {addressVerified && (
                <div className="flex items-center gap-2 p-3 bg-accent/10 border border-accent/30 rounded-lg">
                  <ShieldCheck className="w-5 h-5 text-accent" />
                  <div>
                    <p className="text-accent font-medium text-sm">Location Verified</p>
                    <p className="text-gray-400 text-xs">Suburb and City are locked to Google data for accurate matching</p>
                  </div>
                </div>
              )}
              
              {/* Street Address (editable) */}
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
              
              {/* Suburb (LOCKED when verified) */}
              <div>
                <label className="flex items-center gap-2 text-sm text-gray-400 mb-2">
                  Suburb <span className="text-accent">*</span>
                  {addressVerified && <Lock className="w-3 h-3 text-gray-500" />}
                </label>
                <input
                  type="text"
                  value={settings.suburb || ""}
                  onChange={(e) => !addressVerified && setSettings({ ...settings, suburb: e.target.value })}
                  readOnly={addressVerified}
                  placeholder="Select address above to auto-fill"
                  className={`w-full px-4 py-3 rounded-lg border focus:outline-none ${
                    addressVerified 
                      ? "bg-[#1a1a1a] text-gray-400 border-accent/30 cursor-not-allowed" 
                      : "bg-[#2d2d2d] text-white border-gray-700 focus:border-accent"
                  }`}
                />
                <p className="text-xs text-gray-500 mt-1">
                  {addressVerified ? "Locked to Google verified data" : "This is used to match you with nearby mechanics"}
                </p>
              </div>
              
              {/* City and Postal Code */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="flex items-center gap-2 text-sm text-gray-400 mb-2">
                    City
                    {addressVerified && <Lock className="w-3 h-3 text-gray-500" />}
                  </label>
                  <input
                    type="text"
                    value={settings.city || ""}
                    onChange={(e) => !addressVerified && setSettings({ ...settings, city: e.target.value })}
                    readOnly={addressVerified}
                    placeholder="e.g. Johannesburg"
                    className={`w-full px-4 py-3 rounded-lg border focus:outline-none ${
                      addressVerified 
                        ? "bg-[#1a1a1a] text-gray-400 border-accent/30 cursor-not-allowed" 
                        : "bg-[#2d2d2d] text-white border-gray-700 focus:border-accent"
                    }`}
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

      {/* Security Tab */}
      {activeTab === "security" && (
        <div className="space-y-6">
          {/* Active Sessions Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-white font-medium text-lg flex items-center gap-2">
                  <Shield className="w-5 h-5 text-accent" />
                  Active Sessions
                </h3>
                <p className="text-gray-400 text-sm mt-1">
                  Manage devices where you're currently signed in
                </p>
              </div>
              {deviceSessions.length > 1 && (
                <button
                  onClick={handleRevokeAllOther}
                  disabled={loadingSessions}
                  className="flex items-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg transition-colors text-sm font-medium"
                >
                  <LogOut className="w-4 h-4" />
                  Sign out all other devices
                </button>
              )}
            </div>

            {loadingSessions ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="w-8 h-8 text-accent animate-spin" />
              </div>
            ) : deviceSessions.length === 0 ? (
              <div className="text-center py-12">
                <Monitor className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                <p className="text-gray-400">No active sessions found</p>
                <p className="text-gray-500 text-sm mt-1">Session tracking will begin on your next login</p>
              </div>
            ) : (
              <div className="space-y-3">
                {deviceSessions.map((session) => {
                  const DeviceIcon = getDeviceIcon(session.device_type)
                  return (
                    <div
                      key={session.id}
                      className={`flex items-center justify-between p-4 rounded-lg border transition-colors ${
                        session.is_current
                          ? "bg-accent/10 border-accent/30"
                          : "bg-[#2d2d2d] border-gray-700 hover:border-gray-600"
                      }`}
                    >
                      <div className="flex items-center gap-4">
                        <div className={`p-3 rounded-lg ${session.is_current ? "bg-accent/20" : "bg-[#1a1a1a]"}`}>
                          <DeviceIcon className={`w-6 h-6 ${session.is_current ? "text-accent" : "text-gray-400"}`} />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="text-white font-medium">{session.device_name}</p>
                            {session.is_current && (
                              <span className="text-xs bg-accent text-white px-2 py-0.5 rounded-full">
                                This device
                              </span>
                            )}
                          </div>
                          <div className="flex items-center gap-3 mt-1">
                            <span className="text-gray-400 text-sm">{session.browser}</span>
                            <span className="text-gray-600">•</span>
                            <span className="text-gray-400 text-sm">{session.os}</span>
                            <span className="text-gray-600">•</span>
                            <span className="text-gray-500 text-sm">
                              {session.is_current ? "Active now" : formatLastActive(session.last_active)}
                            </span>
                          </div>
                        </div>
                      </div>
                      
                      {!session.is_current && (
                        <button
                          onClick={() => handleRevokeSession(session.id)}
                          disabled={revokingSession === session.id}
                          className="flex items-center gap-2 px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg transition-colors text-sm"
                        >
                          {revokingSession === session.id ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <Trash2 className="w-4 h-4" />
                          )}
                          Revoke
                        </button>
                      )}
                    </div>
                  )
                })}
              </div>
            )}
          </div>

          {/* Security Tips */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <h3 className="text-white font-medium mb-4 flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-accent" />
              Security Tips
            </h3>
            <ul className="space-y-3">
              <li className="flex items-start gap-3 text-gray-400 text-sm">
                <span className="text-accent mt-0.5">•</span>
                <span>Sign out from devices you don't recognize immediately</span>
              </li>
              <li className="flex items-start gap-3 text-gray-400 text-sm">
                <span className="text-accent mt-0.5">•</span>
                <span>Don't share your OTP code with anyone</span>
              </li>
              <li className="flex items-start gap-3 text-gray-400 text-sm">
                <span className="text-accent mt-0.5">•</span>
                <span>Use a unique phone number for your shop account</span>
              </li>
              <li className="flex items-start gap-3 text-gray-400 text-sm">
                <span className="text-accent mt-0.5">•</span>
                <span>Regularly review active sessions and revoke old ones</span>
              </li>
            </ul>
          </div>
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
