local ns, allFrames, timers, looted = {}, {}, {}, {}
local combat, focus, alt, ctrl, shift = false, nil, false, false, false
local cvar, now, pendingLevel = '0', 1, nil
local function Object(parent)
    local o={shown=true,parent=parent,scripts={},points={},events={},children={}}
    if parent then parent.children[#parent.children+1]=o end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:HookScript(k,fn)
        local prev=self.scripts[k]
        self.scripts[k]=function(...) if prev then prev(...) end; fn(...) end
    end
    function o:SetShown(v)
        if self.shown==v then return end
        self.shown=v
        local fn=self.scripts[v and 'OnShow' or 'OnHide']; if fn then fn(self) end
    end
    function o:Show() self:SetShown(true) end
    function o:Hide() self:SetShown(false) end
    function o:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
    function o:SetPoint(...) self.points={{...}} end
    function o:GetNumPoints() return #self.points end
    function o:GetPoint(i) return unpack(self.points[i]) end
    function o:ClearAllPoints() self.points={} end
    function o:GetEffectiveScale() return 2 end
    function o:GetFrameLevel() return 3 end
    function o:SetPropagateKeyboardInput(v) self.propagate=v end
    function o:CreateFontString() self.label=Object(self); return self.label end
    function o:CreateLine() return Object(self) end
    function o:SetText(v) self.text=v end
    function o:RegisterEvent(e) self.events[e]=true end
    function o:UnregisterEvent(e) self.events[e]=nil end
    function o:UnregisterAllEvents() self.events={} end
    for _,m in ipairs({'SetSize','SetFrameLevel','SetAllPoints','EnableMouse','SetTextColor',
        'SetThickness','SetStartPoint','SetEndPoint','SetColorTexture'}) do o[m]=function() end end
    return o
end
function CreateFrame(_,_,parent)
    local o=Object(parent); allFrames[#allFrames+1]=o; return o
end
function hooksecurefunc(owner,key,fn)
    local original=owner[key]
    owner[key]=function(...) original(...); fn(...) end
end
function InCombatLockdown() return combat end
function IsAltKeyDown() return alt end
function IsControlKeyDown() return ctrl end
function IsShiftKeyDown() return shift end
function GetCurrentKeyBoardFocus() return focus end
function GetCursorPosition() return 800,600 end
function GetTime() return now end
function GetBindingText(k) return k end
function GetNumLootItems() return 3 end
function LootSlot(i) looted[#looted+1]=i end
local links={[1]='item:1000',[2]='money',[3]='item:1001'}
function GetLootSlotLink(i) return links[i] end
function GetLootSlotType(i) return i==2 and 2 or 1 end
C_CVar={GetCVar=function() return cvar end,SetCVar=function(_,v) cvar=v end}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
Enum={LootSlotType={Item=1}}
C_Item={
    GetItemInfoInstant=function(link) return tonumber(link:match('%d+')),nil,nil,'INVTYPE_HEAD',nil,4 end,
    GetDetailedItemLevelInfo=function(link) return link=='item:1000' and 292 or pendingLevel end,
    RequestLoadItemDataByID=function(id) ns.requested=id end,
}
GameTooltip={IsOwned=function() return false end}
UIParent=Object()
LootFrame=Object(); LootFrame.shown=false
LootFrame:SetPoint('CENTER',UIParent,'CENTER',10,20)
LootFrame.ClosePanelButton=Object(LootFrame)
LootFrame.ScrollBox={list={}}
function LootFrame.ScrollBox:ForEachFrame(fn) for _,row in ipairs(self.list) do fn(row) end end
ScrollUtil={AddInitializedFrameCallback=function(_,fn,owner) ns.initRow=function(row) fn(owner,row) end end}
AyijeUI={UI={
    Palette={TEXT={1,1,1},GOLD={1,.8,0}},UnpackColor=function(c) return unpack(c) end,
    SetGlobalFont=function(label,size) label.fontSize=size end,
},L=setmetatable({}, {__index=function(_,k) return k end}),
Loot={active=true,db={restyle=true}},OnFontChanged=function() end}
ns.ActionBindings={Safe=function() return true end}
local cfg={enabled=true,takeAll=true,takeAllKey='E',underMouse=true,itemLevel=true,fontSize=13}
ns.module={active=true,db={lootWindow=cfg}}
assert(loadfile('LootWindow.lua'))('ayijeUIQOL',ns)
local loot=ns.LootWindow
assert(loot.NormalizeKey(' shift-ctrl-e ')=='CTRL-SHIFT-E')
assert(loot.NormalizeKey('SHIFT-SHIFT-E')==nil and loot.NormalizeKey('ESCAPE')==nil)
assert(loot.NormalizeKey('')=='' and loot.NormalizeKey('CTRL-SPACE')=='CTRL-SPACE')
loot:Enable()
local button=ns.lootTakeAllButton
assert(cvar=='1' and not button:IsShown() and not button.scripts.OnKeyDown)
LootFrame:Show()
assert(button:IsShown() and LootFrame.points[1][4]==400 and LootFrame.points[1][5]==300)
button.scripts.OnClick(button)
assert(#looted==3 and looted[1]==3 and looted[3]==1)
looted={}; button.scripts.OnKeyDown(button,'F'); assert(#looted==0 and button.propagate)
button.scripts.OnKeyDown(button,'E'); assert(#looted==3 and not button.propagate)
focus={}; looted={}; button.scripts.OnKeyDown(button,'E'); assert(#looted==0 and button.propagate)
focus=nil; cfg.takeAllKey='CTRL-E'; ctrl=true; loot:ApplyConfig()
button.scripts.OnKeyDown(button,'E'); assert(#looted==3)
ctrl=false; cfg.takeAllKey='E'; loot:ApplyConfig()
combat=true; loot:ApplyConfig(); assert(not button.scripts.OnKeyDown)
cfg.takeAllKey='SHIFT'; loot:ApplyConfig()
assert(button.events.MODIFIER_STATE_CHANGED)
looted={}; button.scripts.OnEvent(button,'MODIFIER_STATE_CHANGED','LSHIFT',1)
assert(#looted==3, 'Standalone modifier remains available in combat')
combat=false
local function Row(index)
    local row=Object(LootFrame); row.Item=Object(row); row.index=index
    function row:GetSlotIndex() return self.index end
    function row:Init(i) self.index=i end
    LootFrame.ScrollBox.list[#LootFrame.ScrollBox.list+1]=row
    ns.initRow(row)
    return row
end
local row=Row(1)
local label=row.Item.children[1].label
assert(label.text==292 and label.fontSize==13 and label.shown)
cfg.fontSize=18; loot:ApplyConfig(); assert(label.fontSize==18)
local liveSlot=row.GetSlotIndex
function row:GetSlotIndex() error('attempt to call a nil value') end
loot:ApplyConfig(); assert(not label.shown,'Released pooled row is skipped without error')
row.GetSlotIndex=liveSlot; loot:ApplyConfig(); assert(label.shown and label.text==292)
row:Init(2); assert(not label.shown,'Money row clears old item level')
row:Init(3); assert(not label.shown and ns.requested==1001)
pendingLevel=300
local event=allFrames[1]
event.scripts.OnEvent(event,'ITEM_DATA_LOAD_RESULT',1001,true)
timers[#timers](); assert(label.shown and label.text==300,'Loaded data refreshes reused row')
cfg.itemLevel=false; loot:ApplyConfig(); assert(not label.shown)
LootFrame.isInEditMode=true; loot:ApplyConfig()
assert(not button:IsShown()); looted={}; loot:TakeAll(); assert(#looted==0)
LootFrame.isInEditMode=false; cfg.underMouse=false; loot:ApplyConfig()
assert(cvar=='0' and LootFrame.points[1][1]=='CENTER','Disabling cursor restores anchor')
cfg.takeAll=false; loot:ApplyConfig(); assert(not button:IsShown() and not button.scripts.OnKeyDown)
cfg.takeAll=true; loot:ApplyConfig(); LootFrame:Hide()
assert(not button.scripts.OnKeyDown,'Closed window releases keyboard')
cfg.enabled=false; loot:ApplyConfig(); assert(cvar=='0')
ns.module.active=false; loot:Disable()
assert(not next(event.events) and not label.shown)
print('PASS: native Take All, configurable keys/modifiers/focus/combat, cursor scale and restoration, item levels, row reuse/loading, previews and live disable.')
