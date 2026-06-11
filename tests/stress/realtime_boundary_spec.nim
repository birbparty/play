import std/[os, strutils]

import bddy

const repoRoot = currentSourcePath().parentDir.parentDir.parentDir

proc readRepo(path: string): string =
  readFile(repoRoot / path)

proc nimSourcesUnder(path: string): seq[string] =
  for file in walkDirRec(repoRoot / path):
    if file.endsWith(".nim"):
      result.add file

proc betweenMarkers(text, startMarker, endMarker: string): string =
  let startPos = text.find(startMarker)
  let endPos = text.find(endMarker, start = startPos + startMarker.len)
  if startPos < 0 or endPos < 0 or endPos < startPos:
    return ""
  text[startPos ..< endPos]

spec "real-time safety source boundaries":
  it "keeps Nim wrappers from exporting callbacks into SoLoud":
    given:
      let sources = nimSourcesUnder("src/play")
      var exportedCallback = ""
      var procVariable = ""
      var threadHook = ""
    act:
      for source in sources:
        let text = readFile(source)
        if "{.exportc" in text:
          exportedCallback = source
        if "procvar" in text:
          procVariable = source
        if "createThread" in text or "threadvar" in text:
          threadHook = source
    then:
      exportedCallback == ""
      procVariable == ""
      threadHook == ""

  it "keeps platform audio callbacks in C++ mixer code":
    given:
      let ctru = readRepo("vendor/soloud/src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp")
      let vita = readRepo("vendor/soloud/src/backend/vita_homebrew/soloud_vita_homebrew.cpp")
      let raw = readRepo("src/play/bindings/soloud_raw.nim")
      let ctruCallback = ctru.betweenMarkers("static void ctru_ndsp_callback", "static void ctru_ndsp_fill")
      let ctruFill = ctru.betweenMarkers("static void ctru_ndsp_fill", "static void ctru_ndsp_thread")
      let ctruThread = ctru.betweenMarkers("static void ctru_ndsp_thread", "static void ctru_ndsp_cleanup")
      let vitaThread = vita.betweenMarkers("static int vita_thread", "result vita_homebrew_init")
      var ctruCallbackSignalsOnly = false
      var ctruFillMixes = false
      var ctruThreadMixes = false
      var vitaThreadMixes = false
      var rawExportsCallbacks = true
    act:
      ctruCallbackSignalsOnly =
        ctruCallback.contains("LightEvent_Signal(&data->mRefillEvent)") and
        not ctruCallback.contains("mixSigned16")
      ctruFillMixes =
        ctruFill.contains("aData->mSoloud->mixSigned16")
      ctruThreadMixes =
        ctruThread.contains("ctru_ndsp_fill(data, &data->mWaveBuf[i])")
      vitaThreadMixes =
        vitaThread.contains("data->soloud->mixSigned16")
      rawExportsCallbacks = raw.contains("{.exportc") or raw.contains("procvar")
    then:
      ctruCallbackSignalsOnly == true
      ctruFillMixes == true
      ctruThreadMixes == true
      vitaThreadMixes == true
      rawExportsCallbacks == false
