import Foundation

/// 手表端的金价数据模型（与 macOS 端 `GoldPriceQuote` 对齐）。
struct WatchGoldQuote: Equatable {
    var cnyPerGram: Double
    var updatedAt: Date
    // 官方行情附加信息（回退源不提供时为 nil）
    var yesterdayPrice: Double?
    var changeRatePercent: Double?
    var isMarketClosed: Bool = false
    var source: String = "CZB-JCJ"
}

/// 手表端精简金价服务：优先京东金融 latestPrice（含昨收/涨跌/休市），
/// 失败时回退浙商银行积存金旧接口。
///
/// 说明：这是 macOS 端 `GoldPriceService` 的独立精简副本。手表 MVP 阶段刻意
/// 自带一份，以保持 watch Target 自包含、不依赖 macOS 专属源码目录；
/// 后续如抽取 `Shared` 模块可去重。
enum WatchGoldService {
    static func fetchCNYPerGram() async throws -> WatchGoldQuote {
        do {
            return try await fetchLatest()
        } catch {
            return try await fetchLegacy()
        }
    }

    // MARK: - 京东金融 latestPrice（主源）

    static func fetchLatest() async throws -> WatchGoldQuote {
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

        let payload = try JSONDecoder().decode(WatchJDLatestPriceResponse.self, from: data)
        guard payload.success, payload.resultCode == 0,
              let datas = payload.resultData?.datas,
              let price = Double(datas.price) else {
            throw URLError(.cannotParseResponse)
        }

        var updatedAt = Date()
        if let millis = datas.time.flatMap(Double.init) {
            updatedAt = Date(timeIntervalSince1970: millis / 1000)
        }

        return WatchGoldQuote(
            cnyPerGram: price,
            updatedAt: updatedAt,
            yesterdayPrice: datas.yesterdayPrice.flatMap(Double.init),
            changeRatePercent: datas.upAndDownRate.flatMap { Double($0.replacingOccurrences(of: "%", with: "")) },
            isMarketClosed: datas.demode ?? false,
            source: "JD-MS"
        )
    }

    // MARK: - 浙商旧接口（回退源）

    static func fetchLegacy() async throws -> WatchGoldQuote {
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

        let payload = try JSONDecoder().decode(ZSBankGoldPriceResponse.self, from: data)
        guard payload.success, payload.resultCode == 0,
              payload.resultData.success, payload.resultData.code == "0000" else {
            throw URLError(.cannotParseResponse)
        }

        let goldData = payload.resultData.data
        return WatchGoldQuote(
            cnyPerGram: goldData.lastPrice,
            updatedAt: goldData.tradeDateTime.date ?? Date()
        )
    }
}

private struct WatchJDLatestPriceResponse: Decodable {
    var resultData: ResultData?
    var success: Bool
    var resultCode: Int

    struct ResultData: Decodable {
        var datas: Datas?
    }

    struct Datas: Decodable {
        var price: String
        var yesterdayPrice: String?
        var upAndDownRate: String?
        var demode: Bool?
        var time: String?
    }
}

private struct ZSBankGoldPriceResponse: Decodable {
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
