import Foundation
import CoreLocation
import MapKit

struct RunRouteOption: Identifiable, Decodable {
    let id: Int
    let preference: String
    let label: String
    let rationale: String
    let distance_m: Int
    let geojson: GeoJSONLineString
}

struct GeoJSONLineString: Decodable {
    let type: String
    let coordinates: [[Double]] // [lng, lat]
}

struct RunRoutesResponse: Decodable {
    let items: [RunRouteOption]
}

struct RunRouteResponse: Decodable {
    let route: RunRouteDetail
}

struct RunRouteDetail: Identifiable, Decodable {
    let id: Int
    let origin_lat: Double
    let origin_lng: Double
    let distance_m: Int
    let preference: String
    let label: String
    let rationale: String
    let geojson: GeoJSONLineString
}

