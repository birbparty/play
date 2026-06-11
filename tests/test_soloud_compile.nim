{.warning[UnusedImport]: off.}
import play/soloud_compile
{.warning[UnusedImport]: on.}

proc Soloud_create(): pointer {.importc, cdecl.}
proc Soloud_destroy(soloud: pointer) {.importc, cdecl.}

when isMainModule:
  let soloud = Soloud_create()
  doAssert soloud != nil
  Soloud_destroy(soloud)
