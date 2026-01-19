import { NextRequest, NextResponse } from "next/server"

// Photon API (OpenStreetMap) - No API key required!
// Documentation: https://photon.komoot.io/
const PHOTON_BASE_URL = "https://photon.komoot.io"

// South Africa coordinates for biasing results
const DEFAULT_LAT = -26.2041  // Johannesburg
const DEFAULT_LON = 28.0473

interface PhotonFeature {
  type: string
  geometry: {
    coordinates: [number, number]
    type: string
  }
  properties: {
    osm_id?: number
    name?: string
    street?: string
    housenumber?: string
    suburb?: string
    district?: string
    city?: string
    town?: string
    village?: string
    state?: string
    country?: string
    postcode?: string
  }
}

interface PhotonResponse {
  type: string
  features: PhotonFeature[]
}

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const input = searchParams.get("input")
  
  console.log("🔍 Photon Autocomplete API called with input:", input)
  
  if (!input || input.length < 3) {
    console.log("⚠️ Input too short, returning empty")
    return NextResponse.json({ predictions: [], status: "ZERO_RESULTS" })
  }
  
  try {
    // Build Photon URL with South Africa bias
    const url = new URL(`${PHOTON_BASE_URL}/api/`)
    url.searchParams.set("q", input)
    url.searchParams.set("lat", DEFAULT_LAT.toString())
    url.searchParams.set("lon", DEFAULT_LON.toString())
    url.searchParams.set("limit", "10")
    url.searchParams.set("lang", "en")
    
    console.log("🌐 Fetching from Photon:", url.toString())
    
    const response = await fetch(url.toString())
    const data: PhotonResponse = await response.json()
    
    console.log("📦 Photon Response: ", data.features?.length || 0, "results")
    
    // Transform Photon response to match our expected format
    const predictions = data.features.map((feature) => {
      const props = feature.properties
      const [lon, lat] = feature.geometry.coordinates
      
      // Build main text
      let mainText = props.name || ""
      if (!mainText && props.street) {
        mainText = props.housenumber ? `${props.housenumber} ${props.street}` : props.street
      }
      if (!mainText) {
        mainText = props.suburb || props.district || props.city || props.town || ""
      }
      
      // Build secondary text
      const secondaryParts: string[] = []
      const suburb = props.suburb || props.district
      const city = props.city || props.town || props.village
      if (suburb && suburb !== mainText) secondaryParts.push(suburb)
      if (city && city !== mainText && city !== suburb) secondaryParts.push(city)
      if (props.state) secondaryParts.push(props.state)
      if (props.country) secondaryParts.push(props.country)
      const secondaryText = secondaryParts.join(", ")
      
      // Build full description
      const description = [mainText, secondaryText].filter(Boolean).join(", ")
      
      // Create place_id from coordinates
      const placeId = `${lat},${lon}`
      
      return {
        place_id: placeId,
        description,
        structured_formatting: {
          main_text: mainText,
          secondary_text: secondaryText
        },
        // Include raw feature for details lookup
        photon_feature: feature
      }
    })
    
    return NextResponse.json({
      predictions,
      status: predictions.length > 0 ? "OK" : "ZERO_RESULTS"
    })
  } catch (error) {
    console.error("❌ Photon autocomplete error:", error)
    return NextResponse.json({ predictions: [], status: "ERROR", error: "Failed to fetch places" }, { status: 500 })
  }
}
