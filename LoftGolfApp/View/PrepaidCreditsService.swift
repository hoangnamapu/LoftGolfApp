import Foundation

struct USPrepayServiceCustomer: Codable {
    let Id: Int
       let RemainingUnits: Int
       let OriginalUnits: Int
       let UnitName: String?
       let EndDate: String?

        var id: Int { Id }
}

final class PrepaidCreditsService {
    typealias CardsCompletion = (Result<[USPrepayServiceCustomer], Error>) -> Void

    static func fetchPrepaidCards(authToken: String, completion: @escaping CardsCompletion) {
        let urlString = "https://beta.uschedule.com/api/loftgolfstudios/prepayservicecustomers"
        guard let url = URL(string: urlString) else {
            completion(.success([]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("c9af66c8-7e45-41f8-a00e-8324df5d3036", forHTTPHeaderField: "X-US-Application-Key")
        request.setValue(authToken, forHTTPHeaderField: "X-US-AuthToken")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.success([])); return }

            do {
                let cards = try JSONDecoder().decode([USPrepayServiceCustomer].self, from: data)
                completion(.success(cards))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
