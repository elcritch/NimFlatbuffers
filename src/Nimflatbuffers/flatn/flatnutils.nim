import strutils

import ../runtime/flatbuffers

import codegen
import parser/Parser
import lexer/Lexer
import lexer/tokenKind
import lexer/token

export builder, table, struct

import os, strformat

proc parseModuleName*(
    filename: string,
): string =
  let
    path = parentDir(filename)
    resourcePath = filename

  echo fmt"{path=}"
  echo fmt"{resourcePath=}"

  var
    file = readFile(resourcepath)
    lexer: Lexer
    parser: Parser

  lexer.initLexer(file)
  lexer.generate_tokens()

  parser.initParser(lexer.tokens)
  parser.parse()

  for node in parser.nodes:
    if node.kind == tkNamespace:
      return node.lexeme.replace(".", "_") & ".nim"
  ## shouldn't get here
  raiseAssert "couldn't parse namespace"