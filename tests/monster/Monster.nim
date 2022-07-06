import Nimflatbuffers/runtime/flatbuffers

# generateCode("MonsterSchema.fbs")
import output/MyGame_Sample

static:
   echo "tp: monster: ", typeof(Monster)

# var builder: Builder[Monster]
# var builder = newBuilders[Monsters](1024)
var builder: Builder[Monster]
builder.init(1024)

#[
var
   weaponOne = builder.Create("Sword")
   weaponTwo = builder.Create("Axe")
builder.WeaponStart()
builder.WeaponAddName(weaponOne)
builder.WeaponAddDamage(3)
var sword = builder.WeaponEnd()

builder.WeaponStart()
builder.WeaponAddName(weaponTwo)
builder.WeaponAddDamage(5)
var axe = builder.WeaponEnd()

var inv = builder.MonsterStartinventoryVector(10)
var i = 9
while i >= 0:
   builder.Prepend(i.byte)
   dec i
inv = builder.EndVector(10)

var weapons = builder.MonsterStartweaponsVector(2)
builder.Prepend(axe)
builder.Prepend(axe)
weapons = builder.EndVector(2)

var path = builder.MonsterStartPathVector(2)
discard builder.CreateVec3(1.0, 2.0, 3.0)
discard builder.CreateVec3(4.0, 5.0, 6.0)
path = builder.EndVector(2)
]#
var name = builder.create("Orc")
builder.monsterStart()
# builder.monsterAddPos(builder.CreateVec3(1.0, 2.0, 3.0))
# builder.monsterAddHp(301)
# builder.monsterAddMana(10)
# builder.monsterAddName(name)

#[
builder.MonsterAddInventory(inv)
builder.MonsterAddColor(Color.Red)
builder.MonsterAddWeapons(weapons)
builder.MonsterAddEquippedType(EquipmentType.Weapon)
builder.MonsterAddEquipped(axe)
builder.MonsterAddPath(path)
]#
var orc = builder.monsterEnd()

builder.finish(orc)

var finishedBytes = builder.finishedBytes()
# echo finishedBytes

var aMonster: Monster
getRootAs(aMonster, finishedBytes, 0)

echo "Monster HP: ", aMonster.hp
echo "Monster Name: \"", aMonster.name, "\""
echo "Monster Pos: ",  aMonster.pos.x, aMonster.pos.y, aMonster.pos.z
