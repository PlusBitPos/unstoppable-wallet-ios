import UniswapKit
import RxSwift
import EthereumKit
import Foundation

class UniswapRepository {
    private let swapKit: UniswapKit.Kit

    private var swapData = [String: SwapData]()

    init(swapKit: UniswapKit.Kit) {
        self.swapKit = swapKit
    }

    private func uniswapToken(coin: Coin) throws -> Token {
        if case let .erc20(address, _, _, _) = coin.type {
            return swapKit.token(contractAddress: try Address(hex: address), decimals: coin.decimal)
        }

        return swapKit.etherToken
    }

    private func uniqueCoinId(coinIn: Coin, coinOut: Coin) -> String {
        [coinIn.code, coinOut.code].joined(separator: "_")
    }

    private func save(swapData: SwapData, coinIn: Coin, coinOut: Coin) {
        self.swapData[self.uniqueCoinId(coinIn: coinIn, coinOut: coinOut)] = swapData
    }

    private func swapData(coinIn: Coin, coinOut: Coin) -> Single<SwapData> {
        do {
            let tokenIn = try uniswapToken(coin: coinIn)
            let tokenOut = try uniswapToken(coin: coinOut)

            if let swapData = swapData[uniqueCoinId(coinIn: coinIn, coinOut: coinOut)] {
                return Single.just(swapData)
            }

            return swapKit.swapDataSingle(tokenIn: tokenIn, tokenOut: tokenOut)
                    .map { swapData in
                        self.save(swapData: swapData, coinIn: coinIn, coinOut: coinOut)

                        return swapData
                    }
        } catch {
            return Single.error(error)
        }
    }

    private func tradeData(swapData: SwapData, amount: Decimal, tradeType: TradeType) -> Single<TradeData> {
        do {
            let tradeData: TradeData
            switch tradeType {
            case .exactIn:
                tradeData = try swapKit.bestTradeExactIn(swapData: swapData, amountIn: amount, options: TradeOptions())
            case .exactOut:
                tradeData = try swapKit.bestTradeExactOut(swapData: swapData, amountOut: amount, options: TradeOptions())
            }

            return Single.just(tradeData)
        } catch {
            return Single.error(error)
        }
    }


}

extension UniswapRepository {

    var routerAddress: Address {
        swapKit.routerAddress
    }

    func trade(coinIn: Coin, coinOut: Coin, amount: Decimal, tradeType: TradeType) -> Single<TradeData> {

        swapData(coinIn: coinIn, coinOut: coinOut).flatMap { swapData in
            self.tradeData(swapData: swapData, amount: amount, tradeType: tradeType)
        }
    }

    func swap(tradeData: TradeData, gasLimit: Int, gasPrice: Int) -> Single<TransactionWithInternal> {
        swapKit.swapSingle(tradeData: tradeData, gasLimit: gasLimit, gasPrice: gasPrice)
    }

}