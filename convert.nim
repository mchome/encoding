import os
import encodings
import streams

proc conventFromFile*(srcPath: string, destPath: string, lineEnding: string = "",
                     srcEncoding: string = "UTF-8", destEncoding: string = "UTF-8",
                     enableBom: bool = false): void =
  if (srcPath.len < 1) or (destPath.len < 1) or (not srcPath.fileExists) or (srcEncoding == destEncoding): return
  if not destPath.splitPath.head.dirExists: destPath.splitPath.head.createDir

  let bom = @[0xEF'i8, 0xBB'i8, 0xBF'i8]

  if srcPath == destPath:
    let data = srcPath.readFile
    let f = destPath.open(fmWrite)
    try:
      if enableBom: discard f.writeBytes(bom, 0, bom.len)
      f.write(data.convert(destEncoding, srcEncoding))
    finally:
      f.close
  else:
    let
      enc = encodings.open(destEncoding, srcEncoding)
      srcFs = newFileStream(srcPath, fmRead)
      destFs = newFileStream(destPath, fmWrite)
    defer:
      enc.close
      srcFs.close
      destfs.close
    if srcFs.isNil: echo "Can't open source path."
    if destFs.isNil: echo "Can't open destination path."
    if srcFs.isNil or destFs.isNil: return

    var data = ""
    var maxLine = 0
    var currentLine = 0
    var lastNewline = false
    var linkBreak = lineEnding
    while true:
      if not srcFs.readLine(data):
        srcFs.setPosition(srcFs.getPosition - 1)
        let c = srcFs.peekChar
        if c == '\n' or c == '\r': lastNewline = true
        if not (lineEnding.len > 0): # detect linebreak & follow original linebreak
          srcFs.setPosition(srcFs.getPosition - 1)
          let c2 = srcFs.peekChar
          if c == '\r': linkBreak = "\r"
          elif c2 == '\r': linkBreak = "\r\n"
          else: linkBreak = "\n"
        break
      else: maxLine.inc
    srcFs.setPosition(0)
    if enableBom: destFs.writeData(bom.unsafeAddr, bom.sizeof)

    while true:
      if not srcFs.readLine(data): break
      else: currentLine.inc
      destFs.write(enc.convert(data), if currentLine < maxLine or lastNewline: linkBreak else: "")

when isMainModule:
  conventFromFile("test.txt", "test.txt", srcEncoding="SHIFT_JIS")
