//
//  ContentViewModel.swift
//  CryptoAsyncAwait
//
//  Created by Stephan Dowless on 1/5/23.
//

import Foundation

@MainActor
class ContentViewModel: ObservableObject {
    @Published var coins = [Coin]()
    @Published var error: CoinError?
    
    let BASE_URL = "https://api.coingecko.com/api/v3/coins/"
    
    var urlString: String {
        return  "\(BASE_URL)markets?vs_currency=usd&order=market_cap_desc&per_page=50&page=1&price_change_percentage=24h"
    }
    
    init() {
        loadData()
    }
    
    func handleRefresh() {
        coins.removeAll()
        loadData()
    }
}
//MARK: - Async/Await
extension ContentViewModel {
    // mark this func @MainActor to let compiler know
    // this func is working on main thread
    // This is equal to the block DispatchQueue.main.async{}
    @MainActor
    func fetchCoinsAsync() async throws {
        do {
            guard let url = URL(string: urlString) else {
                // Don't need "return".
                // What after "throw" won't exec, "throw" is like "return"
                throw CoinError.invalidURL
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CoinError.serverError }
            guard let coins = try? JSONDecoder().decode([Coin].self, from: data) else { throw CoinError.invalidData }
            self.coins = coins
        } catch CoinError.invalidData {
            self.error = CoinError.invalidData
        } catch CoinError.serverError {
            self.error = CoinError.serverError
        } catch CoinError.invalidURL {
            self.error = CoinError.invalidURL
        } catch {
            // Default catch error
            // Should have this one in case error doesn't fall into other cases.
            // It happened when I tried to catch each case of error.
            self.error = CoinError.unkown(error)
        }
    }
    
    func loadData() {
        Task {
            try await fetchCoinsAsync()
        }
    }
    
    // If we don't catch error in fetchCoinsAsync(),
    // we can catch it here
    func loadDataWithCatchError() {
        Task {
            do {
                try await fetchCoinsAsync()
            } catch CoinError.invalidData {
                print("Invalid data")
            } catch CoinError.serverError {
                self.error = CoinError.serverError
            } catch CoinError.invalidURL {
                print("Invalid URL")
            } catch {
                // Default catch error
                // Should have this one in case error doesn't fall into other cases.
                self.error = CoinError.unkown(error)
            }
        }
    }
}

// MARK: - URLSession

extension ContentViewModel {
    func fetchCoinsWithURLSession() {
        guard let url = URL(string: urlString) else {
            print("DEBUG: Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
                        
            DispatchQueue.main.async {
                if let error = error {
                    print("DEBUG: Error \(error)")
                    return
                }
                
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    print("DEBUG: Server error")
                    return
                }
                
                guard let data = data else {
                    print("DEBUG: Invalid data")
                    return
                }
                
                guard let coins = try? JSONDecoder().decode([Coin].self, from: data) else {
                    print("DEBUG: Invalid data")
                    return
                }
                            
                self.coins = coins
            }
        }.resume()
    }
}
