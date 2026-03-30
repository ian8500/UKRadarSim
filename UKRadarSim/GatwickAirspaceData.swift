import Foundation

enum GatwickAirspaceData {
    static let gatwickARP = LatLon(lat: 51.148056, lon: -0.190278)

    static let sectors: [AirspaceSector] = [
        AirspaceSector(
            id: "EGKK-CTR",
            name: "GATWICK CTR",
            airspaceClass: "D",
            floorText: "SFC",
            ceilingText: "2500",
            start: LatLon(lat: 51.216111, lon: -0.191389),
            primitives: [
                .line(to: LatLon(lat: 51.200000, lon: 0.061389)),
                .clockwiseArc(center: gatwickARP, radiusNM: 10, to: LatLon(lat: 51.097222, lon: 0.061667)),
                .line(to: LatLon(lat: 51.044444, lon: -0.323056)),
                .clockwiseArc(center: gatwickARP, radiusNM: 8, to: LatLon(lat: 51.188333, lon: -0.392222)),
                .line(to: LatLon(lat: 51.216111, lon: -0.191389))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.1490, lon: -0.2050),
                alternates: [LatLon(lat: 51.1620, lon: -0.1750), LatLon(lat: 51.1300, lon: -0.2280)]
            ),
            isFilled: true,
            isDashed: false,
            displayPriority: 10
        ),
        AirspaceSector(
            id: "EGKK-CTA-1500",
            name: "GATWICK CTA",
            airspaceClass: "D",
            floorText: "1500",
            ceilingText: "2500",
            start: LatLon(lat: 51.016667, lon: 0.082778),
            primitives: [
                .line(to: LatLon(lat: 51.016667, lon: -0.429167)),
                .clockwiseArc(center: gatwickARP, radiusNM: 12.0, to: LatLon(lat: 51.190000, lon: -0.500833)),
                .line(to: LatLon(lat: 51.271667, lon: 0.092500)),
                .clockwiseArc(center: gatwickARP, radiusNM: 13.0, to: LatLon(lat: 51.016667, lon: 0.082778))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.2340, lon: -0.1020),
                alternates: [LatLon(lat: 51.0630, lon: -0.0380), LatLon(lat: 51.0520, lon: -0.3100)]
            ),
            isFilled: false,
            isDashed: true,
            displayPriority: 20
        ),
        AirspaceSector(
            id: "EGKK-CTA-2500",
            name: "LTMA SFC 2500",
            airspaceClass: "A",
            floorText: "2500",
            ceilingText: "5500",
            start: LatLon(lat: 51.252778, lon: -0.520000),
            primitives: [
                .clockwiseArc(center: gatwickARP, radiusNM: 18.0, to: LatLon(lat: 51.320000, lon: 0.180000)),
                .line(to: LatLon(lat: 51.285000, lon: 0.240000)),
                .anticlockwiseArc(center: gatwickARP, radiusNM: 22.0, to: LatLon(lat: 51.205000, lon: -0.610000)),
                .line(to: LatLon(lat: 51.252778, lon: -0.520000))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.3000, lon: -0.2800),
                alternates: [LatLon(lat: 51.2800, lon: -0.0200), LatLon(lat: 51.2200, lon: -0.4800)]
            ),
            isFilled: false,
            isDashed: true,
            displayPriority: 30
        ),
        AirspaceSector(
            id: "EGKK-CTA-3500",
            name: "LTMA CTA",
            airspaceClass: "A",
            floorText: "3500",
            ceilingText: "FL65",
            start: LatLon(lat: 51.340000, lon: -0.430000),
            primitives: [
                .clockwiseArc(center: gatwickARP, radiusNM: 24.0, to: LatLon(lat: 51.365000, lon: 0.190000)),
                .line(to: LatLon(lat: 51.318000, lon: 0.245000)),
                .anticlockwiseArc(center: gatwickARP, radiusNM: 27.0, to: LatLon(lat: 51.300000, lon: -0.520000)),
                .line(to: LatLon(lat: 51.340000, lon: -0.430000))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.3600, lon: -0.1600),
                alternates: [LatLon(lat: 51.3450, lon: 0.0300), LatLon(lat: 51.3300, lon: -0.3500)]
            ),
            isFilled: false,
            isDashed: true,
            displayPriority: 40
        ),
        AirspaceSector(
            id: "EGKK-CTA-4500",
            name: "LTMA CTA",
            airspaceClass: "A",
            floorText: "4500",
            ceilingText: "FL65",
            start: LatLon(lat: 51.395000, lon: -0.350000),
            primitives: [
                .clockwiseArc(center: gatwickARP, radiusNM: 29.0, to: LatLon(lat: 51.410000, lon: 0.120000)),
                .line(to: LatLon(lat: 51.380000, lon: 0.170000)),
                .anticlockwiseArc(center: gatwickARP, radiusNM: 31.5, to: LatLon(lat: 51.365000, lon: -0.400000)),
                .line(to: LatLon(lat: 51.395000, lon: -0.350000))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.3920, lon: -0.1050),
                alternates: [LatLon(lat: 51.3780, lon: 0.0500), LatLon(lat: 51.3800, lon: -0.2800)]
            ),
            isFilled: false,
            isDashed: true,
            displayPriority: 50
        ),
        AirspaceSector(
            id: "EGKK-CTA-5000",
            name: "LTMA CTA",
            airspaceClass: "A",
            floorText: "5000",
            ceilingText: "FL65",
            start: LatLon(lat: 51.432000, lon: -0.305000),
            primitives: [
                .clockwiseArc(center: gatwickARP, radiusNM: 34.0, to: LatLon(lat: 51.438000, lon: 0.060000)),
                .line(to: LatLon(lat: 51.415000, lon: 0.092000)),
                .anticlockwiseArc(center: gatwickARP, radiusNM: 36.0, to: LatLon(lat: 51.410000, lon: -0.335000)),
                .line(to: LatLon(lat: 51.432000, lon: -0.305000))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.4280, lon: -0.1250),
                alternates: [LatLon(lat: 51.4200, lon: -0.0100), LatLon(lat: 51.4200, lon: -0.2500)]
            ),
            isFilled: false,
            isDashed: true,
            displayPriority: 60
        ),
        AirspaceSector(
            id: "EGKK-CTA-5500",
            name: "LTMA CTA",
            airspaceClass: "A",
            floorText: "5500",
            ceilingText: "FL65",
            start: LatLon(lat: 51.460000, lon: -0.250000),
            primitives: [
                .clockwiseArc(center: gatwickARP, radiusNM: 38.0, to: LatLon(lat: 51.460000, lon: 0.020000)),
                .line(to: LatLon(lat: 51.446000, lon: 0.044000)),
                .anticlockwiseArc(center: gatwickARP, radiusNM: 40.0, to: LatLon(lat: 51.446000, lon: -0.270000)),
                .line(to: LatLon(lat: 51.460000, lon: -0.250000))
            ],
            labelAnchor: AirspaceLabelAnchor(
                primary: LatLon(lat: 51.4550, lon: -0.1200),
                alternates: [LatLon(lat: 51.4480, lon: -0.0300), LatLon(lat: 51.4480, lon: -0.2300)]
            ),
            isFilled: false,
            isDashed: true,
            displayPriority: 70
        )
    ]
}
