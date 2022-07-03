import os, strutils, strformat, options

import flatnutils
import codegen

proc generate(
    filenames: seq[string],
    outputDir = "output/",
) = 
  ## generate codes
  if filenames.len() == 0:
    echo("error: must provide filenames")
    quit(1)
  echo "code gen: files: ", filenames
  for filename in filenames:
    echo "code gen: file: ", filename

    let
      resourcePath = filename.absolutePath()
      modName = parseModuleName(resourcePath)
      outputFileName = outputDir / modName
    echo fmt"flatbuffer namespace: {modName=}"
    echo fmt"flatbuffer namespace: {outputFileName=}"

    generateCodeImpl(resourcePath, outputFileName)

when isMainModule:
  import cligen;
  dispatch generate