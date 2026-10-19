-- Reproduce the reported pattern: 300 shown although another seasonal Hero
-- item still needs crests. Accessories can return maxItemLevel=0, so match an
-- exact native track/rank/current-ilvl rung to gear with proven season data.
local ns={ActionBindings={Safe=function() return true end}}
C_MythicPlus={GetCurrentSeason=function() return 18 end}
C_Item={
    GetItemUpgradeInfo=function(link)
        -- Captured necklace dump: trackString="Hero", trackStringID=974,
        -- currentLevel=1, maxLevel=6, maxItemLevel=0. The screenshot gives 305.
        return {trackString='Hero',trackStringID=974,currentLevel=1,maxLevel=6,
            maxItemLevel=link:find('13662',1,true) and 321 or 0}
    end,
    IsCurrentItem=function() return false end,
    GetDetailedItemLevelInfo=function() return 305 end,
}
assert(loadfile('EquipmentTracks.lua'))('ayijeUIQOL',ns)
local T=ns.EquipmentTracks
local seasonal='item:2000:0:0:0:0:0:0:0:90:0:0:0:1:13662'
local records={
    T.Read(seasonal),
    T.Read(seasonal),
    T.Read(seasonal),
    T.Read('item:2000:0:0:0:0:0:0:0:90:0:0:0:0'),
}
local totals,partial=T.Budget(records,18)
assert(totals[3445].required==400,
    'Hero crest undercount: expected 400 for four Hero 1/6 items, got '..totals[3445].required)
assert(not partial,'native seasonal ladder data should resolve this item')
local anchor=records[1]
anchor.current=6
anchor.itemLevel=321
totals,partial=T.Budget({anchor,records[4]},18)
assert(totals[3445].required==0 and partial,'a zero cap and unmatched native rank must remain unresolved')
local withCap={track='hero',current=1,maximum=6,maxItemLevel=321}
totals,partial=T.Budget({anchor,withCap},18)
assert(totals[3445].required==100 and not partial,'maxed gear still identifies a proven cap')
assert(#totals[3445].items==2 and totals[3445].items[1].cost==0)
assert(totals[3445].items[2].cost==100,'tooltip breakdown must match the total')
local old={track='hero',current=1,maximum=6,maxItemLevel=276,season=17}
totals,partial=T.Budget({anchor,old,withCap},18)
assert(totals[3445].required==100 and not partial,'different native caps must not mix seasons')
local unknownOld={track='hero',current=1,maximum=6,maxItemLevel=276}
totals,partial=T.Budget({anchor,unknownOld},18)
assert(totals[3445].required==0 and partial,'an unmatched old ladder must not spend current crests')
totals,partial=T.Budget({old,unknownOld},18)
assert(totals[3445].required==0 and not partial,'proven old-season ladders are excluded completely')
local collision={track='hero',current=1,maximum=6,maxItemLevel=321,season=17}
totals,partial=T.Budget({anchor,collision,withCap},18)
assert(totals[3445].required==0 and partial,'conflicting provenance must remain unresolved')
totals,partial=T.Budget({records[4]},18)
assert(totals[3445].required==0 and partial,'no provenance must remain explicit instead of guessing')
assert(not records[4].season,'inference must not mutate inventory records')
local zeroCap=records[4]
assert(zeroCap.nativeTrackName=='Hero' and zeroCap.nativeTrackID==974
    and zeroCap.current==1 and zeroCap.maximum==6 and zeroCap.nativeMaxItemLevel==0)
assert(T.Diagnostic(zeroCap):find('maxIlvl=0',1,true),'diagnostics must preserve the captured zero')
local champion={track='champion',current=5,maximum=6,itemLevel=305,season=18}
totals,partial=T.Budget({champion,zeroCap},18)
assert(totals[3445].required==0 and partial,'overlapping ilvl on a different track is not evidence')
local otherRank={track='hero',current=2,maximum=6,itemLevel=305,season=18}
totals,partial=T.Budget({otherRank,zeroCap},18)
assert(totals[3445].required==80 and partial,'a different rank is not seasonal evidence')
local oldRung={track='hero',current=1,maximum=6,itemLevel=259,maxItemLevel=276,season=17}
local unknownOldRung={track='hero',current=1,maximum=6,itemLevel=259}
totals,partial=T.Budget({oldRung,unknownOldRung},18)
assert(totals[3445].required==0 and not partial,'zero-cap old-season rungs must remain excluded')

-- User screenshots: seven equipped Hero 1/6 items at ilvl 305, cap 321.
-- IDs/ranks come from the tooltips. Links below are synthetic: reproduce the
-- original three recognised armor pieces and four unrecognised accessories.
local equipment={}
local function Equip(slot,id,bonus)
    local fields={tostring(id),'0','0','0','0','0','0','0','90','0','0','0',bonus and '1' or '0'}
    if bonus then fields[#fields+1]=tostring(bonus) end
    equipment[slot]='item:'..table.concat(fields,':')
end
Equip(2,272229)         -- Serpentine Talisman
Equip(15,272226,13662)  -- Miststalker's Shroud
Equip(9,272246,13662)   -- Miststalker's Wristbands
Equip(8,272240,13662)   -- Miststalker's Striders
Equip(11,272148)        -- Anguine Gyre
Equip(12,272150)        -- Ouroboric Signet
Equip(13,265657)        -- Fiber of Living Agony
function GetInventoryItemLink(_,slot) return equipment[slot] end
function GetInventoryItemID() end
local equipped=T.Equipped()
totals,partial=T.Budget(equipped,18)
assert(#equipped==7 and #totals[3445].items==7,'all seven equipped Hero items must be included')
assert(equipped[1].nativeMaxItemLevel==0,'the live necklace dump must exercise the zero-cap path')
assert(totals[3445].required==700 and not partial,
    'screenshot regression: seven Hero 1/6 items must require 700 crests, got '..totals[3445].required)
for _,item in ipairs(totals[3445].items) do assert(item.cost==100) end
assert(math.max(0,totals[3445].required-105)==595,'105 owned leaves a 595 crest deficit')
print('crest-budget: seven screenshot items = 700 Hero crests; 105 owned = 595 missing')
print('crest-budget: seasonal Hero item without catalyst bonus is included')
