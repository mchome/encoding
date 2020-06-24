import wNim/[wApp, wFrame, wIcon, wMenu, wStatusBar, wFileDialog, wDirDialog, wMessageDialog,
             wPanel, wNoteBook, wStaticBox, wTextCtrl, wFont, wDataObject, wStaticText, wComboBox, wButton,
             wListCtrl]
import os
import encodings
import strutils
import sequtils
import libuchardet
import convert
import utils

type
  MenuID = enum
    idAddFiles = 1, idAddDir, idExit
    idBomEnable, idBomDisable
    idAbout

const
  codePagesName = codePages.unzip[0]
  bom: seq[int8] = @[0xEF'i8, 0xBB'i8, 0xBF'i8]

proc main(): void =
  var enableBom = true
  var currentFile: tuple[text: string, srcEncoding: string, destEncoding: string, dest: string] = ("", codePagesName[0], codePagesName[0], "")
  var fileList: seq[tuple[src: string, encoding: string, dest: string]] = @[]


  let app = App()
  let frame = Frame(title="Encoding Converter")
  frame.dpiAutoScale:
    frame.size = (600, 495)
    frame.minSize = (470, 250)

  let menubar = frame.MenuBar
  let statusbar = frame.StatusBar

  let menuFile = menubar.Menu("&File")
  menuFile.append(idAddFiles, "&Add files", " "&"Add files.")
  menuFile.append(idAddDir, "&Add folder", " "&"Add folder.")
  menuFile.append(idExit, "&Exit", " "&"Exit program.")

  let menuBom = menuBar.Menu("&Bom")
  menuBom.appendRadioItem(idBomEnable, "&Enable Bom", " "&"Enable byte order mark to the file while saving.").check
  menuBom.appendRadioItem(idBomDisable, "&Disable Bom", " "&"Disable byte order mark to the file while saving.")

  let menuAbout = menuBar.Menu("&About")
  menuAbout.append(idAbout, "&About", " "&"About this.")

  let notebook = frame.NoteBook
  notebook.setDropTarget
  let nbBatch = notebook.addPage("Batch")
  let nbPreview =  notebook.addPage("Preview")

  let pBatch = nbBatch.Panel
  let bLabelDest = pBatch.StaticText(label="Encoding", style=wAlignMiddle)
  let bCbDestEncoding = pBatch.ComboBox(value=codePagesName[0], choices=codePagesName, style=wCbReadOnly)
  let bLabelFilter = pBatch.StaticText(label="Filter", style=wAlignMiddle)
  let bTcFilter = pBatch.TextCtrl(value="txt;config")
  bTcFilter.font = Font(12)
  let bBtnClear = pBatch.Button(label="Clear")
  let bBtnConvert = pBatch.Button(label="Convert")

  let lcFiles = pBatch.ListCtrl(style=wLcReport or wLcNoSortHeader)
  lcFiles.insertColumn(0, "Source Path", width=200)
  lcFiles.insertColumn(1, "Encoding", width=100)
  lcFiles.insertColumn(2, "Destination Path", width=200)
  proc layoutBatch(): void =
    nbBatch.autolayout """
      spacing: 0
      HV: |[pBatch]|

      outer: pBatch
      spacing: 10
      H: |-10-[bLabelDest(53)]-[bCbDestEncoding]-10-[bLabelFilter(28)]-[bTcFilter(bCbDestEncoding)]-10-[bBtnClear(70)]-10-[bBtnConvert(70)]-10-|
      H: |-[lcFiles]-|
      V: |-10-[bLabelDest, bCbDestEncoding, bLabelFilter, bTcFilter, bBtnClear, bBtnConvert]-10-[lcFiles]-10-]
      C: lcFiles.height = pBatch.height - 50
    """

  let pPreview = nbPreview.Panel
  let pLabelSrc = pPreview.StaticText(label="Source", style=wAlignMiddle)
  let pCbSrcEncoding = pPreview.ComboBox(value=currentFile.srcEncoding, choices=codePagesName, style=wCbReadOnly)
  let pLabelDest = pPreview.StaticText(label="Destination", style=wAlignMiddle)
  let pCbDestEncoding = pPreview.ComboBox(value=currentFile.destEncoding, choices=codePagesName, style=wCbReadOnly)
  let pBtnSaveTo = pPreview.Button(label="Save to...")
  let pBtnSaveOverwrite = pPreview.Button(label="Overwrite")
  pBtnSaveOverwrite.disable

  let sbSrc = pPreview.StaticBox(label="Source")
  let sbDest = pPreview.StaticBox(label="Destination")
  let tcSrc = pPreview.TextCtrl(style=wTeMultiLine or wTeProcessTab or wTeDontWrap or wVScroll)
  let tcDest = pPreview.TextCtrl(style=wTeMultiLine or wTeProcessTab or wTeDontWrap or wTeReadOnly or wVScroll)
  let font = Font(10)
  tcSrc.font = font
  tcDest.font = font
  proc layoutPreview(): void =
    nbPreview.autolayout """
      spacing: 0
      HV: |[pPreview]|

      outer: pPreview
      spacing: 10
      H: |-10-[pLabelSrc(40)]-[pCbSrcEncoding]-10-[pLabelDest(65)]-[pCbDestEncoding]-10-[pBtnSaveTo(70)]-10-[pBtnSaveOverwrite(pBtnSaveTo.width)]-10-|
      H: |-10-[sbSrc]-[sbDest(sbSrc)]-10-|
      V: |-8-[pLabelSrc, pCbSrcEncoding, pLabelDest, pCbDestEncoding, pBtnSaveTo, pBtnSaveOverwrite]-5-[sbSrc, sbDest]-5-]
      C: sbSrc.height = pPreview.height - 45
      C: sbDest.height = sbSrc.height
      C: pCbSrcEncoding.width = pCbDestEncoding.width

      outer: sbSrc
      spacing: 0
      HV: |[tcSrc]|

      outer: sbDest
      spacing: 0
      HV: |[tcDest]|
    """

  proc addFiles(files: seq[string]): void =
    let srcFiles = fileList.mapIt(it.src)
    let filters = bTcFilter.value.split(";")
    for file in files:
      if not srcFiles.contains(file):
        if file.existsFile and filters.contains(file.splitFile.ext.toLowerAscii.replace(".", "")):
          var charset = file.getFileCharset
          if (charset.len < 1) or (not codePagesName.contains(charset)): charset = codePagesName[0]
          else: statusbar.setStatusText(file&"'s encoding is detected: "&charset)
          fileList.add((file, charset, file))
          let i = lcFiles.appendItem(file)
          lcFiles.setItem(index=i, col=1, text=charset)
          lcFiles.setItem(index=i, col=2, text=file)
        elif file.existsDir:
          file.getFiles(filters).addFiles
  proc updateFiles(): void =
    lcFiles.deleteAllItems
    for file in fileList:
      let i = lcFiles.appendItem(file.src)
      lcFiles.setItem(index=i, col=1, text=file.encoding)
      lcFiles.setItem(index=i, col=2, text=file.dest)

  notebook.wEvent_DragEnter do (event: wEvent):
    let dataObject = event.dataObject
    if dataObject.isFiles or dataObject.isText:
      event.effect = wDragCopy
  notebook.wEvent_Drop do (event: wEvent):
    let dataObject = event.dataObject
    if dataObject.isFiles:
      dataObject.files.addFiles
    elif dataObject.isText:
      pBtnSaveOverwrite.disable
      tcSrc.value = dataObject.text

  frame.idAddFiles do ():
    let files = frame.FileDialog("Adding Files",
                                 wildcard="Text Files(*.txt)|*.txt|All Files(*.*)|*.*",
                                 style=wFdMultiple).display
    if files.len > 0:
      files.addFiles
  frame.idAddDir do ():
    let dir = frame.DirDialog("Add a folder").display
    if dir.len > 0:
      dir.getFiles(bTcFilter.value.split(";")).addFiles
  frame.idExit do (): frame.close
  frame.idBomEnable do (): enableBom = true
  frame.idBomDisable do (): enableBom = false
  frame.idAbout do ():
    frame.MessageDialog("A program can help you to convert files' encoding to UTF-8.\n"&"Compiled at "&CompileDate.replace("-", "/")&" "&CompileTime&".",
                        " "&"About This", style=wIconInformation).display

  tcSrc.wEvent_Text do ():
    pBtnSaveOverwrite.disable
    currentFile.text = tcSrc.value
    currentFile.dest = ""
    tcDest.changeValue(currentFile.text.convert(currentFile.srcEncoding, "UTF-8").convert("UTF-8", currentFile.destEncoding))
  pCbSrcEncoding.wEvent_ComboBox do ():
    let encoding = pCbSrcEncoding.value
    if not (encoding == currentFile.srcEncoding):
      currentFile.srcEncoding = encoding
      if currentFile.srcEncoding == "UTF-8":
        tcDest.changeValue(currentFile.text.convert("UTF-8", currentFile.destEncoding))
      else:
        tcDest.changeValue(currentFile.text.convert(currentFile.srcEncoding, "UTF-8").convert("UTF-8", currentFile.destEncoding))
  pCbDestEncoding.wEvent_ComboBox do ():
    let encoding = pCbDestEncoding.value
    if not (encoding == currentFile.destEncoding):
      currentFile.destEncoding = encoding
      if currentFile.srcEncoding == "UTF-8":
        tcDest.changeValue(currentFile.text.convert("UTF-8", currentFile.destEncoding))
      else:
        tcDest.changeValue(currentFile.text.convert(currentFile.srcEncoding, "UTF-8").convert("UTF-8", currentFile.destEncoding))
  pBtnSaveTo.wEvent_Button do ():
    let file = frame.FileDialog("Saving File",
                                wildcard="Text Files(*.txt)|*.txt|All Files(*.*)|*.*",
                                style=wFdSave).display
    if file.len == 1:
      let f = file[0].open(fmWrite)
      try:
        if enableBom: discard f.writeBytes(bom, 0, bom.len)
        f.write(tcDest.value)
        statusbar.setStatusText("Saved to "&file[0])
        currentFile.dest = file[0]
        pBtnSaveOverwrite.enable
      except IOError:
        statusbar.setStatusText(getCurrentExceptionMsg())
      finally:
        f.close
  pBtnSaveOverwrite.wEvent_Button do ():
    let f = currentFile.dest.open(fmWrite)
    try:
      if enableBom: discard f.writeBytes(bom, 0, bom.len)
      f.write(tcDest.value)
      statusbar.setStatusText("Saved to "&currentFile.dest)
    except IOError:
      statusbar.setStatusText(getCurrentExceptionMsg())
    finally:
      f.close

  lcFiles.wEvent_KeyUp do (event: wEvent):
    if event.keyCode == wKey_Delete:
      echo "TBD: delete item" #TODO
  bCbDestEncoding.wEvent_ComboBox do ():
    for file in fileList.mitems: file.encoding = bCbDestEncoding.value
    updateFiles()
  lcFiles.wEvent_ListItemActivated do (event: wEvent):
    let file = fileList[event.index]
    currentFile = (file.src.readFile, codePagesName[0], file.encoding, file.dest)
    tcSrc.changeValue(currentFile.text)
    pCbSrcEncoding.changeValue(codePagesName[0])
    pCbDestEncoding.changeValue(currentFile.destEncoding)
    tcDest.changeValue(currentFile.text.convert("UTF-8", currentFile.destEncoding))
    pBtnSaveOverwrite.enable
    discard notebook.page(2)

  bBtnClear.wEvent_Button do ():
    fileList = @[]
    lcFiles.deleteAllItems
  bBtnConvert.wEvent_Button do ():
    try:
      for file in fileList:
        file.src.conventFromFile(file.dest, srcEncoding=file.encoding, enableBom=enableBom)
        statusbar.setStatusText("Converting "&file.src)
    except Exception:
      statusbar.setStatusText(getCurrentExceptionMsg())
    finally:
      fileList = @[]
      lcFiles.deleteAllItems

  nbPreview.wEvent_Size do ():
    layoutPreview()
  nbBatch.wEvent_Size do ():
    layoutBatch()

  layoutPreview()
  layoutBatch()
  frame.center
  frame.show
  app.mainLoop

main()
