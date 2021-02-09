import Swift0MQ

func withPubSubPair(_ block: (Socket, Socket) throws -> Void) throws {
    let (ctx, subscriber, publisher) = try contextAndPairWithTypes(first: .subscribe, second: .publish)
    try block(publisher, subscriber)
    try ctx.shutdown()
}

func withRequestReplyPair(_ block: (Socket, Socket) throws -> Void) throws {
    let (ctx, first, second) = try contextAndPairWithTypes(first: .request, second: .reply)

    try block(first, second)

    try ctx.shutdown()
}

func withPushPullPair(_ block: (Socket, Socket) throws -> Void) throws {
    let (ctx, first, second) = try contextAndPairWithTypes(first: .push, second: .pull)

    try block(first, second)

    try ctx.shutdown()
}

func with(_ first: SocketType, and second: SocketType, block: (Socket, Socket) throws -> Void) throws {
    let (ctx, first, second) = try contextAndPairWithTypes(first: first, second: second)

    try block(first, second)

    try ctx.shutdown()
}

private func contextAndPairWithTypes(first: SocketType, second: SocketType) throws -> (ZMQ, Socket, Socket) {
    let zmq = try ZMQ()

    let socketA = try zmq.socket(type: first)
    _ = try socketA.connect(to: "inproc://testing")

    let socketB = try zmq.socket(type: second)
    _ = try socketB.bind(to: "inproc://testing")

    return (zmq, socketA, socketB)
}
