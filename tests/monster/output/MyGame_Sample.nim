import Nimflatbuffers

type
  Color* {.pure.} = enum
    Red = 0.int8, Green = 1.int8, Blue = 2.int8


type
  EquipmentType* {.pure.} = enum
    Weapon = 0'u8

type
  Equipment* = object of FlatObj

type
  Vec3* = object of FlatObj


proc x*(this: Vec3): float32 =
  result = Get[float32](this.tab, this.tab.Pos + 4)
proc `x=`*(this: var Vec3; n: float32; ) =
  discard this.tab.Mutate(this.tab.Pos + 4, n)

proc y*(this: Vec3): float32 =
  result = Get[float32](this.tab, this.tab.Pos + 8)
proc `y=`*(this: var Vec3; n: float32; ) =
  discard this.tab.Mutate(this.tab.Pos + 8, n)

proc z*(this: Vec3): float32 =
  result = Get[float32](this.tab, this.tab.Pos + 12)
proc `z=`*(this: var Vec3; n: float32; ) =
  discard this.tab.Mutate(this.tab.Pos + 12, n)

proc CreateVec3*(this: var Builder; x: float32; y: float32; z: float32): uoffset =
  this.Prep(4, 12)
  this.Prepend(z)
  this.Prepend(y)
  this.Prepend(x)
  result = this.Offset()


type
  Monster* = object of FlatObj


proc pos*(this: Monster): Vec3 =
  var o = this.tab.Offset(4)
  if o != 0:
    var x = this.tab.Indirect(o + this.tab.Pos)
    result.Init(this.tab.Bytes, x)
  else:
    result = default(type(result))

proc mana*(this: Monster): int16 =
  var o = this.tab.Offset(6)
  if o != 0:
    result = Get[int16](this.tab, o + this.tab.Pos)
  else:
    result = default(type(result))

proc `mana=`*(this: var Monster; n: int16) =
  discard this.tab.MutateSlot(6, n)

proc hp*(this: Monster): int16 =
  var o = this.tab.Offset(8)
  if o != 0:
    result = Get[int16](this.tab, o + this.tab.Pos)
  else:
    result = default(type(result))

proc `hp=`*(this: var Monster; n: int16) =
  discard this.tab.MutateSlot(8, n)
proc name*(this: Monster): string =
  var o = this.tab.Offset(10)
  if o != 0:
    result = this.tab.toString(o)
  else:
    discard

proc friendly*(this: Monster): bool =
  var o = this.tab.Offset(12)
  if o != 0:
    result = Get[bool](this.tab, o + this.tab.Pos)
  else:
    result = default(type(result))

proc `friendly=`*(this: var Monster; n: bool) =
  discard this.tab.MutateSlot(12, n)

proc MonsterStart*(this: var Builder) =
  this.StartObject(5)

proc MonsterAddPos*(this: var Builder; pos: uoffset) =
  this.PrependSlot(0, pos, default(uoffset))

proc MonsterAddMana*(this: var Builder; mana: uoffset) =
  this.PrependSlot(1, mana, default(uoffset))

proc MonsterAddHp*(this: var Builder; hp: uoffset) =
  this.PrependSlot(2, hp, default(uoffset))

proc MonsterAddName*(this: var Builder; name: uoffset) =
  this.PrependSlot(4, name, default(uoffset))

proc MonsterAddFriendly*(this: var Builder; friendly: uoffset) =
  this.PrependSlot(4, friendly, default(uoffset))

proc MonsterEnd*(this: var Builder): uoffset =
  result = this.EndObject()


type
  Weapon* = object of FlatObj

proc name*(this: Weapon): string =
  var o = this.tab.Offset(4)
  if o != 0:
    result = this.tab.toString(o)
  else:
    discard

proc damage*(this: Weapon): int16 =
  var o = this.tab.Offset(6)
  if o != 0:
    result = Get[int16](this.tab, o + this.tab.Pos)
  else:
    result = default(type(result))

proc `damage=`*(this: var Weapon; n: int16) =
  discard this.tab.MutateSlot(6, n)

proc WeaponStart*(this: var Builder) =
  this.StartObject(2)

proc WeaponAddName*(this: var Builder; name: uoffset) =
  this.PrependSlot(1, name, default(uoffset))

proc WeaponAddDamage*(this: var Builder; damage: int16) =
  this.PrependSlot(1, damage, default(int16))

proc WeaponEnd*(this: var Builder): uoffset =
  result = this.EndObject()
