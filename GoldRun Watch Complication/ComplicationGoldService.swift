import Foundation

/// Complication 扩展专用的精简金价取价：优先京东金融 latestPrice（含涨跌幅），
/// 失败时回退浙商银行积存金旧接口。
///
/// 独立扩展 target 无法直接复用手表 App 的 `WatchGoldService`，
/// 故内置一份等价实现。
enum ComplicationGoldService {
    struct Quote {
        let price: Double
        let time: Date
        var changeRatePercent: Double?
    }

    static func fetchCNYPerGram() async throws -> Quote {
        do {
            return try await fetchLatest()
        } catch {
            return try await fetchLegacy()
        }
    }

    // MARK: - 京东金融 latestPrice（主源）

    private static func fetchLatest() async throws -> Quote {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "ms.jr.jd.com"
        components.path = "/gw/generic/hj/h5/m/latestPrice"

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "reqData={}".data(using: .utf8)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(ComplicationJDLatestResponse.self, from: data)
        guard payload.success, payload.resultCode == 0,
              let datas = payload.resultData?.datas,
              let price = Double(datas.price) else {
            throw URLError(.cannotParseResponse)
        }

        var time = Date()
        if let millis = datas.time.flatMap(Double.init) {
            time = Date(timeIntervalSince1970: millis / 1000)
        }

        return Quote(
            price: price,
            time: time,
            changeRatePercent: datas.upAndDownRate.flatMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        )
    }

    // MARK: - 浙商旧接口（回退源）

    private static func fetchLegacy() async throws -> Quote {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.jdjygold.com"
        components.path = "/gw2/generic/produTools/h5/m/getGoldPrice"
        components.queryItems = [URLQueryItem(name: "goldCode", value: "CZB-JCJ")]

        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(ComplicationGoldResponse.self, from: data)
        guard payload.success, payload.resultCode == 0,
              payload.resultData.success, payload.resultData.code == "0000" else {
            throw URLError(.cannotParseResponse)
        }

        let goldData = payload.resultData.data
        return Quote(price: goldData.lastPrice, time: goldData.tradeDateTime.date ?? Date())
    }
}

private struct ComplicationJDLatestResponse: Decodable {
    var resultData: ResultData?
    var success: Bool
    var resultCode: Int

    struct ResultData: Decodable {
        var datas: Datas?
    }

    struct Datas: Decodable {
        var price: String
        var upAndDownRate: String?
        var time: String?
    }
}

private struct ComplicationGoldResponse: Decodable {
    var resultData: ResultData
    var success: Bool
    var resultCode: Int
    var resultMsg: String

    struct ResultData: Decodable {
        var code: String
        var data: GoldData
        var success: Bool
    }

    struct GoldData: Decodable {
        var lastPrice: Double
        var tradeDateTime: TradeDateTime
    }

    struct TradeDateTime: Decodable {
        var year: Int
        var monthValue: Int
        var dayOfMonth: Int
        var hour: Int
        var minute: Int
        var second: Int

        var date: Date? {
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = TimeZone(identifier: "Asia/Shanghai")
            components.year = year
            components.month = monthValue
            components.day = dayOfMonth
            components.hour = hour
            components.minute = minute
            components.second = second
            return components.date
        }
    }
}
