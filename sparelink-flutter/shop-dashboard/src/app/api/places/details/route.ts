import { NextRequest, NextResponse } from "next/server"

// Photon API (OpenStreetMap) - No API key required!
// Documentation: https://photon.komoot.io/
const PHOTON_BASE_URL = "https://photon.komoot.io"

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const placeId = searchParams.get("place_id")
  
  console.log("📍 Photon Details API called with place_id:", placeId)
  
  if (!placeId) {
    console.log("⚠️ Missing place_id")
    return NextResponse.json({ error: "place_id is required", status: "INVALID_REQUEST" }, { status: 400 })
  }
  
  try {
    // place_id format is "lat,lon" from our autocomplete
    const [latStr, lonStr] = placeId.split(",")
    const lat = parseFloat(latStr)
    const lon = parseFloat(lonStr)
    
    if (isNaN(lat) || isNaN(lon)) {
      console.log("⚠️ Invalid place_id format, expected 'lat,lon'")
      return NextResponse.json({ error: "Invalid place_id format", status: "INVALID_REQUEST" }, { status: 400 })
    }
    
    // Use Photon reverse geocoding
    const url = new URL(`${PHOTON_BASE_URL}/reverse`)
    url.searchParams.set("lat", lat.toString())
    url.searchParams.set("lon", lon.toString())
    url.searchParams.set("lang", "en")
    
    console.log("🌐 Fetching details from Photon:", url.toString())
    
    const response = await fetch(url.toString())
    const data = await response.json()
    
    console.log("📦 Photon Reverse Response:", data.features?.length || 0, "results")
    
    if (!data.features || data.features.length === 0) {
      return NextResponse.json({ 
        status: "ZERO_RESULTS",
        result: null 
      })
    }
    
    const feature = data.features[0]
    const props = feature.properties
    const [resultLon, resultLat] = feature.geometry.coordinates
    
    // Extract address components
    const suburb = props.suburb || props.district || null
    const city = props.city || props.town || props.village || null
    const state = props.state || null
    const postcode = props.postcode || null
    const country = props.country || null
    const street = props.street || null
    const housenumber = props.housenumber || null
    
    console.log("📍 Extracted - Suburb:", suburb, "| City:", city, "| State:", state)
    
    // Build formatted address
    const addressParts: string[] = []
    if (housenumber && street) {
      addressParts.push(`${housenumber} ${street}`)
    } else if (street) {
      addressParts.push(street)
    } else if (props.name) {
      addressParts.push(props.name)
    }
    if (suburb) addressParts.push(suburb)
    if (city) addressParts.push(city)
    if (state) addressParts.push(state)
    if (postcode) addressParts.push(postcode)
    if (country) addressParts.push(country)
    
    const formattedAddress = addressParts.join(", ")
    
    // Build address_components in Google-like format for compatibility
    const addressComponents: Array<{long_name: string, short_name: string, types: string[]}> = []
    
    if (housenumber) {
      addressComponents.push({ long_name: housenumber, short_name: housenumber, types: ["street_number"] })
    }
    if (street) {
      addressComponents.push({ long_name: street, short_name: street, types: ["route"] })
    }
    if (suburb) {
      addressComponents.push({ long_name: suburb, short_name: suburb, types: ["sublocality", "sublocality_level_1"] })
    }
    if (city) {
      addressComponents.push({ long_name: city, short_name: city, types: ["locality"] })
    }
    if (state) {
      addressComponents.push({ long_name: state, short_name: state, types: ["administrative_area_level_1"] })
    }
    if (postcode) {
      addressComponents.push({ long_name: postcode, short_name: postcode, types: ["postal_code"] })
    }
    if (country) {
      addressComponents.push({ long_name: country, short_name: country, types: ["country"] })
    }
    
    // Return in Google-compatible format
    return NextResponse.json({
      status: "OK",
      result: {
        formatted_address: formattedAddress,
        address_components: addressComponents,
        geometry: {
          location: {
            lat: resultLat,
            lng: resultLon
          }
        },
        // Include raw Photon data for reference
        photon_properties: props
      }
    })
  } catch (error) {
    console.error("❌ Photon details error:", error)
    return NextResponse.json({ error: "Failed to fetch place details", status: "ERROR" }, { status: 500 })
  }
}
