import os
import strutils
import sequtils

const codePages* = {
  "UTF-8": 65001,
  "SHIFT_JIS": 932,
  "GB2312": 936,
  "KS_C_5601-1987": 949,
  "BIG5": 950,
  "KOI8-R": 20866,
  "KOI8-U": 21866,
  "EUC-JP": 51932,
  "EUC-KR": 51949,
  "HZ-GB-2312": 52936,
  "GB18030": 52936
}

proc getFiles*(path: string, extFilter: seq[string] = @[]): seq[string] =
  var files: seq[string] = @[]
  if path.fileExists:
    files.add(path)
  elif path.dirExists:
    for file in path.walkDirRec: files.add(file.expandFilename)
  files.filterIt((extFilter.len == 0) or extFilter.contains(it.splitFile.ext.toLowerAscii.replace(".", "")))
