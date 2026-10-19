GetLocale=function() return "enUS" end
local data={
 {id=101,category=10}, {id=102,category=10,minimum=1}, {id=103,category=10},
 {id=104,category=20}, {id=105,category=10,legacyEvent=99}, {id=106,category=10,hiddenSeason=8},
 {id=107,category=10}, {id=108,category=10}, {id=109,category=10}, {id=110,category=10}, {id=111,category=10}, {id=112,category=10}, {id=113,category=10},
}
local addon={raidAchievementData={[2549]=data}}
GetCategoryInfo=function(id) return "Category", id==20 and 81 or -1 end
GetAchievementInfo=function(id)
 if id==109 then return end
 return id,"Achievement "..id,10,id==103,nil,nil,nil,"Description",id==107 and 1 or id==110 and 2 or id==112 and 16384 or 0,123,"Reward",id==108
end
GetAchievementNumCriteria=function(id) return id==111 and 1 or 2 end
GetAchievementCriteriaInfo=function(id,index)
 if id==111 then return "Kill count",0,false,4,10 end
 return index==1 and "First criterion" or "Second criterion",0,index==1,index==1 and 1 or 3,index==1 and 1 or 10,nil,nil,nil,index==2 and "3 / 10" or ""
end
local combat, opened
InCombatLockdown=function() return combat end
ShowAchievementFrameForAchievement=function(id) opened=id end
assert(loadfile("TrackerProviders/RaidAchievementContent.lua"))("AyijeUIQOLTrackers",addon)
local rows=addon.GetRaidAchievementRows({mapID=2549,name="Amirdrassil"})
GetAchievementCategory=function(id) return id==113 and 81 or id==104 and 20 or 10 end
rows=addon.GetRaidAchievementRows({mapID=2549,name="Amirdrassil"})
assert(#rows==4,"Statistics, guild, special, retired, hidden or invalid achievements leaked")
assert(rows[1].raidAchievementID==101 and rows[1].raidAchievementProgress=="1 / 2")
assert(rows[1].tooltipLines[3]:find("First criterion",1,true) and rows[1].tooltipLines[4]:find("3 / 10",1,true))
assert(rows[1].tooltipLines[5]=="Reward: Reward")
assert(rows[2].gaugeMaximum==1 and rows[2].gaugeValue==1,"Minimum criteria ignored")
assert(rows[3].raidAchievementCompleted and rows[3].gaugeValue==2)
assert(rows[4].gaugeValue==4 and rows[4].gaugeMaximum==10 and rows[4].raidAchievementProgress=="4 / 10","Numeric criterion progress lost")
assert(#addon.GetRaidAchievementRows({mapID=999})==0)
assert(addon.OpenRaidAchievement(rows[1]) and opened==101)
combat=true; opened=nil; assert(not addon.OpenRaidAchievement(rows[1]) and not opened)
combat=false; ShowAchievementFrameForAchievement=nil
assert(not addon.OpenRaidAchievement(rows[1]) and not addon.OpenRaidAchievement(nil))
GetAchievementCriteriaInfo=nil
assert(#addon.GetRaidAchievementRows({mapID=2549})==0)
local primary={}
assert(loadfile("TrackerProviders/RaidAchievementData.lua"))("AyijeUIQOLTrackers",primary)
local found={}
for _,entry in ipairs(primary.raidAchievementData[2549]) do found[entry.id]=true end
assert(found[19349] and found[19089] and found[19343],"Missing Amirdrassil glory, challenge or mythic achievement")
assert(primary.raidAchievementData[2912] and primary.raidAchievementData[3004],"Missing current raid maps")
print("PASS: raid achievement mapping, account completion, criteria/rewards, progress minimum, availability exclusions, missing data and native click combat guard.")
