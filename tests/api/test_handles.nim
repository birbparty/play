import common/test_helpers
import play
import std/sequtils
import std/strutils
import std/times

type TestCase = object
  name: string
  ok: bool
  message: string
  duration: float

var cases: seq[TestCase]

proc xmlEscape(value: string): string =
  result = newStringOfCap(value.len)
  for ch in value:
    case ch
    of '<': result.add("&lt;")
    of '>': result.add("&gt;")
    of '&': result.add("&amp;")
    of '"': result.add("&quot;")
    of '\'': result.add("&apos;")
    else:
      if ch < ' ' and ch notin {'\t', '\n', '\r'}:
        result.add('?')
      else:
        result.add(ch)

proc writeJUnit(path: string) =
  if path.len == 0:
    return

  let failures = cases.countIt(not it.ok)
  var totalTime = 0.0
  for testCase in cases:
    totalTime += testCase.duration

  var output = ""
  output.add("""<?xml version="1.0" encoding="UTF-8"?>""" & "\n")
  output.add(
    "<testsuites tests=\"" & $cases.len & "\" failures=\"" & $failures &
    "\" errors=\"0\" skipped=\"0\" time=\"" & formatFloat(totalTime, ffDecimal, 5) & "\">\n")
  output.add(
    "  <testsuite name=\"public handle operations API smoke\" " &
    "classname=\"public handle operations API smoke\" tests=\"" & $cases.len &
    "\" failures=\"" & $failures & "\" errors=\"0\" skipped=\"0\" time=\"" &
    formatFloat(totalTime, ffDecimal, 5) & "\" timestamp=\"" &
    now().utc.format("yyyy-MM-dd'T'HH:mm:ss") & "Z\">\n")

  for testCase in cases:
    output.add(
      "    <testcase name=\"" & xmlEscape(testCase.name) &
      "\" classname=\"public handle operations API smoke\" time=\"" &
      formatFloat(testCase.duration, ffDecimal, 5) & "\">")
    if testCase.ok:
      output.add("\n")
    else:
      output.add(
        "\n      <failure message=\"" & xmlEscape(testCase.message) & "\">" &
        xmlEscape(testCase.message) & "</failure>\n")
    output.add("    </testcase>\n")

  output.add("  </testsuite>\n")
  output.add("</testsuites>\n")
  path.writeFile(output)

template runCase(caseName: string, body: untyped) =
  block:
    echo "case start: ", caseName
    let started = epochTime()
    var ok = true
    var message = ""
    try:
      body
    except AssertionDefect as error:
      ok = false
      message = error.msg
    except CatchableError as error:
      ok = false
      message = $error.name & ": " & error.msg
    cases.add(TestCase(name: caseName, ok: ok, message: message, duration: epochTime() - started))
    echo "case ", (if ok: "ok: " else: "failed: "), caseName

proc assertInvalid(result: PlayResult) =
  doAssert result.ok == false
  doAssert result.error.kind == invalidHandle

runCase("rejects dead handles before init"):
  assertInvalid(pause(noHandle))
  assertInvalid(resume(noHandle))
  assertInvalid(stop(noHandle))
  assertInvalid(setLooping(noHandle, true))
  assertInvalid(setVolume(noHandle, 1.0'f32))
  doAssert noHandle.isValid == false

runCase("pauses, resumes, loops, changes volume, and stops a live sound handle"):
  let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
  try:
    doAssert soundResult.ok

    let initResult = init(initOptions(backend = noSoundBackend))
    doAssert initResult.ok

    let handle = play(soundResult.sound)
    doAssert handle.isValid
    doAssert pause(handle).ok
    doAssert resume(handle).ok
    doAssert setLooping(handle, true).ok
    doAssert setVolume(handle, 0.5'f32).ok
    doAssert stop(handle).ok
    assertInvalid(stop(handle))
    doAssert handle.isValid == false
  finally:
    if soundResult.ok:
      soundResult.sound.dispose()
    shutdown()

runCase("keeps stopped handles invalid after shutdown"):
  let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
  var disposed = false
  try:
    doAssert soundResult.ok

    let initResult = init(initOptions(backend = noSoundBackend))
    doAssert initResult.ok

    let handle = play(soundResult.sound)
    doAssert handle.isValid
    doAssert stop(handle).ok
    doAssert handle.isValid == false
    soundResult.sound.dispose()
    disposed = true
    shutdown()
    doAssert handle.isValid == false
    assertInvalid(pause(handle))
  finally:
    if soundResult.ok and not disposed:
      soundResult.sound.dispose()
    shutdown()

runCase("plays and stops a public handle under NULL backend"):
  let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
  try:
    doAssert soundResult.ok

    let initResult = init(initOptions(backend = nullBackend))
    doAssert initResult.ok

    let handle = play(soundResult.sound)
    doAssert handle != noHandle
    doAssert stop(handle).ok
  finally:
    if soundResult.ok:
      soundResult.sound.dispose()
    shutdown()

const bddyJunit {.strdefine.} = ""
echo "bddyJunit path: ", (if bddyJunit.len == 0: "<empty>" else: bddyJunit)
writeJUnit(bddyJunit)

if cases.anyIt(not it.ok):
  quit(1)
