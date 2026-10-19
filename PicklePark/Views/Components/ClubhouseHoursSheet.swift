import SwiftUI

public struct ClubhouseHoursSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.canvasBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Hero Header
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.burlingameBlue.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "building.2.crop.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.burlingameBlue)
                            }
                            .padding(.top, 8)
                            
                            Text("Washington Park Clubhouse")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("850 Burlingame Ave, Burlingame, CA 94010")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 6)
                        
                        // Clubhouse Hours Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(AppTheme.burlingameBlue)
                                Text("CLUBHOUSE & DESK HOURS")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("Open Today")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(AppTheme.availableGreen.opacity(0.12))
                                    .foregroundColor(AppTheme.availableGreen)
                                    .clipShape(Capsule())
                            }
                            
                            VStack(spacing: 8) {
                                HoursRow(day: "Monday – Thursday", hours: "8:00 AM – 7:00 PM", isHighlight: true)
                                HoursRow(day: "Friday", hours: "8:00 AM – 5:00 PM")
                                HoursRow(day: "Saturday", hours: "9:00 AM – 4:00 PM")
                                HoursRow(day: "Sunday", hours: "9:00 AM – 4:00 PM")
                            }
                        }
                        .padding(14)
                        .cleanCardStyle()
                        
                        // Court & Lights Schedule Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(AppTheme.pickleballLime)
                                Text("COURTS & LIGHTS SCHEDULE")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            VStack(spacing: 8) {
                                HoursRow(day: "Park & Courts Open", hours: "6:00 AM – 10:00 PM", isHighlight: true)
                                HoursRow(day: "Court Lights Active", hours: "Dusk – 10:00 PM (Auto Shutoff)")
                                HoursRow(day: "Court 1 Drop-In", hours: "8:00 AM – 10:00 PM Daily")
                                HoursRow(day: "Courts 2 & 3 WebTrac", hours: "Reservations or Walk-On")
                            }
                        }
                        .padding(14)
                        .cleanCardStyle()
                        
                        // Park Amenities & Amenities Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("FACILITIES & AMENITIES")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            VStack(spacing: 8) {
                                AmenityRow(icon: "figure.walk", title: "Restrooms", desc: "Located inside Clubhouse and adjacent to Court 1")
                                AmenityRow(icon: "drop.fill", title: "Water Refill Station", desc: "Next to Clubhouse front entrance")
                                AmenityRow(icon: "car.fill", title: "Free Parking", desc: "Washington Park lot on Burlingame Ave & Carolan Ave")
                                AmenityRow(icon: "phone.fill", title: "Parks & Rec Desk", desc: "(650) 558-7300 · parksrec@burlingame.org")
                            }
                        }
                        .padding(14)
                        .cleanCardStyle()
                        
                        // Open in Apple Maps Button
                        Button(action: {
                            if let url = URL(string: "http://maps.apple.com/?daddr=850+Burlingame+Ave,+Burlingame,+CA+94010") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Get Directions in Maps")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.burlingameBlue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Clubhouse & Park Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.burlingameBlue)
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
}

private struct HoursRow: View {
    let day: String
    let hours: String
    var isHighlight: Bool = false
    
    var body: some View {
        HStack {
            Text(day)
                .font(.system(size: 12, weight: isHighlight ? .bold : .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(hours)
                .font(.system(size: 12, weight: isHighlight ? .bold : .semibold))
                .foregroundColor(isHighlight ? AppTheme.burlingameBlue : AppTheme.textSecondary)
        }
        .padding(.vertical, 3)
    }
}

private struct AmenityRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.burlingameBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
