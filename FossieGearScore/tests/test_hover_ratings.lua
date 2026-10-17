-- Exercise real native unit-tooltip decoration and shared benchmark helpers.
local NS,count={},0
local function check(ok,why) assert(ok,why); count=count+1 end
local colorUpdates=0
local callback
local units={player={guid="Self",level=30},mouseover={guid="Other",level=30}}
local current={guid="Other",classToken="MAGE",score=265,dynamicAvailable=false}
local complete,cached=true,true
CreateFrame=function()
    return {RegisterEvent=function() end,SetScript=function() end}
end
UnitGUID=function(unit) return units[unit] and units[unit].guid end
UnitIsPlayer=function(unit) return units[unit]~=nil end
UnitLevel=function(unit) return units[unit] and units[unit].level end
NS.GetClassToken=function() return "MAGE" end
TooltipUtil={GetDisplayedUnit=function(t) return "Player",t.unit,UnitGUID(t.unit) end}
Enum={TooltipDataType={Unit=2}}
TooltipDataProcessor={AddTooltipPostCall=function(_,fn) callback=fn end}
local function font(text)
    return {text=text,SetText=function(self,v) self.text=v end,SetTextColor=function(self,...) colorUpdates=colorUpdates+1; self.color={...} end}
end
local tip={unit="mouseover",shown=true,additions={},name="HoverFixture"}
function tip:GetName() return self.name end
function tip:NumLines() return #self.additions end
function tip:GetPrimaryTooltipData() return self.data end
function tip:IsShown() return self.shown end
function tip:Show() self.shown=true end
function tip:HookScript() end
function tip:ClearLines() self.additions={} end
function tip:RefreshDataNextUpdate() self.refreshRequested=true end
function tip:AddDoubleLine(label,value,r,g,b)
    local left,right=font(label),font(value)
    left.color={r,g,b}
    self.additions[#self.additions+1]={left=left,right=right}
    _G[self.name .. "TextLeft" .. #self.additions]=left
    _G[self.name .. "TextRight" .. #self.additions]=right
end
GameTooltip=tip
hooksecurefunc=function(object,key,fn)
    local old=object[key]; object[key]=function(...) old(...); fn(...) end
end
for _,file in ipairs({"Weights.lua","Scoring.lua","LevelBenchmarks.lua","DungeonBenchmarks.lua","DungeonLevels.lua",
    "Dungeons.lua","GearAssessment.lua","GearTotals.lua"}) do assert(loadfile(file))("FossieGearScore",NS) end
NS.GetGearScore=function() return current,cached end
local mode="normal"
NS.GetDisplayMode=function() return mode end
NS.GetDisplayVisibility=function() return mode=="normal" or mode=="both",mode=="dynamic" or mode=="both" end
-- Any attempt to evaluate alternate specs on hover is a regression.
NS.GetCachedItemDynamicScore=function() error("hover evaluated another spec") end
local function draw()
    tip:ClearLines(); tip.data={type=2,guid=UnitGUID(tip.unit)}; tip.refreshRequested=false
    callback(tip,tip.data)
    check(not NS.gearUIError,"hover decoration did not throw")
end
for _,case in ipairs({{211,"Very Badly Geared"},{212,"Badly Geared"},{238.5,"Averagely Geared"},
    {291.5,"Well Geared"},{318,"Well Geared"},{371,"Overgeared"}}) do
    current.score=case[1]; draw()
    check(#tip.additions==3 and tip.additions[1].left.text==case[2] and tip.additions[2].left.text=="GS:",
        "five hover labels follow the menu's GS percentage bands and appear above GS")
end
current.score=265; draw()
current.score=371; callback(tip,tip.data)
check(#tip.additions==3 and tip.additions[1].left.text=="Overgeared"
    and tip.additions[1].left.color[3]==1,"live grade changes update text and colour without duplicate rows")
do
    local before=colorUpdates
    for i=1,100 do callback(tip,tip.data) end
    check(colorUpdates==before,"identical hover callbacks do not reset an unchanged native text colour")
end
current.enchantmentScore=999; current.enchantmentUnknown=true; draw()
check(tip.additions[1].left.text=="Overgeared","hover grade excludes enchantment points, even unknown tiers")
current.partial=true; draw()
check(#tip.additions==2 and tip.additions[1].left.text=="GS:","partial gear cannot show a guessed hover rating")
current.partial=false; current.dataPending=true; draw()
check(#tip.additions==2,"pending items cannot receive a hover rating")
current.dataPending=false; units.mouseover.level=1; draw()
check(#tip.additions==2,"a zero level reference has no hover rating")
units.mouseover.level=61; draw(); check(#tip.additions==2,"unsupported levels do not invent a hover grade")
units.mouseover.level=30; current.dynamicAvailable=true; current.dynamicScore=100; mode="dynamic"; draw()
check(tip.additions[1].left.text=="Overgeared" and tip.additions[2].left.text=="DGS:",
    "dynamic-only hover still rates ordinary GS above the visible score")
mode="none"; draw(); check(#tip.additions==0,"disabled player scores also hide the rating")
mode="both"; draw(); local oldGrade=tip.additions[1].left
units.mouseover.guid="Changed"; tip.data={type=2,guid="Changed"}; callback(tip,tip.data)
check(oldGrade.text=="" and tip.refreshRequested,"a tooltip identity change clears the previous player's rating")
print("PASS: " .. count .. " player-hover rating checks (" .. _VERSION .. ")")
