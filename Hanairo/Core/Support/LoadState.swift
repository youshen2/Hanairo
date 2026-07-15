import Foundation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}
