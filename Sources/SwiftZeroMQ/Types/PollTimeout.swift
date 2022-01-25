enum PollTimeout {
    case immediate
    case indefinate
    case microSeconds(Int)
}

extension PollTimeout {
    var value: Int {
        switch self {
        case .immediate:
            return 0
        case .indefinate:
            return -1
        case .microSeconds(let us):
            return us
        }
    }
}
