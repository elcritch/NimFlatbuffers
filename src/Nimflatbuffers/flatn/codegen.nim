# TODO: Invertir orden de Prepend de las estructuras
# TODO: Averiguar porque no lee la información correctamente
import system except NimNode
import std/[os]
import cdecl/compiler/macros2

from std/sequtils import toSeq
from std/strutils import split, replace, contains, parseInt, join
from std/algorithm import reverse, reversed

import utils/util
import parser/[nodes, Parser]
import lexer/[Lexer, tokenKind]

var
   structs {.compileTime.} : seq[Node]
   tabls {.compileTime.} : seq[Node]
   enums {.compileTime.} : seq[Node]
   unions {.compileTime.} : seq[Node]


iterator namesE(nodes: var seq[Node]): string =
   for node in nodes:
      yield node.children[0].children[0].lexeme

iterator names(nodes: var seq[Node]): string =
   for node in nodes:
      yield node.children[0].lexeme

proc getName(nodes: var seq[Node], name: string): Node =
   for node in nodes:
      if node.children[0].children[0].lexeme == name:
         return node

proc getEnumName(node: Node): string =
   node.children[0].children[0].lexeme

proc findStruct(ident: string): Node {.used.} =
   for node in structs:
      if node.lexeme == ident:
         return node

proc findTable(ident: string): Node {.used.} =
   for node in tabls:
      if node.lexeme == ident:
         return node

proc findEnum(ident: string): Node {.used.} =
   for node in enums:
      if node.lexeme == ident:
         return node

iterator toEnumFields(node: Node): NimNode =
   for child in node.children[1].children:
      yield newNimNode(nnkEnumFieldDef).add(
         ident child.children[0].lexeme,
         newNimNode(nnkDotExpr).add(
            newIntLitNode parseInt(child.children[1].lexeme),
            ident node.children[0].children[1].lexeme
         )
      )

iterator toUnionFields(node: Node): NimNode =
   var idx: uint8 = 0
   for child in node.children[1].children:
      yield newNimNode(nnkEnumFieldDef).add(
         ident child.lexeme,
         newLit idx
      )
      inc idx

iterator fieldTypeSlots(node: Node): (string, string, int, int, int, Node) =
   var maxSize: int = 0
   #var size: int = 0
   for child in node.children[1].children:
      var fieldNode = child.children[1]

      if fieldNode.kind == tkEquals: # there is a default value, not handled yet
         # set the string value of the tkEquals node to the field's type + its default value separated by "|"
         fieldNode.lexeme = fieldNode.children[0].lexeme & "|" & fieldNode.children[1].lexeme
      if fieldNode.kind == nkOpenArray:
         if maxSize < 4:
            maxSize = 4
      elif fieldNode.kind == tkStruct:
         if maxSize < fieldNode.structSize:
            maxSize = fieldNode.structSize
      elif fieldNode.lexeme.contains("bool") or
      fieldNode.lexeme.contains("byte") or
      fieldNode.lexeme.contains("ubyte"):
         if maxSize < 1:
            maxSize = 1
      elif fieldNode.lexeme.contains("8"):
         if maxSize < 1:
            maxSize = 1
      elif fieldNode.lexeme.contains("16"):
         if maxSize < 2:
            maxSize = 2
      elif fieldNode.lexeme.contains("32"):
         if maxSize < 4:
            maxSize = 4
      elif fieldNode.lexeme.contains("64"):
         if maxSize < 8:
            maxSize = 8
      elif fieldNode.lexeme == "string":
         if maxSize < 4:
            maxSize = 4
      else:
         if maxSize < 4:
            maxSize = 4

   var
      i: int = 1
      x: int = 0
   for child in node.children[1].children:
      var fieldNode = child.children[1]

      if fieldNode.kind == tkEquals: # there is a default value, not handled yet
         # set the string value of the tkEquals node to the field's type + its default value separated by "|"
         fieldNode.lexeme = fieldNode.children[0].lexeme & "|" & fieldNode.children[1].lexeme

      if fieldNode.children.len == 1:
         if child.kind == tkUnion:
            yield (child.children[0].lexeme, fieldNode.children[0].lexeme, (i + 1) * 2, x, maxSize, child)
            inc x
         elif child.kind == tkString: # TODO handle strings
            yield (child.children[0].lexeme, fieldNode.children[0].lexeme, (i + 1) * 2, x, maxSize, child)
            inc x
            inc i
         else:
            yield (child.children[0].lexeme, fieldNode.children[0].lexeme, (i + 1) * 2, x, maxSize, child)
      else:
         yield (child.children[0].lexeme, fieldNode.lexeme, (i + 1) * 2, x, maxSize, child)
      inc i
      inc x

iterator fieldTypeSlotsT(node: Node): (string, string, int) =
   var maxSize: int = 0
   for child in node.children[1].children:
      if child.children[1].lexeme in ["bool", "byte"]:
         if maxSize < 1:
            maxSize = 1
      elif child.children[1].lexeme.contains("8"):
         if maxSize < 1:
            maxSize = 1
      elif child.children[1].lexeme.contains("16"):
         if maxSize < 2:
            maxSize = 2
      elif child.children[1].lexeme.contains("32"):
         if maxSize < 4:
            maxSize = 4
      elif child.children[1].lexeme.contains("64"):
         if maxSize < 8:
            maxSize = 8
      elif child.children[1].lexeme == "string":
         if maxSize < 4:
            maxSize = 4
         #quit("dont know wtf to do with strings")
      else:
         if maxSize < 4:
            maxSize = 4

   var i: int = 0
   for child in node.children[1].children:
      yield (child.children[0].lexeme, child.children[1].lexeme, i)
      inc i, maxSize

proc stringify(n: NimNode): string =
   #n.repr.replace("type\n   ", "type ").replace("; )", ")")
   n.repr

proc newEnder(objName: string, node: Node): NimNode {.used.} =
   result = parseStmt("proc " & objName & "End*[T](this: var Builder[T]): uoffset =\n" &
   "   result = this.endObject()\n")

proc newStructGetter(obj, field, typ: string, off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         )
      ],
      parseStmt( "structGetter(this, " & $off & ", " & $typ & ")")
      # parseStmt(  # TODO understand why the offset is wrong by -4, hardcoded solution should be provisional
      #    "result = this.tab.Get[:" & typ & "](this.tab.Pos + " & $(off + 4) & ")\n"
      # )
   )

proc newStructGetterT(obj, field, typ: string, off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident obj
            ),
            newEmptyNode()
         )
      ],
      parseStmt(  # TODO understand why the offset is wrong by -4, hardcoded solution should be provisional
         "result = this.tab.Get[:" & typ & "](this.tab.Pos + " & $(off + 4) & ")\n"
      )
   )

proc newStructSetter(obj, field, typ: string, off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident "`" & field & "=`"
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident obj
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident "n",
            ident typ,
            newEmptyNode()
         ),
         newEmptyNode()
      ],
      parseStmt( "structSetter(this, " & $off & ", n)")
      # parseStmt(  # TODO understand why the offset is wrong by -4, hardcoded solution should be provisional
      #    "discard this.tab.Mutate(this.tab.Pos + " & $(off + 4) & ", n)"
      # )
   )

proc newStructCreator(node: Node): NimNode {.used.} =
   var
      args: seq[NimNode]
      inputs: seq[NimNode]
      toPrepend: string
      # structTyp = node.children[0].lexeme
      # Dont use actual type, use uoffset
      structTyp = "uoffset"

   args = @[
      ident structTyp,
      nnkIdentDefs.newTree(
         ident "this",
         nnkVarTy.newTree(
            ident "B"
         ),
         newEmptyNode()
      )
   ]

   for child in node.children[1].children.reversed():
      toPrepend.add "this.prepend(" & child.children[0].lexeme & ")"
      toPrepend.add "\n"
      inputs.add nnkIdentDefs.newTree(
         ident child.children[0].lexeme,
         ident child.children[1].lexeme,
         newEmptyNode()
      )
   inputs.reverse()
   args.add inputs

   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident "create" & node.children[0].lexeme
      ),
      args,
      parseStmt(
         "this.prep(" & $node.alignment & ", " & $node.structSize & ")\n" &
         toPrepend &
         "result = this.offset()"

      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newStruct(node: Node): seq[string] =
   var
      objName = nnkPostfix.newTree(ident"*", ident(node.children[0].lexeme))
      #objSize = node.size
      mutatorProcs: seq[string]

   var
      objType = nnkObjectTy.newTree(
         newEmptyNode(),
      nnkOfInherit.newTree(
            ident"FlatObj"
         ),
         newEmptyNode() # objFields
      )

   for field, typ, off in node.fieldTypeSlotsT:
      mutatorProcs.add "\n"
      if typ notin BasicNimTypes:
         if typ in toSeq(unions.names):
            mutatorProcs.add("# SKIPPED FIELD, " & field & " of type " & typ)
         else:
            mutatorProcs.add newStructGetterT(objName[1].strVals, field, typ, off).stringify
            mutatorProcs.add "\n"
            mutatorProcs.add newStructSetter(objName[1].strVals, field, typ, off).stringify
      else:
         mutatorProcs.add newStructGetter(objName[1].strVals, field, typ, off).stringify
         mutatorProcs.add newStructSetter(objName[1].strVals, field, typ, off).stringify

   result.add nnkTypeSection.newTree(nnkTypeDef.newTree(objName, newEmptyNode(), objType)).stringify
   result.add "\n\n"
   result.add mutatorProcs
   result.add "\n"
   result.add newStructCreator(node).stringify
   result.add "\n\n"

proc newTableGetter(obj, field, typA: string, off: int): NimNode =
   var typ: string
   var defaultVal: string
   if "|" in typA: # Default value
      typ = typA.split("|")[0]
      defaultVal = typA.split("|")[1]
   else:
      typ = typA
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         )
      ],
      parseStmt( "basicTableGetter(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   " & "   result = this.tab.Get[:" & typ & "](o + this.tab.Pos)\n" &
      #    "else:\n" &
      #    "   " & "   result = default(type(result))\n"
      # )
   )

# Struct getter
proc newTableGetterS(obj, field, typ: string; off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         ),
      ],
      parseStmt( "basicTableGetterS(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    #"var obj: " & typ & "\n" &
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   " & "   var x = o + this.tab.Pos\n" &
      #    "   " & "   result.Init(this.tab.Bytes, x)\n" &
      #    "else:\n" &
      #    "   " & "   result = default(type(result))\n"
      # )
   )

# Table getter
proc newTableGetterT(obj, field, typ: string; off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         ),
      ],
      parseStmt( "basicTableGetterT(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    #"var obj: " & typ & "\n" &
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   " & "   var x = this.tab.Indirect(o + this.tab.Pos)\n" &
      #    "   " & "   result.Init(this.tab.Bytes, x)\n" &
      #    "else:\n" &
      #    "   " & "   result = default(type(result))\n"
      # )
   )

proc newTableSetter(obj, field, typA: string, off: int): NimNode =
   var typ: string
   var defaultVal: string
   if "|" in typA: # Default value
      typ = typA.split("|")[0]
      defaultVal = typA.split("|")[1]
   else:
      typ = typA
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident "`" & field & "=`"
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident obj
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident "n",
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "discard this.tab.mutateSlot(" & $off & ", n)\n"
      )
   )

proc newTableStringGetter(obj, field, typ: string; off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         )
      ],
      parseStmt( "basicTableStringGetter(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   result = this.tab.toString(o)\n" &
      #    "else:\n" &
      #    "   discard\n"
      # )
   )

proc newTableArrayGetter(obj, field, typ: string; off, inlineSize, size: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident "j",
            ident "int",
            newEmptyNode()
         )
      ],
      parseStmt("result = tableArrayGetter(this, " & $inlineSize & ")")
      # parseStmt(
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   var x = this.tab.Vector(o)\n" &
      #    "   x += j.uoffset * " & $inlineSize & ".uoffset\n" &
      #    "   result = this.tab.Get[:" & typ & "](o + this.tab.Pos)\n" &
      #    "else:\n" &
      #    "   discard\n"
      # )
   )

proc newTableArrayLength(obj, field, typ: string, off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field & "Length"
      ),
      [
         ident "int",
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         )
      ],
      parseStmt( "tableArrayLength(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   result = this.tab.Vectorlen(o)\n"
      # )
   )

proc newTableArrayStarter(obj, field: string; inlineSize, fieldSize: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Start" & field & "Vector"
      ),
      [
         ident "uoffset",
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident "numElems",
            ident "int",
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.startVector(" & $fieldSize & ", numElems, " & $inlineSize & ")\n"
      )
   )
   result[2] = nnkGenericParams.newTree(nnkIdentDefs.newTree(ident "T"))

proc newTableUnionTypeGetter(obj, field, typ: string, off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field & "Type"
      ),
      [
         ident typ,
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         )
      ],
      parseStmt( "tableUnionTypeGetter(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   result = this.tab.Get[:" & typ & "](o + this.tab.Pos)\n" &
      #    "else:\n" &
      #    "   result = default(type(result))\n"
      # )
   )

proc newTableUnionTypeSetter(obj, field, typ: string, off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident "`" & field & "Type=`"
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident obj
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident "n",
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "discard this.tab.MutateSlot(" & $off & ", n)\n"
      )
   )

proc newTableUnionGetter(obj, field, typ: string; off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident field
      ),
      [
         ident "FlatObj",
         nnkIdentDefs.newTree(
            ident "this",
            ident obj,
            newEmptyNode()
         ),
         #[nnkIdentDefs.newTree(
            ident "obj",
            nnkVarTy.newTree(
               ident "FlatObj"
            ),
            newEmptyNode()
         )]#
      ],
      parseStmt( "tableUnionGetter(this, " & $off & ", " & $typ & ")")
      # parseStmt(
      #    #"var obj: " & typ & "\n" &
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   this.tab.Union(result.tab, o)\n" &
      #    #"   " & "   result = true\n" &
      #    "else:\n" &
      #    "   discard"
      #    #"   " & "   result = false\n"
      # )
   )
# NO SETTERS IN THE API!!!
proc newTableUnionSetter(obj, field, typ: string; off: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident "`" & field & "=`"
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident obj
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident "obj",
            nnkVarTy.newTree(
               ident "FlatObj"
            ),
            newEmptyNode()
         ),
      ],
      parseStmt( "tableUnionGetter(this, " & $off & ", n)")
      # parseStmt(
      #    #"var obj: " & typ & "\n" &
      #    "var o = this.tab.Offset(" & $off & ")\n" &
      #    "if o != 0:\n" &
      #    "   this.tab.Union(obj.tab, o)\n" &
      #    #"   " & "   result = true\n" &
      #    "else:\n" &
      #    "   discard"
      #    #"   " & "   result = false\n"
      # )
   )

proc newTableAdder(obj, field, typ: string, slo: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Add" & FirstLetterCap(field)
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident field,
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.prependSlot(" & $slo & ", " & field & ", default(" & typ & "))\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTableEnumAdder(obj, field, typ: string, slo: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Add" & FirstLetterCap(field)
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident field,
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.prependSlot(" & $slo & ", " & field & ", default(" & typ & "))\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTableArrayAdder(obj, field, typ: string, slo: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Add" & FirstLetterCap(field)
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident field,
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.prependSlot(" & $slo & ", " & field & ", default(" & typ & "))\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTableUnionTypeAdder(obj, field, typ: string, slo: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Add" & FirstLetterCap(field) & "Type"
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident field,
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.prependSlot(" & $slo & ", " & field & ", default(" & typ & "))\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTableUnionAdder(obj, field, typ: string, slo: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Add" & FirstLetterCap(field)
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident field,
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.prependSlot(" & $(slo + 1) & ", " & field & ", default(" & typ & "))\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTableStringAdder(obj, field, typ: string, slo: int): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident obj & "Add" & FirstLetterCap(field)
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
         nnkIdentDefs.newTree(
            ident field,
            ident typ,
            newEmptyNode()
         )
      ],
      parseStmt(
         "this.prependSlot(" & $(slo + 1) & ", " & field & ", default(" & typ & "))\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTableStarter(objName: string, node: Node): NimNode =
   result = newProc(
      nnkPostFix.newTree(
         ident "*",
         ident objName & "Start"
      ),
      [
         newEmptyNode(),
         nnkIdentDefs.newTree(
            ident "this",
            nnkVarTy.newTree(
               ident "B"
            ),
            newEmptyNode()
         ),
      ],
      parseStmt(
         "this.startObject(" & $node.children[1].children.len & ")\n"
      )
   )
   result[2] = nnkGenericParams.newTree( nnkIdentDefs.newTree( ident "B", newEmptyNode(), newEmptyNode()))

proc newTable(node: Node): seq[string] =
   var
      objCapName = node.children[0].lexeme
      objName = objCapName.SnakeCase()
      objId = nnkPostfix.newTree(ident"*", ident(node.children[0].lexeme))
      mutatorProcs: seq[string]

   echo "OBJ_NAME: ", repr(objname)
   echo "OBJ_NAME:1: ", repr(objname[1])
   var
      objType = nnkObjectTy.newTree(
         newEmptyNode(),
         nnkOfInherit.newTree(
            ident"FlatObj"
         ),
         newEmptyNode()
      )

   for field, typ, off, slo, size, child in node.fieldTypeSlots:
      if child.children[1].kind == nkOpenArray:
         if typ notin BasicNimTypes:
            mutatorProcs.add "\n"
            mutatorProcs.add newTableArrayGetter(objCapName, field, "uoffset", off, child.children[1].inlineSize, size).stringify
            mutatorProcs.add "\n"
            mutatorProcs.add newTableArrayLength(objCapName, field, "uoffset", off).stringify
         else:
            mutatorProcs.add "\n"
            mutatorProcs.add newTableArrayGetter(objCapName, field, typ, off, child.children[1].inlineSize, size).stringify
            mutatorProcs.add "\n"
            mutatorProcs.add newTableArrayLength(objCapName, field, typ, off).stringify
      else:
         var hasDefault: bool = false
         if "|" in typ: # only support default values for basic types, so we dont need to check for non basic types
            hasDefault = true
            if typ.split("|")[0] notin BasicNimTypes:
               error("Dont support default values for non basic types")

         if typ notin BasicNimTypes and not hasDefault:
            if typ in toSeq(unions.names):
               mutatorProcs.add "\n"
               mutatorProcs.add newTableUnionTypeGetter(objCapName, field, typ & "Type", off).stringify
               mutatorProcs.add "\n"
               mutatorProcs.add newTableUnionTypeSetter(objCapName, field, typ & "Type", off).stringify
               mutatorProcs.add "\n"
               mutatorProcs.add newTableUnionGetter(objCapName, field, "uoffset", off).stringify
               #mutatorProcs.add "\n"
               #mutatorProcs.add newTableUnionSetter(objName[1].strVals, field, getName(enums, typ).enumType, slo).stringify
            elif typ in toSeq(enums.namesE):
               mutatorProcs.add "\n"
               mutatorProcs.add newTableGetter(objCapName, field, getName(enums, typ).enumType, off).stringify
               mutatorProcs.add "\n"
               mutatorProcs.add newTableSetter(objCapName, field, getName(enums, typ).enumType, off).stringify
            elif typ in toSeq(structs.names):
               mutatorProcs.add "\n"
               mutatorProcs.add newTableGetterS(objCapName, field, typ, off).stringify
               # TODO: make this only added when --gen-mutable is passed (and also allow for --gen-mutable to be passed :p )
               #mutatorProcs.add "\n"
               #mutatorProcs.add newTableSetter(objName[1].strVals, field, typ, off).stringify
            else:
               mutatorProcs.add "\n"
               mutatorProcs.add newTableGetterT(objCapName, field, typ, off).stringify
               # TODO: make this only added when --gen-mutable is passed (and also allow for --gen-mutable to be passed :p )
               #mutatorProcs.add "\n"
               #mutatorProcs.add newTableSetter(objName[1].strVals, field, typ, off).stringify
         else:
            if typ == "string":
               mutatorProcs.add newTableStringGetter(objCapName, field, typ, off).stringify
            else:
               mutatorProcs.add "\n"
               mutatorProcs.add newTableGetter(objCapName, field, typ, off).stringify
               mutatorProcs.add "\n"
               mutatorProcs.add newTableSetter(objCapName, field, typ, off).stringify

   result.add nnkTypeSection.newTree(nnkTypeDef.newTree(objId, newEmptyNode(), objType)).stringify
   result.add "\n\n"
   result.add mutatorProcs
   result.add "\n"
   result.add newTableStarter(objName, node).stringify
   for field, typ, off, slo, size, child in node.fieldTypeSlots:
      result.add "\n"
      if child.children[1].kind == nkOpenArray:
         result.add newTableArrayAdder(objName, field, "uoffset", slo).stringify
         result.add "\n"
         result.add newTableArrayStarter(objName, field,
            child.children[1].inlineSize, child.children[1].fieldSize).stringify
      else:
         if typ notin BasicNimTypes:
            if typ in toSeq(unions.names):
               result.add newTableUnionTypeAdder(objName, field, typ & "Type", slo).stringify
               result.add "\n"
               # TODO: Consider creating a "type [UnionName] = uoffset" and use that instead of using "uoffset" directly
               result.add newTableUnionAdder(objName, field, "uoffset", slo).stringify
            elif typ in toSeq(enums.namesE):
               result.add newTableEnumAdder(objName, field, getName(enums, typ).getEnumName(), slo).stringify
            else:
               result.add newTableAdder(objName, field, "uoffset", slo).stringify
         else:
            if typ == "string":
               result.add newTableStringAdder(objName, field, "uoffset", slo).stringify
            else:
               result.add newTableAdder(objName, field, typ, slo).stringify
   result.add newEnder(objName, node).stringify
   result.add "\n\n"

proc newEnum(node: Node): seq[string] =
   var objName = ident(node.children[0].children[0].lexeme)

   result.add newEnum(
      name = objName,
      fields = toSeq(node.toEnumFields),
      public = true, pure = true
   ).stringify & "\n\n\n"

proc newUnion(node: Node): seq[string] =
   var
      objName = ident(node.children[0].lexeme & "Type")
      objType = nnkObjectTy.newTree(
         newEmptyNode(),
         nnkOfInherit.newTree(
            ident"FlatObj"
         ),
         newEmptyNode() # objFields
      )

   result.add newEnum(
      name = objName,
      fields = toSeq(node.toUnionFields),
      public = true, pure = true
   ).stringify & "\n\n"

   result.add nnkTypeSection.newTree(
      nnkTypeDef.newTree(
         nnkPostfix.newTree(ident"*", ident(node.children[0].lexeme)),
         newEmptyNode(),
         objType
      )
   ).stringify & "\n\n"


proc newNodeFromFlat(node: Node): seq[string] =
   if node.kind == tkTable:
      tabls.add node
      result = newTable(node)
   elif node.kind == tkStruct:
      structs.add node
      result = newStruct(node)
   elif node.kind == tkEnum:
      enums.add node
      result = newEnum(node)
   elif node.kind == tkunion:
      unions.add node
      result = newUnion(node)
   else:
      raise newException(Exception, "ERROR, not supported node type: " & $node.kind & "\n\n")

proc generateCodeImpl*(
      resourcepath: string,
      outputfile: string,
) =
   var
      file = readFile(resourcepath)
      lexer: Lexer
      parser: Parser

   lexer.initLexer(file)
   lexer.generate_tokens()

   parser.initParser(lexer.tokens)
   parser.parse()

   var header = "import Nimflatbuffers\n\n"

   var
      fileContents: string = header
      allNodes: seq[string]
      currentNode: seq[string]

   for node in parser.nodes:
      if node.kind == tkNamespace:
         continue
      currentNode = newNodeFromFlat(node)
      allNodes.add currentNode
      for str in currentNode:
         fileContents.add(str)

   if not dirExists(outputfile.parentDir()):
      createDir(outputfile.parentDir())
   writeFile(outputFile, fileContents[0..^3])
