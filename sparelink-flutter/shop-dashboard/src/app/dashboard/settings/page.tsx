"use client"

import { useEffect, useState, useRef } from "react"
import { 
  supabase, 
  getDeviceSessions, 
  revokeDeviceSession, 
  revokeAllOtherSessions,
  DeviceSession 
} from "@/lib/supabase"
import { Store, Clock, Truck, MapPin, Phone, Mail, Save, Loader2, Search, ShieldCheck, Lock, Shield, Smartphone, Monitor, Tablet, Trash2, LogOut, Users, UserPlus, X, Calendar, Plus, Edit2, Check, AlertTriangle, Camera, Globe, Facebook, Instagram, Twitter } from "lucide-react"

// Photon API for address autocomplete (same as Flutter app)
const PHOTON_BASE_URL = 'https://photon.komoot.io'

interface PhotonResult {
  properties: {
    name?: string
    street?: string
    housenumber?: string
    city?: string
    state?: string
    postcode?: string
    country?: string
  }
  geometry: {
    coordinates: [number, number]
  }
}

interface StaffMember {
  id: string
  email: string
  name: string
  role: 'admin' | 'staff'
  status: 'active' | 'pending' | 'inactive'
  invited_at: string
  last_active?: string
}

interface Holiday {
  id: string
  date: string
  name: string
  recurring: boolean
}

// Legacy Google Places interfaces (keeping for compatibility)
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
  // New profile fields
  logo_url: string
  banner_url: string
  website: string
  facebook: string
  instagram: string
  twitter: string
  specialties: string[]
  payment_methods: string[]
  registration_number: string
  vat_number: string
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
    // New profile fields
    logo_url: "",
    banner_url: "",
    website: "",
    facebook: "",
    instagram: "",
    twitter: "",
    specialties: [],
    payment_methods: [],
    registration_number: "",
    vat_number: "",
  })
  
  // Image upload state
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [uploadingBanner, setUploadingBanner] = useState(false)
  const logoInputRef = useRef<HTMLInputElement>(null)
  const bannerInputRef = useRef<HTMLInputElement>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [activeTab, setActiveTab] = useState("profile")
  
  // Device sessions state (multi-device management)
  const [deviceSessions, setDeviceSessions] = useState<DeviceSession[]>([])
  const [loadingSessions, setLoadingSessions] = useState(false)
  const [revokingSession, setRevokingSession] = useState<string | null>(null)
  
  // Photon address autocomplete state
  const [addressSearch, setAddressSearch] = useState("")
  const [addressResults, setAddressResults] = useState<PhotonResult[]>([])
  const [searchingAddress, setSearchingAddress] = useState(false)
  const [showAddressDropdown, setShowAddressDropdown] = useState(false)
  const addressTimeoutRef = useRef<NodeJS.Timeout | null>(null)
  
  // Staff management state
  const [staffMembers, setStaffMembers] = useState<StaffMember[]>([])
  const [showInviteModal, setShowInviteModal] = useState(false)
  const [inviteEmail, setInviteEmail] = useState("")
  const [inviteName, setInviteName] = useState("")
  const [inviteRole, setInviteRole] = useState<'admin' | 'staff'>('staff')
  const [inviting, setInviting] = useState(false)
  
  // Holiday calendar state
  const [holidays, setHolidays] = useState<Holiday[]>([])
  const [showHolidayModal, setShowHolidayModal] = useState(false)
  const [newHoliday, setNewHoliday] = useState({ date: "", name: "", recurring: false })
  const [editingHoliday, setEditingHoliday] = useState<Holiday | null>(null)
  
  useEffect(() => {
    loadSettings()
    loadStaffMembers()
    loadHolidays()
  }, [])

  const loadStaffMembers = () => {
    try {
      const saved = localStorage.getItem('sparelink-staff-members')
      if (saved) setStaffMembers(JSON.parse(saved))
    } catch (e) {
      console.error('Error loading staff:', e)
    }
  }

  const loadHolidays = () => {
    try {
      const saved = localStorage.getItem('sparelink-holidays')
      if (saved) setHolidays(JSON.parse(saved))
    } catch (e) {
      console.error('Error loading holidays:', e)
    }
  }
  
  // Photon address search (same as Flutter app)
  const searchPhotonAddress = async (query: string) => {
    if (query.length < 3) {
      setAddressResults([])
      setShowAddressDropdown(false)
      return
    }

    setSearchingAddress(true)
    try {
      // Bias results towards South Africa
      const response = await fetch(
        `${PHOTON_BASE_URL}/api/?q=${encodeURIComponent(query)}&limit=5&lat=-26.2041&lon=28.0473`
      )
      const data = await response.json()
      setAddressResults(data.features || [])
      setShowAddressDropdown(true)
    } catch (error) {
      console.error('Photon search error:', error)
      setAddressResults([])
    } finally {
      setSearchingAddress(false)
    }
  }

  // Handle address input change with debounce
  const handleAddressInputChange = (value: string) => {
    setAddressSearch(value)
    
    if (addressTimeoutRef.current) {
      clearTimeout(addressTimeoutRef.current)
    }
    
    addressTimeoutRef.current = setTimeout(() => {
      searchPhotonAddress(value)
    }, 300)
  }

  // Select address from Photon results
  const selectPhotonAddress = (result: PhotonResult) => {
    const props = result.properties
    const streetNumber = props.housenumber || ''
    const street = props.street || props.name || ''
    const city = props.city || ''
    const state = props.state || ''
    const postcode = props.postcode || ''
    
    const fullAddress = [
      streetNumber && street ? `${streetNumber} ${street}` : street,
      city,
      state,
      postcode
    ].filter(Boolean).join(', ')

    setSettings(prev => ({
      ...prev,
      address: fullAddress,
      street_address: streetNumber && street ? `${streetNumber} ${street}` : street,
      suburb: '',
      city: city,
      postal_code: postcode
    }))
    
    setAddressSearch(fullAddress)
    setShowAddressDropdown(false)
    setAddressResults([])
  }

  // Format Photon result for display
  const formatPhotonResult = (result: PhotonResult): string => {
    const props = result.properties
    const parts = [
      props.housenumber && props.street ? `${props.housenumber} ${props.street}` : props.street || props.name,
      props.city,
      props.state,
      props.postcode
    ].filter(Boolean)
    return parts.join(', ')
  }

  // Staff management functions
  const handleInviteStaff = () => {
    if (!inviteEmail || !inviteName) {
      alert('Please enter email and name')
      return
    }

    const newStaff: StaffMember = {
      id: Date.now().toString(),
      email: inviteEmail,
      name: inviteName,
      role: inviteRole,
      status: 'pending',
      invited_at: new Date().toISOString()
    }

    const updated = [...staffMembers, newStaff]
    setStaffMembers(updated)
    localStorage.setItem('sparelink-staff-members', JSON.stringify(updated))
    
    setShowInviteModal(false)
    setInviteEmail('')
    setInviteName('')
    setInviteRole('staff')
  }

  const updateStaffRole = (staffId: string, newRole: 'admin' | 'staff') => {
    const updated = staffMembers.map(s => 
      s.id === staffId ? { ...s, role: newRole } : s
    )
    setStaffMembers(updated)
    localStorage.setItem('sparelink-staff-members', JSON.stringify(updated))
  }

  const removeStaffMember = (staffId: string) => {
    if (confirm('Remove this team member?')) {
      const updated = staffMembers.filter(s => s.id !== staffId)
      setStaffMembers(updated)
      localStorage.setItem('sparelink-staff-members', JSON.stringify(updated))
    }
  }

  // Holiday calendar functions
  const handleSaveHoliday = () => {
    if (!newHoliday.date || !newHoliday.name) {
      alert('Please enter date and name')
      return
    }

    let updated: Holiday[]
    if (editingHoliday) {
      updated = holidays.map(h => 
        h.id === editingHoliday.id ? { ...newHoliday, id: editingHoliday.id } : h
      )
    } else {
      updated = [...holidays, { ...newHoliday, id: Date.now().toString() }]
    }

    setHolidays(updated)
    localStorage.setItem('sparelink-holidays', JSON.stringify(updated))
    setShowHolidayModal(false)
    setNewHoliday({ date: '', name: '', recurring: false })
    setEditingHoliday(null)
  }

  const deleteHoliday = (holidayId: string) => {
    if (confirm('Delete this holiday?')) {
      const updated = holidays.filter(h => h.id !== holidayId)
      setHolidays(updated)
      localStorage.setItem('sparelink-holidays', JSON.stringify(updated))
    }
  }

  
  // Get place details and extract address components (using local API proxy)
  const selectPlace = async (placeId: string, description: string) => {
    setAddressSearch(description)
    setShowAddressDropdown(false)
    setSearchingAddress(true)
    
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
        
      }
    } catch (error) {
      console.error("Place details error:", error)
    } finally {
      setSearchingAddress(false)
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
    { id: "team", label: "Team", icon: Users },
    { id: "holidays", label: "Holidays", icon: Calendar },
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

  // Handle logo upload
  const handleLogoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.startsWith('image/')) {
      alert('Please upload an image file')
      return
    }

    if (file.size > 5 * 1024 * 1024) {
      alert('Image must be less than 5MB')
      return
    }

    setUploadingLogo(true)
    try {
      const fileExt = file.name.split('.').pop()
      const fileName = `shop-logo-${settings.id}-${Date.now()}.${fileExt}`
      const filePath = `shop-logos/${fileName}`

      const { error: uploadError } = await supabase.storage
        .from('shop-assets')
        .upload(filePath, file, { upsert: true })

      if (uploadError) throw uploadError

      const { data: { publicUrl } } = supabase.storage
        .from('shop-assets')
        .getPublicUrl(filePath)

      setSettings(prev => ({ ...prev, logo_url: publicUrl }))
      
      // Save to database
      await supabase
        .from('shops')
        .update({ logo_url: publicUrl })
        .eq('id', settings.id)

    } catch (error) {
      console.error('Logo upload error:', error)
      alert('Failed to upload logo. Please try again.')
    } finally {
      setUploadingLogo(false)
    }
  }

  // Handle banner upload
  const handleBannerUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.type.startsWith('image/')) {
      alert('Please upload an image file')
      return
    }

    if (file.size > 10 * 1024 * 1024) {
      alert('Image must be less than 10MB')
      return
    }

    setUploadingBanner(true)
    try {
      const fileExt = file.name.split('.').pop()
      const fileName = `shop-banner-${settings.id}-${Date.now()}.${fileExt}`
      const filePath = `shop-banners/${fileName}`

      const { error: uploadError } = await supabase.storage
        .from('shop-assets')
        .upload(filePath, file, { upsert: true })

      if (uploadError) throw uploadError

      const { data: { publicUrl } } = supabase.storage
        .from('shop-assets')
        .getPublicUrl(filePath)

      setSettings(prev => ({ ...prev, banner_url: publicUrl }))
      
      // Save to database
      await supabase
        .from('shops')
        .update({ banner_url: publicUrl })
        .eq('id', settings.id)

    } catch (error) {
      console.error('Banner upload error:', error)
      alert('Failed to upload banner. Please try again.')
    } finally {
      setUploadingBanner(false)
    }
  }

  // Specialty options
  const SPECIALTY_OPTIONS = [
    'Engine Repairs', 'Brake Systems', 'Transmission', 'Electrical',
    'Suspension', 'Body Work', 'Air Conditioning', 'Diagnostics',
    'German Cars', 'Japanese Cars', 'American Cars', 'Luxury Vehicles',
    'Commercial Vehicles', 'Diesel Specialists', '4x4 Specialists'
  ]

  // Payment method options
  const PAYMENT_OPTIONS = [
    'Cash', 'Card', 'EFT', 'SnapScan', 'Zapper', 'PayFast', 'Account'
  ]

  const toggleSpecialty = (specialty: string) => {
    setSettings(prev => ({
      ...prev,
      specialties: prev.specialties.includes(specialty)
        ? prev.specialties.filter(s => s !== specialty)
        : [...prev.specialties, specialty]
    }))
  }

  const togglePaymentMethod = (method: string) => {
    setSettings(prev => ({
      ...prev,
      payment_methods: prev.payment_methods.includes(method)
        ? prev.payment_methods.filter(m => m !== method)
        : [...prev.payment_methods, method]
    }))
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
        <div className="space-y-6">
          {/* Shop Logo & Banner Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
              <Camera className="w-5 h-5 text-accent" />
              Shop Branding
            </h3>
            
            {/* Banner Upload */}
            <div className="mb-6">
              <label className="block text-sm text-gray-400 mb-2">Cover Banner</label>
              <div 
                className="relative h-40 bg-[#2d2d2d] rounded-xl border-2 border-dashed border-gray-700 hover:border-accent transition-colors cursor-pointer overflow-hidden"
                onClick={() => bannerInputRef.current?.click()}
              >
                {settings.banner_url ? (
                  <img src={settings.banner_url} alt="Shop Banner" className="w-full h-full object-cover" />
                ) : (
                  <div className="absolute inset-0 flex flex-col items-center justify-center">
                    <Camera className="w-8 h-8 text-gray-500 mb-2" />
                    <p className="text-gray-500 text-sm">Click to upload banner (1200x400 recommended)</p>
                  </div>
                )}
                {uploadingBanner && (
                  <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                    <Loader2 className="w-8 h-8 text-accent animate-spin" />
                  </div>
                )}
              </div>
              <input
                ref={bannerInputRef}
                type="file"
                accept="image/*"
                onChange={handleBannerUpload}
                className="hidden"
              />
            </div>

            {/* Logo Upload */}
            <div className="flex items-start gap-6">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Shop Logo</label>
                <div 
                  className="relative w-32 h-32 bg-[#2d2d2d] rounded-xl border-2 border-dashed border-gray-700 hover:border-accent transition-colors cursor-pointer overflow-hidden"
                  onClick={() => logoInputRef.current?.click()}
                >
                  {settings.logo_url ? (
                    <img src={settings.logo_url} alt="Shop Logo" className="w-full h-full object-cover" />
                  ) : (
                    <div className="absolute inset-0 flex flex-col items-center justify-center">
                      <Store className="w-8 h-8 text-gray-500 mb-1" />
                      <p className="text-gray-500 text-xs text-center px-2">Upload Logo</p>
                    </div>
                  )}
                  {uploadingLogo && (
                    <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                      <Loader2 className="w-6 h-6 text-accent animate-spin" />
                    </div>
                  )}
                </div>
                <input
                  ref={logoInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleLogoUpload}
                  className="hidden"
                />
                <p className="text-xs text-gray-500 mt-2">Square image, max 5MB</p>
              </div>
              <div className="flex-1">
                <p className="text-gray-400 text-sm mb-3">Your shop logo appears on quotes, invoices, and your public profile.</p>
                <div className="p-3 bg-accent/10 border border-accent/30 rounded-lg">
                  <p className="text-accent text-sm font-medium">Tip: Use a high-quality logo</p>
                  <p className="text-gray-400 text-xs mt-1">A professional logo helps build trust with mechanics.</p>
                </div>
              </div>
            </div>
          </div>

          {/* Basic Info Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6 space-y-6">
            <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
              <Store className="w-5 h-5 text-accent" />
              Basic Information
            </h3>
            
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
              {/* Photon Address Search (same as Flutter app) */}
              <div className="relative">
                <label className="block text-sm text-gray-400 mb-2">Search Address</label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                  <input
                    type="text"
                    value={addressSearch}
                    onChange={(e) => handleAddressInputChange(e.target.value)}
                    onFocus={() => addressResults.length > 0 && setShowAddressDropdown(true)}
                    placeholder="Start typing your address..."
                    className="w-full bg-[#2d2d2d] text-white pl-11 pr-10 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                  {searchingAddress && (
                    <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-accent animate-spin" />
                  )}
                </div>
                
                {/* Photon Address Results Dropdown */}
                {showAddressDropdown && addressResults.length > 0 && (
                  <div className="absolute z-10 w-full mt-1 bg-[#2d2d2d] border border-gray-700 rounded-lg shadow-xl max-h-64 overflow-y-auto">
                    {addressResults.map((result, index) => (
                      <button
                        key={index}
                        onClick={() => selectPhotonAddress(result)}
                        className="w-full px-4 py-3 text-left hover:bg-[#3d3d3d] border-b border-gray-700 last:border-0 transition-colors"
                      >
                        <p className="text-white font-medium">{formatPhotonResult(result)}</p>
                        <p className="text-gray-500 text-sm">{result.properties.country || 'South Africa'}</p>
                      </button>
                    ))}
                  </div>
                )}
              </div>
              
              {/* Address Selected Info */}
              {settings.address && (
                <div className="flex items-center gap-2 p-3 bg-accent/10 border border-accent/30 rounded-lg">
                  <ShieldCheck className="w-5 h-5 text-accent" />
                  <div>
                    <p className="text-accent font-medium text-sm">Address Selected</p>
                    <p className="text-gray-400 text-xs">Using Photon geocoding (same as mobile app) for accurate matching</p>
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
                </label>
                <input
                  type="text"
                  value={settings.suburb || ""}
                  onChange={(e) => setSettings({ ...settings, suburb: e.target.value })}
                  placeholder="Select address above or enter manually"
                  className="w-full px-4 py-3 rounded-lg border focus:outline-none bg-[#2d2d2d] text-white border-gray-700 focus:border-accent"
                />
                <p className="text-xs text-gray-500 mt-1">
                  This is used to match you with nearby mechanics
                </p>
              </div>
              
              {/* City and Postal Code */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="flex items-center gap-2 text-sm text-gray-400 mb-2">
                    City
                  </label>
                  <input
                    type="text"
                    value={settings.city || ""}
                    onChange={(e) => setSettings({ ...settings, city: e.target.value })}
                    placeholder="e.g. Johannesburg"
                    className="w-full px-4 py-3 rounded-lg border focus:outline-none bg-[#2d2d2d] text-white border-gray-700 focus:border-accent"
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

          {/* Social Media & Website Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6 space-y-4">
            <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
              <Globe className="w-5 h-5 text-accent" />
              Online Presence
            </h3>
            
            <div>
              <label className="block text-sm text-gray-400 mb-2">Website</label>
              <div className="relative">
                <Globe className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="url"
                  value={settings.website || ""}
                  onChange={(e) => setSettings({ ...settings, website: e.target.value })}
                  placeholder="https://www.yourshop.co.za"
                  className="w-full bg-[#2d2d2d] text-white pl-11 pr-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Facebook</label>
                <div className="relative">
                  <Facebook className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-blue-500" />
                  <input
                    type="text"
                    value={settings.facebook || ""}
                    onChange={(e) => setSettings({ ...settings, facebook: e.target.value })}
                    placeholder="facebook.com/yourshop"
                    className="w-full bg-[#2d2d2d] text-white pl-11 pr-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Instagram</label>
                <div className="relative">
                  <Instagram className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-pink-500" />
                  <input
                    type="text"
                    value={settings.instagram || ""}
                    onChange={(e) => setSettings({ ...settings, instagram: e.target.value })}
                    placeholder="@yourshop"
                    className="w-full bg-[#2d2d2d] text-white pl-11 pr-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Twitter / X</label>
                <div className="relative">
                  <Twitter className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-sky-500" />
                  <input
                    type="text"
                    value={settings.twitter || ""}
                    onChange={(e) => setSettings({ ...settings, twitter: e.target.value })}
                    placeholder="@yourshop"
                    className="w-full bg-[#2d2d2d] text-white pl-11 pr-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Specialties Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Shop Specialties</h3>
            <p className="text-gray-400 text-sm mb-4">Select the services and vehicle types you specialize in</p>
            <div className="flex flex-wrap gap-2">
              {SPECIALTY_OPTIONS.map((specialty) => (
                <button
                  key={specialty}
                  onClick={() => toggleSpecialty(specialty)}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                    settings.specialties.includes(specialty)
                      ? 'bg-accent text-white'
                      : 'bg-[#2d2d2d] text-gray-400 hover:text-white hover:bg-[#3d3d3d]'
                  }`}
                >
                  {specialty}
                </button>
              ))}
            </div>
          </div>

          {/* Payment Methods Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Accepted Payment Methods</h3>
            <p className="text-gray-400 text-sm mb-4">Let customers know how they can pay</p>
            <div className="flex flex-wrap gap-2">
              {PAYMENT_OPTIONS.map((method) => (
                <button
                  key={method}
                  onClick={() => togglePaymentMethod(method)}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                    settings.payment_methods.includes(method)
                      ? 'bg-green-500 text-white'
                      : 'bg-[#2d2d2d] text-gray-400 hover:text-white hover:bg-[#3d3d3d]'
                  }`}
                >
                  {method}
                </button>
              ))}
            </div>
          </div>

          {/* Business Registration Section */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6 space-y-4">
            <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-accent" />
              Business Registration
            </h3>
            <p className="text-gray-400 text-sm mb-4">Optional: Add your business registration details for professional invoices</p>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Company Registration Number</label>
                <input
                  type="text"
                  value={settings.registration_number || ""}
                  onChange={(e) => setSettings({ ...settings, registration_number: e.target.value })}
                  placeholder="e.g., 2024/123456/07"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">VAT Number</label>
                <input
                  type="text"
                  value={settings.vat_number || ""}
                  onChange={(e) => setSettings({ ...settings, vat_number: e.target.value })}
                  placeholder="e.g., 4123456789"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
            </div>
            
            <div className="p-3 bg-blue-500/10 border border-blue-500/30 rounded-lg">
              <p className="text-blue-400 text-sm">These details will appear on your invoices and quotes for tax purposes.</p>
            </div>
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

      {/* Team Tab */}
      {activeTab === "team" && (
        <div className="space-y-6">
          {/* Team Header */}
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-lg font-semibold text-white">Team Members</h3>
                <p className="text-gray-400 text-sm">Manage staff access to your dashboard</p>
              </div>
              <button
                onClick={() => setShowInviteModal(true)}
                className="px-4 py-2 bg-accent hover:bg-accent-hover text-white rounded-lg flex items-center gap-2 transition-colors"
              >
                <UserPlus className="w-4 h-4" />
                Invite Member
              </button>
            </div>

            {/* Roles Explanation */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div className="p-4 bg-purple-500/10 border border-purple-500/30 rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Shield className="w-5 h-5 text-purple-400" />
                  <h4 className="text-purple-400 font-medium">Admin</h4>
                </div>
                <p className="text-gray-400 text-sm">Full access to all settings, can manage team members, view analytics, and modify shop profile.</p>
              </div>
              <div className="p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Users className="w-5 h-5 text-blue-400" />
                  <h4 className="text-blue-400 font-medium">Staff</h4>
                </div>
                <p className="text-gray-400 text-sm">Can respond to quotes, manage chats, and update order status. Cannot modify settings or invite members.</p>
              </div>
            </div>

            {/* Staff List */}
            {staffMembers.length === 0 ? (
              <div className="text-center py-8">
                <Users className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                <p className="text-gray-400">No team members yet</p>
                <p className="text-gray-500 text-sm">Invite staff to help manage your shop</p>
              </div>
            ) : (
              <div className="space-y-3">
                {staffMembers.map((member) => (
                  <div key={member.id} className="flex items-center justify-between p-4 bg-[#2d2d2d] rounded-lg">
                    <div className="flex items-center gap-3">
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center ${member.role === 'admin' ? 'bg-purple-500/20' : 'bg-blue-500/20'}`}>
                        {member.role === 'admin' ? (
                          <Shield className="w-5 h-5 text-purple-400" />
                        ) : (
                          <Users className="w-5 h-5 text-blue-400" />
                        )}
                      </div>
                      <div>
                        <p className="text-white font-medium">{member.name}</p>
                        <p className="text-gray-400 text-sm">{member.email}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className={`px-2 py-1 rounded text-xs ${member.status === 'active' ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'}`}>
                        {member.status}
                      </span>
                      <select
                        value={member.role}
                        onChange={(e) => updateStaffRole(member.id, e.target.value as 'admin' | 'staff')}
                        className="bg-[#1a1a1a] text-white px-3 py-1.5 rounded-lg border border-gray-700 text-sm"
                      >
                        <option value="staff">Staff</option>
                        <option value="admin">Admin</option>
                      </select>
                      <button
                        onClick={() => removeStaffMember(member.id)}
                        className="p-2 text-gray-400 hover:text-red-400 transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Holidays Tab */}
      {activeTab === "holidays" && (
        <div className="space-y-6">
          <div className="bg-[#1a1a1a] rounded-xl border border-gray-800 p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-lg font-semibold text-white">Holiday Calendar</h3>
                <p className="text-gray-400 text-sm">Mark dates when your shop is closed</p>
              </div>
              <button
                onClick={() => { setEditingHoliday(null); setNewHoliday({ date: '', name: '', recurring: false }); setShowHolidayModal(true); }}
                className="px-4 py-2 bg-accent hover:bg-accent-hover text-white rounded-lg flex items-center gap-2 transition-colors"
              >
                <Plus className="w-4 h-4" />
                Add Holiday
              </button>
            </div>

            {/* Info Box */}
            <div className="p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg mb-6">
              <div className="flex items-start gap-3">
                <AlertTriangle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-blue-400 font-medium">Quiet Hours</p>
                  <p className="text-gray-400 text-sm">On holidays, mechanics will see a notice that you may have delayed responses. No auto-matching will occur on these dates.</p>
                </div>
              </div>
            </div>

            {/* Holiday List */}
            {holidays.length === 0 ? (
              <div className="text-center py-8">
                <Calendar className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                <p className="text-gray-400">No holidays scheduled</p>
                <p className="text-gray-500 text-sm">Add holidays to inform mechanics of your availability</p>
              </div>
            ) : (
              <div className="space-y-3">
                {holidays.sort((a, b) => a.date.localeCompare(b.date)).map((holiday) => (
                  <div key={holiday.id} className="flex items-center justify-between p-4 bg-[#2d2d2d] rounded-lg">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-red-500/20 rounded-lg flex items-center justify-center">
                        <Calendar className="w-5 h-5 text-red-400" />
                      </div>
                      <div>
                        <p className="text-white font-medium">{holiday.name}</p>
                        <p className="text-gray-400 text-sm">
                          {new Date(holiday.date).toLocaleDateString('en-ZA', { day: 'numeric', month: 'long', year: holiday.recurring ? undefined : 'numeric' })}
                          {holiday.recurring && <span className="ml-2 text-yellow-400">(Every year)</span>}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => { setEditingHoliday(holiday); setNewHoliday(holiday); setShowHolidayModal(true); }}
                        className="p-2 text-gray-400 hover:text-white transition-colors"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => deleteHoliday(holiday.id)}
                        className="p-2 text-gray-400 hover:text-red-400 transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Common SA Holidays Quick Add */}
            <div className="mt-6 pt-6 border-t border-gray-800">
              <p className="text-gray-400 text-sm mb-3">Quick add South African public holidays:</p>
              <div className="flex flex-wrap gap-2">
                {[
                  { name: "New Year's Day", date: "01-01" },
                  { name: "Human Rights Day", date: "03-21" },
                  { name: "Good Friday", date: "03-29" },
                  { name: "Freedom Day", date: "04-27" },
                  { name: "Workers' Day", date: "05-01" },
                  { name: "Youth Day", date: "06-16" },
                  { name: "National Women's Day", date: "08-09" },
                  { name: "Heritage Day", date: "09-24" },
                  { name: "Day of Reconciliation", date: "12-16" },
                  { name: "Christmas Day", date: "12-25" },
                  { name: "Day of Goodwill", date: "12-26" },
                ].map((h) => (
                  <button
                    key={h.date}
                    onClick={() => {
                      const year = new Date().getFullYear()
                      const existing = holidays.find(hol => hol.date.endsWith(h.date))
                      if (!existing) {
                        const newH: Holiday = { id: Date.now().toString(), date: `${year}-${h.date}`, name: h.name, recurring: true }
                        const updated = [...holidays, newH]
                        setHolidays(updated)
                        localStorage.setItem('sparelink-holidays', JSON.stringify(updated))
                      }
                    }}
                    disabled={holidays.some(hol => hol.date.endsWith(h.date))}
                    className="px-3 py-1.5 bg-[#2d2d2d] hover:bg-[#3d3d3d] text-gray-300 hover:text-white rounded-lg text-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {h.name}
                  </button>
                ))}
              </div>
            </div>
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

      {/* Invite Staff Modal */}
      {showInviteModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-md border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <div>
                <h3 className="text-xl font-semibold text-white">Invite Team Member</h3>
                <p className="text-gray-400 text-sm">Send an invitation to join your shop</p>
              </div>
              <button onClick={() => setShowInviteModal(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Full Name *</label>
                <input
                  type="text"
                  value={inviteName}
                  onChange={(e) => setInviteName(e.target.value)}
                  placeholder="John Smith"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Email Address *</label>
                <input
                  type="email"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="john@example.com"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Role</label>
                <select
                  value={inviteRole}
                  onChange={(e) => setInviteRole(e.target.value as 'admin' | 'staff')}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                >
                  <option value="staff">Staff - Can respond to quotes and chats</option>
                  <option value="admin">Admin - Full access to settings</option>
                </select>
              </div>
            </div>
            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => setShowInviteModal(false)}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleInviteStaff}
                disabled={!inviteEmail || !inviteName}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                <Mail className="w-5 h-5" />
                Send Invite
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Holiday Modal */}
      {showHolidayModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1a1a] rounded-2xl w-full max-w-md border border-gray-800">
            <div className="flex items-center justify-between p-6 border-b border-gray-800">
              <div>
                <h3 className="text-xl font-semibold text-white">{editingHoliday ? 'Edit Holiday' : 'Add Holiday'}</h3>
                <p className="text-gray-400 text-sm">Mark a date when your shop will be closed</p>
              </div>
              <button onClick={() => { setShowHolidayModal(false); setEditingHoliday(null); }} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Holiday Name *</label>
                <input
                  type="text"
                  value={newHoliday.name}
                  onChange={(e) => setNewHoliday({ ...newHoliday, name: e.target.value })}
                  placeholder="e.g., Christmas Day"
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Date *</label>
                <input
                  type="date"
                  value={newHoliday.date}
                  onChange={(e) => setNewHoliday({ ...newHoliday, date: e.target.value })}
                  className="w-full bg-[#2d2d2d] text-white px-4 py-3 rounded-lg border border-gray-700 focus:border-accent focus:outline-none"
                />
              </div>
              <div className="flex items-center justify-between p-4 bg-[#2d2d2d] rounded-lg">
                <div>
                  <p className="text-white font-medium">Recurring Annually</p>
                  <p className="text-gray-400 text-sm">Repeat this holiday every year</p>
                </div>
                <button
                  onClick={() => setNewHoliday({ ...newHoliday, recurring: !newHoliday.recurring })}
                  className={`w-14 h-8 rounded-full transition-colors ${newHoliday.recurring ? "bg-accent" : "bg-gray-600"}`}
                >
                  <div className={`w-6 h-6 bg-white rounded-full transition-transform ${newHoliday.recurring ? "translate-x-7" : "translate-x-1"}`} />
                </button>
              </div>
            </div>
            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => { setShowHolidayModal(false); setEditingHoliday(null); }}
                className="flex-1 px-4 py-3 border border-gray-700 text-white rounded-lg hover:bg-[#2d2d2d] transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveHoliday}
                disabled={!newHoliday.date || !newHoliday.name}
                className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-white rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                <Check className="w-5 h-5" />
                {editingHoliday ? 'Update' : 'Add'} Holiday
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
