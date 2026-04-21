<div align="center">

# FitNow iOS

**Tu fitness sin límites** — Plataforma que conecta atletas con gimnasios, entrenadores personales y clubes deportivos.

![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat-square&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-17+-000000?style=flat-square&logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-0071E3?style=flat-square&logo=swift&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-15+-147EFB?style=flat-square&logo=xcode&logoColor=white)

</div>

---

## Tabla de contenidos

- [Descripción](#descripción)
- [Roles de usuario](#roles-de-usuario)
- [Pantallas](#pantallas)
- [Sistema de diseño](#sistema-de-diseño)
  - [Paleta de colores](#paleta-de-colores)
  - [Tipografía](#tipografía)
  - [Sombras y elevación](#sombras-y-elevación)
  - [Border radius](#border-radius)
  - [Gradientes](#gradientes)
- [Interacciones y animaciones](#interacciones-y-animaciones)
- [Navegación y flujos](#navegación-y-flujos)
- [Setup](#setup)
- [Estructura del proyecto](#estructura-del-proyecto)

---

## Descripción

FitNow es una app iOS de fitness con **dark mode nativo**, diseño de alta fidelidad y 3 roles de usuario diferenciados. Cubre flujos completos de inscripción a actividades, navegación GPS para correr y administración de proveedores.

**Stack tecnológico:**
- SwiftUI 5.0 + NavigationStack
- MapKit (Run Navigator — dark mode, overlay de ruta)
- Fuentes custom: DM Serif Display · JetBrains Mono
- Íconos: SF Symbols (nativo iOS)

---

## Roles de usuario

| Rol | Color de marca | Tab bar |
|---|---|---|
| **Atleta** | Azul `#1E90FF` | Home · Explorar · Run · Inscripciones · Perfil |
| **Proveedor** | Púrpura `#7B52F8` | Dashboard · Explorar · Perfil |
| **Admin** | Rojo `#FF3055` | Panel · Perfil |

---

## Pantallas

| # | Pantalla | Rol | Descripción |
|---|---|---|---|
| 1 | **Splash Screen** | Todos | Logo + wordmark + dots pulsantes → navega a Login en 2.6 s |
| 2 | **Login / Registro** | Todos | Form card con role picker, toggle login↔registro, acceso admin |
| 3 | **Home** | Atleta | Hero header, stats row, quick actions, promo banner, novedades |
| 4 | **Explorar** | Atleta | Search + filter chips + lista de actividades por tipo |
| 5 | **Activity Detail** | Atleta | Hero 280 pt, precio, cupos, descripción, provider card, CTA sticky |
| 6 | **Enrollment Wizard** | Atleta | 3 pasos: Confirmar → Plan → Pagar → Success con confetti |
| 7 | **Mis Inscripciones** | Atleta | Segmented picker Próximas/Pasadas/Todas, empty state |
| 8 | **Calendario** | Atleta | Week strip + timeline con eventos por tipo |
| 9 | **Run Planner** | Atleta | Distance selector gigante, slider, presets, rutas seleccionables |
| 10 | **Run Navigator** | Atleta | Full-screen MapKit, HUD glass, hazard banner, dashboard métricas |
| 11 | **Provider Dashboard** | Proveedor | Stats, quick actions, activity list con fill bar, feed de novedades |
| 12 | **Admin Panel** | Admin | Tabs Ofertas/Estadísticas/Usuarios/Proveedores, bar chart 7 días |
| 13 | **Perfil** | Todos | Avatar con borde gradiente, stats, settings groups, sign out |

---

## Sistema de diseño

### Paleta de colores

El diseño es **dark mode nativo**. No hay modo claro.

#### Brand / Accent

```swift
extension Color {
    // Primarios
    static let fnBlue    = Color(red: 0.12, green: 0.56, blue: 1.00)  // #1E90FF — azul eléctrico
    static let fnCobalt  = Color(red: 0.25, green: 0.41, blue: 0.88)  // #4169E1 — gradiente
    static let fnIce     = Color(red: 0.66, green: 0.78, blue: 0.98)  // #A8C7FA — azul claro

    // Semánticos
    static let fnGreen   = Color(red: 0.00, green: 0.90, blue: 0.46)  // #00E676 — éxito
    static let fnAmber   = Color(red: 1.00, green: 0.70, blue: 0.00)  // #FFB300 — warning
    static let fnCrimson = Color(red: 1.00, green: 0.19, blue: 0.33)  // #FF3055 — error/danger
    static let fnPurple  = Color(red: 0.48, green: 0.32, blue: 0.97)  // #7B52F8 — proveedor
}
```

#### Superficies

```swift
extension Color {
    static let fnBg       = Color(red: 0.04, green: 0.09, blue: 0.16)  // #0A1628 — fondo base
    static let fnSurface  = Color(red: 0.07, green: 0.13, blue: 0.25)  // #112240 — tarjeta
    static let fnElevated = Color(red: 0.10, green: 0.20, blue: 0.34)  // #1A3356 — elevado
    static let fnBorder   = Color(red: 0.14, green: 0.23, blue: 0.33)  // #243B55 — borde
}
```

#### Texto

```swift
extension Color {
    static let fnWhite = Color(red: 0.91, green: 0.94, blue: 0.996) // #E8F0FE — primario
    static let fnSlate = Color(red: 0.53, green: 0.60, blue: 0.67)  // #8899AA — secundario
    static let fnAsh   = Color(red: 0.27, green: 0.33, blue: 0.40)  // #445566 — placeholder
}
```

#### Colores semánticos por tipo de actividad

| Tipo | Color | Hex | Token |
|---|---|---|---|
| `trainer` | Amber | `#FFB300` | `fnAmber` |
| `gym` | Blue | `#1E90FF` | `fnBlue` |
| `club` | Purple | `#7B52F8` | `fnPurple` |
| `club_sport` | Green | `#00E676` | `fnGreen` |

---

### Tipografía

Fuentes custom requeridas en el bundle de Xcode: **DM Serif Display** y **JetBrains Mono** (Google Fonts). Fallback: `.serif` y `.monospacedDigit`.

```swift
// Display — títulos, wordmarks
Font.custom("DM Serif Display", size: 54)  // Hero / Splash
Font.custom("DM Serif Display", size: 34)  // Screen headers
Font.custom("DM Serif Display", size: 28)  // Section headers
Font.custom("DM Serif Display", size: 22)  // Sub-headers

// UI — cuerpo, labels, botones
Font.system(size: 16, weight: .bold)       // Botones primarios
Font.system(size: 14, weight: .semibold)   // Labels
Font.system(size: 13, weight: .medium)     // Subtítulos
Font.system(size: 11, weight: .regular)    // Captions / uppercase labels

// Mono — métricas, números, precios
Font.custom("JetBrains Mono", size: 72)    // Distance selector (Run Planner)
Font.custom("JetBrains Mono", size: 44)    // Total precio (Enrollment)
Font.custom("JetBrains Mono", size: 32)    // Precio grande
Font.custom("JetBrains Mono", size: 26)    // Dashboard métricas
Font.custom("JetBrains Mono", size: 20)    // Estadísticas
Font.custom("JetBrains Mono", size: 14)    // Precio lista
Font.custom("JetBrains Mono", size: 11)    // Labels pequeños
```

---

### Sombras y elevación

```swift
// Tarjeta genérica
.shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 4)

// Blue glow — botones CTA, acciones primarias
.shadow(color: Color.fnBlue.opacity(0.35), radius: 24, x: 0, y: 8)

// Green glow — confirmación, éxito
.shadow(color: Color.fnGreen.opacity(0.30), radius: 24, x: 0, y: 8)

// Red glow — danger, admin
.shadow(color: Color.fnCrimson.opacity(0.30), radius: 24, x: 0, y: 8)

// Purple glow — proveedor
.shadow(color: Color.fnPurple.opacity(0.30), radius: 24, x: 0, y: 8)
```

---

### Border radius

| Elemento | Radio | SwiftUI |
|---|---|---|
| Botones | 16 pt | `.cornerRadius(16)` |
| Tarjetas grandes | 20 pt | `.cornerRadius(20)` |
| Tarjetas chicas | 14 pt | `.cornerRadius(14)` |
| Badges / chips | ∞ | `.clipShape(Capsule())` |
| Íconos cuadrados | 12–14 pt | `.cornerRadius(12)` |
| Avatares | ∞ | `.clipShape(Circle())` |
| Splash logo | 28 pt | `.cornerRadius(28)` |
| Login form card | 24 pt | `.cornerRadius(24)` |

---

### Gradientes

```swift
// Primario — botones CTA, hero headers
LinearGradient(
    colors: [Color(hex: "#1E90FF"), Color(hex: "#4169E1")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

// Verde éxito — enrollment success, confirmaciones
LinearGradient(
    colors: [Color(hex: "#00E676"), Color(hex: "#00AA55")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

// Rojo danger — admin, acciones destructivas
LinearGradient(
    colors: [Color(hex: "#FF3055"), Color(hex: "#CC0033")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

// Proveedor
LinearGradient(
    colors: [Color(hex: "#7B52F8"), Color(hex: "#5533CC")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

// Trainer (amber)
LinearGradient(
    colors: [Color(hex: "#FFB300"), Color(hex: "#E65100")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)
```

---

## Interacciones y animaciones

### ScaleButtonStyle — aplicar a TODOS los botones

```swift
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(
                .spring(response: 0.18, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
```

### Entrada de pantallas (screen entry)

```swift
// En cada vista: .onAppear { appeared = true }
.opacity(appeared ? 1 : 0)
.offset(y: appeared ? 0 : 16)
.animation(
    .spring(response: 0.6, dampingFraction: 0.82).delay(staggerDelay),
    value: appeared
)
```

### Transición entre pantallas

Fade puro: `opacity 0 → 1`, duración 160 ms. **Sin slide.**

### Enrollment success — confetti

28 partículas con posición `x` aleatoria (20–80 % del ancho), delay aleatorio 0–0.6 s.
- Animación: `translateY(0) → 130 pt` + `rotate(0) → 720°`, 1.8 s ease-in
- Colores: `fnBlue`, `fnGreen`, `fnAmber`, `fnPurple`, `fnWhite`

### Splash dots pulsantes

3 dots azules, animación `.easeInOut(duration: 1.2)` con `.repeatForever(autoreverses: true)`, delays escalonados (0, 0.2, 0.4 s).

### Run Navigator — dot de usuario pulsante

Anillo exterior con `scaleEffect` 1.0 → 1.6 + `opacity` 1.0 → 0, `.easeInOut(duration: 1.4).repeatForever()`.

---

## Navegación y flujos

```
Splash (2.6 s)
  └─► Login / Registro
        ├─► Home  (Atleta)
        │     ├─► Explorar
        │     │     └─► Activity Detail
        │     │               └─► Enrollment Wizard (paso 1 → 2 → 3 → Success)
        │     │                         └─► Inscripciones | Home
        │     ├─► Run Planner
        │     │     └─► Run Navigator
        │     │               └─► Run Planner (Abandonar / Finalizar)
        │     ├─► Inscripciones
        │     ├─► Calendario
        │     └─► Perfil
        ├─► Provider Dashboard  (Proveedor)
        │     ├─► Explorar
        │     └─► Perfil
        └─► Admin Panel  (Admin)
              └─► Perfil
```

#### Tab bars por rol

| Rol | Tabs |
|---|---|
| Atleta | Home · Explorar · Run · Inscripciones · Perfil |
| Proveedor | Dashboard · Explorar · Perfil |
| Admin | Panel · Perfil |

---

## Setup

### Requisitos

- Xcode 15+
- iOS 17+ deployment target
- Swift 5.9+

### Instalación

```bash
git clone https://github.com/manuel-cosovschi/fitnow-ios.git
cd fitnow-ios
open FitNow.xcodeproj
```

### Fuentes custom

Agregar al bundle de Xcode (`FitNow/Resources/Fonts/`):

1. Descargar desde Google Fonts:
   - [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display)
   - [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono)
2. Arrastrar los archivos `.ttf` al grupo `Resources/Fonts` en Xcode
3. Marcar **Add to target: FitNow**
4. Verificar que estén declaradas en `Info.plist` bajo `UIAppFonts`:

```xml
<key>UIAppFonts</key>
<array>
    <string>DMSerifDisplay-Regular.ttf</string>
    <string>DMSerifDisplay-Italic.ttf</string>
    <string>JetBrainsMono-Regular.ttf</string>
    <string>JetBrainsMono-Bold.ttf</string>
    <string>JetBrainsMono-Medium.ttf</string>
</array>
```

### MapKit (Run Navigator)

Agregar `NSLocationWhenInUseUsageDescription` en `Info.plist`.

Configuración del mapa:

```swift
let config = MKStandardMapConfiguration()
config.pointOfInterestFilter = .excludingAll
// Aplicar dark mode via colorScheme del entorno
```

---

## Estructura del proyecto

```
FitNow/
├── App/
│   ├── FitNowApp.swift
│   └── ContentView.swift
├── Design/
│   ├── Colors.swift          # Tokens fnBlue, fnBg, fnSurface…
│   ├── Typography.swift      # Font extensions
│   ├── Gradients.swift       # LinearGradient constants
│   └── Components/
│       ├── FNButton.swift    # Botón primario con ScaleButtonStyle
│       ├── GlassCard.swift   # Card con blur + border sutil
│       ├── ActivityCard.swift
│       ├── StatCard.swift
│       └── BadgeView.swift
├── Screens/
│   ├── Splash/
│   ├── Auth/                 # Login + Registro
│   ├── Home/
│   ├── Explore/
│   ├── ActivityDetail/
│   ├── Enrollment/           # Wizard 3 pasos + Success
│   ├── Enrollments/          # Mis Inscripciones
│   ├── Calendar/
│   ├── Run/
│   │   ├── RunPlanner/
│   │   └── RunNavigator/
│   ├── Provider/
│   ├── Admin/
│   └── Profile/
├── Models/
├── Resources/
│   └── Fonts/
└── Info.plist
```

---

## Notas de diseño

- **Precio con gradiente:** En SwiftUI, el efecto `WebkitBackgroundClip: text` del HTML se logra con `.overlay(gradient).mask(Text(...))` sobre un `Text`.
- **Glass cards:** `ZStack` con `.background(.ultraThinMaterial)` + borde `fnBorder` 0.5 pt.
- **Borde izquierdo de tipo en ActivityCard:** `Rectangle().frame(width: 3).foregroundStyle(typeColor)` dentro de un `HStack` con el contenido.
- **Hero gradient overlay:** `LinearGradient` de `typeColor.opacity(0.22)` a `fnBg`, encima de la vista de fondo.

---

<div align="center">

*Diseño: FitNow Design System · Abril 2026*

</div>
