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

// Análisis post-corrida (POST /ai/run-analysis). Los números vienen de la
// sesión real; el texto del modelo pasa por validación en el backend.
struct RunAnalysis: Decodable {
    let headline: String
    let summary: String
    let pace_assessment: String
    let strengths: [String]
    let improvements: [String]
    let recommendation: String
    let next_run: NextRun
    let metrics: Metrics?
    let ai_mode: String

    struct NextRun: Decodable {
        let distance_km: Double
        let focus: String
    }
    struct Metrics: Decodable {
        let distance_km: Double?
        let duration_min: Double?
        let pace_label: String?
        let avg_hr: Int?
    }

    var isDemo: Bool { ai_mode != "real" }
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

