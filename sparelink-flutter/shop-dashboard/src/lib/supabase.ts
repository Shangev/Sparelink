import { createClient } from '@supabase/supabase-js'

// Supabase configuration
const supabaseUrl = 'https://zcxsbfzezfjnkxwnnklf.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjeHNiZnplemZqbmt4d25ua2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDY1MjIsImV4cCI6MjA4MzcyMjUyMn0.lHSBwHRery2A5wMy0A2Zhlk-HzTvWXhGR0GIjybrlec'

// Create Supabase client with session persistence enabled
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    // Persist session in localStorage for browser restarts
    persistSession: true,
    // Storage key for the session
    storageKey: 'sparelink-shop-auth',
    // Auto-refresh session before expiry
    autoRefreshToken: true,
    // Detect session from URL (for OAuth callbacks, NOT for SSO tokens)
    detectSessionInUrl: false,
  },
})

// ============================================
// SESSION MANAGEMENT TYPES
// ============================================

export interface DeviceSession {
  id: string
  user_id: string
  device_name: string
  device_type: 'desktop' | 'mobile' | 'tablet'
  browser: string
  os: string
  ip_address: string
  last_active: string
  created_at: string
  is_current: boolean
}

export interface SSOToken {
  token: string
  user_id: string
  expires_at: string
  used: boolean
}

// ============================================
// SESSION PERSISTENCE HELPERS
// ============================================

/**
 * Get the current session from storage
 */
export async function getCurrentSession() {
  const { data: { session }, error } = await supabase.auth.getSession()
  return { session, error }
}

/**
 * Refresh the current session
 */
export async function refreshSession() {
  const { data: { session }, error } = await supabase.auth.refreshSession()
  return { session, error }
}

/**
 * Listen for auth state changes
 */
export function onAuthStateChange(callback: (event: string, session: any) => void) {
  return supabase.auth.onAuthStateChange(callback)
}

// ============================================
// SSO (SINGLE SIGN-ON) FROM MOBILE
// ============================================

/**
 * Generate a secure SSO token for mobile-to-web authentication
 * This creates a one-time use token stored in the database
 * The token is NOT passed via URL - it's exchanged via secure POST
 */
export async function generateSSOToken(userId: string): Promise<string | null> {
  try {
    // Generate a cryptographically secure token
    const tokenArray = new Uint8Array(32)
    crypto.getRandomValues(tokenArray)
    const token = Array.from(tokenArray, byte => byte.toString(16).padStart(2, '0')).join('')
    
    // Token expires in 5 minutes (short-lived for security)
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()
    
    // Store token in database
    const { error } = await supabase
      .from('sso_tokens')
      .insert({
        token,
        user_id: userId,
        expires_at: expiresAt,
        used: false,
      })
    
    if (error) throw error
    
    return token
  } catch (error) {
    console.error('Failed to generate SSO token:', error)
    return null
  }
}

/**
 * Exchange SSO token for a session (called from web dashboard)
 * Token is sent via POST body, never in URL
 */
export async function exchangeSSOToken(token: string): Promise<{ success: boolean; error?: string }> {
  try {
    // Verify token in database
    const { data: tokenData, error: fetchError } = await supabase
      .from('sso_tokens')
      .select('*')
      .eq('token', token)
      .eq('used', false)
      .single()
    
    if (fetchError || !tokenData) {
      return { success: false, error: 'Invalid or expired token' }
    }
    
    // Check expiration
    if (new Date(tokenData.expires_at) < new Date()) {
      // Clean up expired token
      await supabase.from('sso_tokens').delete().eq('token', token)
      return { success: false, error: 'Token has expired' }
    }
    
    // Mark token as used (one-time use)
    await supabase
      .from('sso_tokens')
      .update({ used: true })
      .eq('token', token)
    
    // Get user data and create session
    const { data: userData, error: userError } = await supabase
      .from('profiles')
      .select('id, role')
      .eq('id', tokenData.user_id)
      .single()
    
    if (userError || !userData || userData.role !== 'shop') {
      return { success: false, error: 'User not authorized for shop dashboard' }
    }
    
    // Note: The actual session creation happens via Supabase's admin API
    // or by having the user verify via OTP on the web as a fallback
    return { success: true }
  } catch (error) {
    console.error('SSO token exchange failed:', error)
    return { success: false, error: 'Authentication failed' }
  }
}

// ============================================
// MULTI-DEVICE SESSION MANAGEMENT
// ============================================

/**
 * Register current device session
 */
export async function registerDeviceSession(userId: string): Promise<string | null> {
  try {
    // Detect device info from user agent
    const userAgent = typeof window !== 'undefined' ? window.navigator.userAgent : 'Unknown'
    const deviceInfo = parseUserAgent(userAgent)
    
    // Generate session ID
    const sessionId = crypto.randomUUID()
    
    const { error } = await supabase
      .from('device_sessions')
      .insert({
        id: sessionId,
        user_id: userId,
        device_name: deviceInfo.deviceName,
        device_type: deviceInfo.deviceType,
        browser: deviceInfo.browser,
        os: deviceInfo.os,
        ip_address: 'client', // Will be set by server/edge function
        last_active: new Date().toISOString(),
      })
    
    if (error) throw error
    
    // Store session ID locally
    if (typeof window !== 'undefined') {
      localStorage.setItem('sparelink-device-session-id', sessionId)
    }
    
    return sessionId
  } catch (error) {
    console.error('Failed to register device session:', error)
    return null
  }
}

/**
 * Update last active timestamp for current session
 */
export async function updateSessionActivity() {
  try {
    const sessionId = typeof window !== 'undefined' 
      ? localStorage.getItem('sparelink-device-session-id') 
      : null
    
    if (!sessionId) return
    
    await supabase
      .from('device_sessions')
      .update({ last_active: new Date().toISOString() })
      .eq('id', sessionId)
  } catch (error) {
    console.error('Failed to update session activity:', error)
  }
}

/**
 * Get all active sessions for a user
 */
export async function getDeviceSessions(userId: string): Promise<DeviceSession[]> {
  try {
    const currentSessionId = typeof window !== 'undefined' 
      ? localStorage.getItem('sparelink-device-session-id') 
      : null
    
    const { data, error } = await supabase
      .from('device_sessions')
      .select('*')
      .eq('user_id', userId)
      .order('last_active', { ascending: false })
    
    if (error) throw error
    
    // Mark current session
    return (data || []).map(session => ({
      ...session,
      is_current: session.id === currentSessionId,
    }))
  } catch (error) {
    console.error('Failed to get device sessions:', error)
    return []
  }
}

/**
 * Revoke a specific device session
 */
export async function revokeDeviceSession(sessionId: string): Promise<boolean> {
  try {
    const { error } = await supabase
      .from('device_sessions')
      .delete()
      .eq('id', sessionId)
    
    return !error
  } catch (error) {
    console.error('Failed to revoke device session:', error)
    return false
  }
}

/**
 * Revoke all sessions except current
 */
export async function revokeAllOtherSessions(userId: string): Promise<boolean> {
  try {
    const currentSessionId = typeof window !== 'undefined' 
      ? localStorage.getItem('sparelink-device-session-id') 
      : null
    
    const { error } = await supabase
      .from('device_sessions')
      .delete()
      .eq('user_id', userId)
      .neq('id', currentSessionId || '')
    
    return !error
  } catch (error) {
    console.error('Failed to revoke other sessions:', error)
    return false
  }
}

/**
 * Clean up session on logout
 */
export async function cleanupSession() {
  try {
    const sessionId = typeof window !== 'undefined' 
      ? localStorage.getItem('sparelink-device-session-id') 
      : null
    
    if (sessionId) {
      await supabase.from('device_sessions').delete().eq('id', sessionId)
      localStorage.removeItem('sparelink-device-session-id')
    }
  } catch (error) {
    console.error('Failed to cleanup session:', error)
  }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Parse user agent to extract device info
 */
function parseUserAgent(userAgent: string): {
  deviceName: string
  deviceType: 'desktop' | 'mobile' | 'tablet'
  browser: string
  os: string
} {
  // Detect OS
  let os = 'Unknown'
  if (userAgent.includes('Windows')) os = 'Windows'
  else if (userAgent.includes('Mac OS')) os = 'macOS'
  else if (userAgent.includes('Linux')) os = 'Linux'
  else if (userAgent.includes('Android')) os = 'Android'
  else if (userAgent.includes('iOS') || userAgent.includes('iPhone') || userAgent.includes('iPad')) os = 'iOS'
  
  // Detect browser
  let browser = 'Unknown'
  if (userAgent.includes('Chrome') && !userAgent.includes('Edg')) browser = 'Chrome'
  else if (userAgent.includes('Safari') && !userAgent.includes('Chrome')) browser = 'Safari'
  else if (userAgent.includes('Firefox')) browser = 'Firefox'
  else if (userAgent.includes('Edg')) browser = 'Edge'
  
  // Detect device type
  let deviceType: 'desktop' | 'mobile' | 'tablet' = 'desktop'
  if (userAgent.includes('Mobile') || userAgent.includes('Android')) deviceType = 'mobile'
  else if (userAgent.includes('Tablet') || userAgent.includes('iPad')) deviceType = 'tablet'
  
  // Generate device name
  const deviceName = `${browser} on ${os}`
  
  return { deviceName, deviceType, browser, os }
}
