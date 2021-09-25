from os import fileExists
import strutils
import nimterop/[build, cimport]

const
  baseDir = getProjectCacheDir("nim-uchardet")
  srcDir = baseDir/"uchardet"
  includeDir = srcDir/"src"
  gitUrl = "https://gitlab.freedesktop.org/uchardet/uchardet.git"

const defs = """
  uchardetSetVer=v0.0.7
  uchardetGit
  uchardetStatic
"""

setDefines(defs.splitLines())

getHeader(
  "uchardet.h",
  giturl = gitUrl,
  outdir = srcDir,
)

cOverride:
  type
    uchardet_t = ptr object
    Uchardet* = uchardet_t

when not isDefined(uchardetStatic):
  cImport(includeDir/"uchardet.h", recurse = true, flags = "-f=ast2 -H",
      dynlib = "uchardetLPath")
else:
  cImport(includeDir/"uchardet.h", recurse = true, flags = "-f=ast2 -H")
  {.passL: "-lstdc++ -static-libgcc -static".}


const
  BufSize = 2 shl 15

proc readFile(filename: string, len: int64): TaintedString {.tags: [
    ReadIOEffect].} =
  var f: File
  if f.open(filename):
    try:
      result = len.newString
      let bytes = f.readBuffer(addr(result[0]), len)
      if f.endOfFile:
        if bytes < len:
          result.setLen(bytes)
    finally:
      f.close

proc getBufferCharset*(data: string): string =
  if data.len < 1: return

  let ud: Uchardet = uchardet_new()
  if ud.uchardet_handle_data(data, data.len.csize_t) != 0:
    echo "error to handle data"
    ud.uchardet_data_end
    ud.uchardet_delete
    return
  ud.uchardet_data_end
  result = $ud.uchardet_get_charset
  ud.uchardet_delete

proc getFileCharset*(path: string; maxlen: int = BufSize): string =
  if path.len > 0 and path.fileExists:
    var content = ""
    if maxlen > 0:
      content = path.readFile(maxlen)
    else:
      content = path.readFile
    result = content.getBufferCharset


when isMainModule:
  import encodings
  let text = "戝暥帤彫暥帤偺堘偄傪柍帇偡傞".convert("GB2312", "UTF-8")
  echo text.getBufferCharset
  assert text.convert("UTF-8", text.getBufferCharset) == "大文字小文字の違いを無視する"
