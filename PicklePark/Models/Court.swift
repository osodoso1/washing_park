import Foundation

public struct Court: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let isReservableOnWebTrac: Bool
    public let hasLights: Bool
    public let surfaceType: String
    public let locationDescription: String
    public let webTracFacilityId: String
    
    public init(
        id: String,
        name: String,
        displayName: String,
        isReservableOnWebTrac: Bool = true,
        hasLights: Bool = true,
        surfaceType: String = "Hard Court (Reservable on WebTrac)",
        locationDescription: String = "Washington Park, 850 Burlingame Ave",
        webTracFacilityId: String
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.isReservableOnWebTrac = isReservableOnWebTrac
        self.hasLights = hasLights
        self.surfaceType = surfaceType
        self.locationDescription = locationDescription
        self.webTracFacilityId = webTracFacilityId
    }
    
    /// The Reservable Courts at Washington Park: Court 2 and Court 3
    public static let reservableCourts: [Court] = [
        Court(
            id: "wp_tennis_2",
            name: "Washington Park Court 2",
            displayName: "Court 2",
            isReservableOnWebTrac: true,
            hasLights: true,
            surfaceType: "Reservable Pickleball / Tennis",
            locationDescription: "Main Court 2 (Reservable on WebTrac)",
            webTracFacilityId: "WP-TC02"
        ),
        Court(
            id: "wp_tennis_3",
            name: "Washington Park Court 3",
            displayName: "Court 3",
            isReservableOnWebTrac: true,
            hasLights: true,
            surfaceType: "Reservable Pickleball / Tennis",
            locationDescription: "Main Court 3 (Reservable on WebTrac)",
            webTracFacilityId: "WP-TC03"
        )
    ]
}
