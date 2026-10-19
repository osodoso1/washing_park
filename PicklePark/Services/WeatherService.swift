import Foundation
import Combine
import SwiftUI

public struct WeatherInfo: Codable {
    public var temperature: Int
    public var humidity: Int
    public var precipitationPct: Int
    public var conditionEmoji: String
    public var conditionDescription: String
    public var windSpeedMph: Int
    public var windGustMph: Int
    public var windDirection: String
    public var aqi: Int
    public var aqiStatus: String
    public var aqiEmoji: String
    public var lastUpdated: Date
    
    public var formattedWeatherSummary: String {
        let windStr: String
        if windSpeedMph <= 2 {
            windStr = "🍃 Calm"
        } else {
            let gustStr = windGustMph > (windSpeedMph + 2) ? " (Gusts \(windGustMph))" : ""
            windStr = "💨 \(windSpeedMph) mph \(windDirection)\(gustStr)"
        }
        return "\(conditionEmoji) \(temperature)°F | \(windStr)"
    }
    
    public var formattedAqiSummary: String {
        "\(aqiEmoji) AQI \(aqi) · \(aqiStatus)"
    }
    
    public var fullLeftSummary: String {
        "\(formattedAqiSummary) · \(formattedWeatherSummary)"
    }
}

public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()
    
    private let storageKey = "picklepark_cached_weather_v6"
    
    // Exact GPS coordinates for Washington Park, Burlingame, CA
    private let latitude = 37.5779
    private let longitude = -122.3481
    
    @Published public var currentWeather: WeatherInfo
    @Published public var isLoading: Bool = false
    
    public init() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(WeatherInfo.self, from: savedData) {
            self.currentWeather = decoded
        } else {
            self.currentWeather = WeatherInfo(
                temperature: 65,
                humidity: 68,
                precipitationPct: 0,
                conditionEmoji: "⛅️",
                conditionDescription: "Partly Cloudy",
                windSpeedMph: 8,
                windGustMph: 11,
                windDirection: "NNW",
                aqi: 38,
                aqiStatus: "Good",
                aqiEmoji: "🟢",
                lastUpdated: Date()
            )
        }
        
        Task {
            await fetchCurrentWeather()
        }
    }
    
    /// Fetches real-time hyper-local weather & US Air Quality Index
    public func fetchCurrentWeather() async {
        await MainActor.run { isLoading = true }
        
        async let weatherResult = fetchGroundWeather()
        async let aqiResult = fetchAirQuality()
        
        let (weather, aqiTuple) = await (weatherResult, aqiResult)
        
        var updated = weather
        if let (aqiVal, aqiText, aqiIco) = aqiTuple {
            updated.aqi = aqiVal
            updated.aqiStatus = aqiText
            updated.aqiEmoji = aqiIco
        }
        
        await MainActor.run {
            self.currentWeather = updated
            self.isLoading = false
        }
        
        if let encoded = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    /// Fetches calibrated METAR ground observations + gusts
    private func fetchGroundWeather() async -> WeatherInfo {
        var baseInfo = self.currentWeather
        
        // 1. Try wttr.in ground station for Burlingame
        if let url = URL(string: "https://wttr.in/Burlingame,CA?format=j1") {
            var request = URLRequest(url: url)
            request.setValue("PicklePark/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 6.0
            
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let conditions = json["current_condition"] as? [[String: Any]],
               let current = conditions.first {
                
                let temp = Int(current["temp_F"] as? String ?? "65") ?? 65
                let hum = Int(current["humidity"] as? String ?? "68") ?? 68
                let wind = Int(current["windspeedMiles"] as? String ?? "8") ?? 8
                let windDir = current["winddir16Point"] as? String ?? "NNW"
                let descList = current["weatherDesc"] as? [[String: Any]]
                let desc = descList?.first?["value"] as? String ?? "Partly Cloudy"
                
                var emoji = "⛅️"
                let lower = desc.lowercased()
                if lower.contains("rain") || lower.contains("shower") { emoji = "🌧️" }
                else if lower.contains("sunny") || lower.contains("clear") { emoji = "☀️" }
                else if lower.contains("overcast") || lower.contains("cloud") { emoji = "☁️" }
                
                baseInfo.temperature = temp
                baseInfo.humidity = hum
                baseInfo.conditionEmoji = emoji
                baseInfo.conditionDescription = desc
                baseInfo.windSpeedMph = wind
                baseInfo.windDirection = windDir
                baseInfo.lastUpdated = Date()
            }
        }
        
        // 2. Supplement wind gusts and precision from Open-Meteo High-Resolution endpoint
        if let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=wind_gusts_10m&wind_speed_unit=mph") {
            if let (data, response) = try? await URLSession.shared.data(from: url),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any] {
                let gust = Int(round(current["wind_gusts_10m"] as? Double ?? Double(baseInfo.windSpeedMph + 3)))
                baseInfo.windGustMph = gust
            }
        }
        
        return baseInfo
    }
    
    /// Fetches EPA US Air Quality Index (AQI) from Open-Meteo Air Quality API
    private func fetchAirQuality() async -> (Int, String, String)? {
        guard let url = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=us_aqi") else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let aqi = current["us_aqi"] as? Int else {
                return nil
            }
            
            let (status, emoji) = parseAQIScale(aqi)
            return (aqi, status, emoji)
        } catch {
            return nil
        }
    }
    
    private func parseAQIScale(_ aqi: Int) -> (status: String, emoji: String) {
        switch aqi {
        case 0...50:
            return ("Good", "🟢")
        case 51...100:
            return ("Okay", "🟡")
        case 101...200:
            return ("Bad", "🔴")
        default:
            return ("Stay Indoors", "🟣")
        }
    }
}
