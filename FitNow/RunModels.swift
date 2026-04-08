// RunModels.swift
import Foundation
import CoreLocation

// Opción mostrada en el planner
struct RunRouteOption: Identifiable, Decodable {
    let id: Int
    let preference: String
    let label: String
    let rationale: String
    let distance_m: Int
    let geojson: GeoJSONLineString
}

// GeoJSON línea: { "type": "LineString", "coordinates": [[lng, lat], ...] }
struct GeoJSONLineString: Decodable {
    let type: String
    let coordinates: [[Double]]
}

// Extensión que convierte a coordenadas 2D (lo que usa el mapa y la navegación)
extension GeoJSONLineString {
    var coords2D: [CLLocationCoordinate2D] {
        coordinates.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
}

// Respuesta con lista de opciones para el planner
struct RunRoutesResponse: Decodable {
    let items: [RunRouteOption]
}

// Sesión de carrera del usuario (GET /run/sessions/mine)
struct RunSession: Identifiable, Decodable {
    let id: Int
    let started_at: String?
    let finished_at: String?
    let distance_m: Double?
    let duration_s: Double?
    let avg_pace_s_per_km: Double?
    let status: String?
}

struct RunSessionsResponse: Decodable {
    let items: [RunSession]
}

// Respuesta con una ruta concreta (si la pidieras por id)
struct RunRouteResponse: Decodable {
    let route: RunRouteDetail
}

// Detalle de una ruta concreta (alternativa de uso)
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

