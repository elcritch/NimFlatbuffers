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
  structGetter(this, 0, float32)
proc `x=`*(this: var Vec3; n: float32; ) =
  structSetter(this, 0, n)

proc y*(this: Vec3): float32 =
  structGetter(this, 4, float32)
proc `y=`*(this: var Vec3; n: float32; ) =
  structSetter(this, 4, n)

proc z*(this: Vec3): float32 =
  structGetter(this, 8, float32)
proc `z=`*(this: var Vec3; n: float32; ) =
  structSetter(this, 8, n)

proc CreateVec3*(this: var Builder; x: float32; y: float32; z: float32): uoffset =
  this.prep(4, 12)
  this.prepend(z)
  this.prepend(y)
  this.prepend(x)
  result = this.offset()


type
  Monster* = object of FlatObj


proc pos*(this: monster): Vec3 =
  basicTableGetterT(this, 4, Vec3)

proc mana*(this: monster): int16 =
  basicTableGetter(this, 6, int16)

proc `mana=`*(this: var monster; n: int16) =
  discard this.tab.mutateSlot(6, n)

proc hp*(this: monster): int16 =
  basicTableGetter(this, 8, int16)

proc `hp=`*(this: var monster; n: int16) =
  discard this.tab.mutateSlot(8, n)
proc name*(this: monster): string =
  basicTableStringGetter(this, 10, string)

proc friendly*(this: monster): bool =
  basicTableGetter(this, 12, bool)

proc `friendly=`*(this: var monster; n: bool) =
  discard this.tab.mutateSlot(12, n)

proc MonsterStart*(this: var Builder) =
  this.startObject(5)

proc monsterAddPos*(this: var Builder; pos: uoffset) =
  this.prependSlot(0, pos, default(uoffset))

proc monsterAddMana*(this: var Builder; mana: uoffset) =
  this.prependSlot(1, mana, default(uoffset))

proc monsterAddHp*(this: var Builder; hp: uoffset) =
  this.prependSlot(2, hp, default(uoffset))

proc monsterAddName*(this: var Builder; name: uoffset) =
  this.prependSlot(4, name, default(uoffset))

proc monsterAddFriendly*(this: var Builder; friendly: uoffset) =
  this.prependSlot(4, friendly, default(uoffset))

proc MonsterEnd*(this: var Builder): uoffset =
  result = this.endObject()


type
  Weapon* = object of FlatObj

proc name*(this: weapon): string =
  basicTableStringGetter(this, 4, string)

proc damage*(this: weapon): int16 =
  basicTableGetter(this, 6, int16)

proc `damage=`*(this: var weapon; n: int16) =
  discard this.tab.mutateSlot(6, n)

proc WeaponStart*(this: var Builder) =
  this.startObject(2)

proc weaponAddName*(this: var Builder; name: uoffset) =
  this.prependSlot(1, name, default(uoffset))

proc weaponAddDamage*(this: var Builder; damage: int16) =
  this.prependSlot(1, damage, default(int16))

proc WeaponEnd*(this: var Builder): uoffset =
  result = this.endObject()
