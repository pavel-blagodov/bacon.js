Bacon = (require "../src/Bacon").Bacon

describe "Bacon.later", ->
  it "should send single event and end", ->
    expectStreamEvents(
      -> Bacon.later(10, "lol")
      ["lol"])

describe "Bacon.sequentially", ->
  it "should send given events and end", ->
    expectStreamEvents(
      -> Bacon.sequentially(10, ["lol", "wut"])
      ["lol", "wut"])

describe "Bacon.interval", ->
  it "repeats single element indefinitely", ->
    expectStreamEvents(
      -> Bacon.interval(10, "x").take(3)
      ["x", "x", "x"])

describe "EventStream.filter", -> 
  it "should filter values", ->
    expectStreamEvents(
      -> repeat(10, [1, 2, 3]).take(3).filter(lessThan(3))
      [1, 2])

describe "EventStream.map", ->
  it "should map with given function", ->
    expectStreamEvents(
      -> repeat(10, [1, 2, 3]).take(3).map(times(2))
      [2, 4, 6])

describe "EventStream.takeWhile", ->
  it "should take while predicate is true", ->
    expectStreamEvents(
      -> repeat(10, [1, 2, 3]).takeWhile(lessThan(3))
      [1, 2])

describe "EventStream.distinctUntilChanged", ->
  it "drops duplicates", ->
    expectStreamEvents(
      -> repeat(10, [1, 2, 2, 3, 1]).take(5).distinctUntilChanged()
    [1, 2, 3, 1])

describe "EventStream.flatMap", ->
  it "should spawn new stream for each value and collect results into a single stream", ->
    expectStreamEvents(
      -> repeat(10, [1, 2]).take(2).flatMap (value) ->
        Bacon.sequentially(100, [value, value])
      [1, 2, 1, 2])

describe "EventStream.switch", ->
  it "spawns new streams but collects values from the latest spawned stream only", ->
    expectStreamEvents(
      -> repeat(30, [1, 2]).take(2).switch (value) ->
        Bacon.sequentially(20, [value, value])
      [1, 2, 2])

describe "EventStream.merge", ->
  it "merges two streams and ends when both are exhausted", ->
    expectStreamEvents( 
      ->
        left = repeat(10, [1, 2, 3]).take(3)
        right = repeat(100, [4, 5, 6]).take(3)
        left.merge(right)
      [1, 2, 3, 4, 5, 6])
  it "respects subscriber return value", ->
    expectStreamEvents(
      ->
        left = repeat(20, [1, 3]).take(3)
        right = repeat(30, [2]).take(3)
        left.merge(right).takeWhile(lessThan(2))
      [1])

describe "EventStream.delay", ->
  it "delays all events by given delay in milliseconds", ->
    expectStreamEvents(
      ->
        left = repeat(20, [1, 2, 3]).take(3)
        right = repeat(10, [4, 5, 6]).delay(100).take(3)
        left.merge(right)
      [1, 2, 3, 4, 5, 6])

describe "EventStream.throttle", ->
  it "throttles input by given delay", ->
    expectStreamEvents(
      -> repeat(10, [1, 2]).take(2).throttle(20)
      [2])

describe "EventStream.bufferWithTime", ->
  it "returns events in bursts", ->
    expectStreamEvents(
      -> repeat(10, [1, 2, 3, 4, 5, 6, 7]).take(7).bufferWithTime(33)
      [[1, 2, 3, 4], [5, 6, 7]])

describe "EventStream.takeUntil", ->
  it "takes elements from source until an event appears in the other stream", ->
    expectStreamEvents(
      ->
        src = repeat(30, [1, 2, 3])
        stopper = repeat(70, ["stop!"])
        src.takeUntil(stopper)
      [1, 2])

describe "Bacon.pushStream", ->
  it "delivers pushed events", ->
    expectStreamEvents(
      ->
        s = Bacon.pushStream()
        s.push "pullMe"
        soon ->
          s.push "pushMe"
          s.end()
        s
      ["pushMe"])

describe "Property", ->
  it "delivers current value and changes to subscribers", ->
    expectPropertyEvents(
      ->
        s = Bacon.pushStream()
        p = s.toProperty("a")
        soon ->
          s.push "b"
          s.end()
        p
      ["a", "b"])

describe "Property.map", ->
  it "maps property values", ->
    expectPropertyEvents(
      ->
        s = Bacon.pushStream()
        p = s.toProperty(1).map(times(2))
        soon ->
          s.push 2
          s.end()
        p
      [2, 4])

describe "Property.changes", ->
  it "yields property change events", ->
    expectPropertyEvents(
      ->
        s = Bacon.pushStream()
        p = s.toProperty("a").changes()
        soon ->
          s.push "b"
          s.end()
        p
      ["b"])

describe "Property.combine", ->
  it "combines latest values of two properties", ->
    expectPropertyEvents( 
      ->
        left = repeat(20, [1, 2, 3]).take(3).toProperty()
        right = repeat(20, [4, 5, 6]).delay(10).take(3).toProperty()
        left.combine(right, add)
      [5, 6, 7, 8, 9])

describe "Property.sampledBy", -> 
  it "samples property at events, resulting to EventStream", ->
    expectStreamEvents(
      ->
        prop = repeat(20, [1, 2]).take(2).toProperty()
        stream = repeat(30, ["troll"]).take(4)
        prop.sampledBy(stream)
      [1, 2, 2, 2])

describe "Property.sample", -> 
  it "samples property by given interval", ->
    expectStreamEvents(
      ->
        prop = repeat(20, [1, 2]).take(2).toProperty()
        prop.sample(30).take(4)
      [1, 2, 2, 2])

describe "EventStream.scan", ->
  it "accumulates values with given seed and accumulator function", ->
    expectPropertyEvents(
      -> repeat(10, [1, 2, 3]).take(3).scan(0, add)
      [0, 1, 3, 6])

describe "Observable.subscribe and onValue", ->
  it "returns a dispose() for unsubscribing", ->
    s = Bacon.pushStream()
    values = []
    dispose = s.onValue (value) -> values.push value
    s.push "lol"
    dispose()
    s.push "wut"
    expect(values).toEqual(["lol"])


lessThan = (limit) -> 
  (x) -> x < limit

times = (factor) ->
  (x) -> x * factor

add = (x, y) -> x + y

expectPropertyEvents = (src, expectedEvents) ->
  runs -> verifySingleSubscriber src(), expectedEvents

expectStreamEvents = (src, expectedEvents) ->
  runs -> verifySingleSubscriber src(), expectedEvents
  runs -> verifySwitching src(), expectedEvents

verifySingleSubscriber = (src, expectedEvents) ->
  events = []
  ended = false
  streamEnded = -> ended
  runs -> src.subscribe (event) -> 
    if event.isEnd()
      ended = true
    else
      events.push(event.value)

  waitsFor streamEnded, 1000
  runs -> 
    expect(events).toEqual(expectedEvents)
    verifyCleanup()

# get each event with new subscriber
verifySwitching = (src, expectedEvents) ->
  events = []
  ended = false
  streamEnded = -> ended
  newSink = -> 
    (event) ->
      if event.isEnd()
        ended = true
      else
        events.push(event.value)
        src.subscribe(newSink())
        Bacon.noMore
  runs -> 
    src.subscribe(newSink())
  waitsFor streamEnded, 1000
  runs -> 
    expect(events).toEqual(expectedEvents)
    verifyCleanup()

seqs = []
soon = (f) -> setTimeout f, 100
repeat = (interval, values) ->
  source = Bacon.repeatedly(interval, values)
  seqs.push({ values : values, source : source })
  source

verifyCleanup = ->
  for seq in seqs
    #console.log("verify cleanup: #{seq.values}")
    expect(seq.source.hasSubscribers()).toEqual(false)
  seqs = []

