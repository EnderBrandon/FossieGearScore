local count,frames=0,{}
local function check(ok,why) assert(ok,why); count=count+1 end
local function font()
    return {SetText=function(self,v) self.text=v end,SetPoint=function() end,SetWidth=function(self,v) self.width=v end,
        SetJustifyH=function() end,GetStringHeight=function(self) return math.ceil(#self.text*6/self.width)*14 end}
end
CreateFrame=function(_,name,parent,template)
    local f={name=name,parent=parent,template=template,scripts={},events={},shown=true}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:SetScript(event,fn) self.scripts[event]=fn end
    function f:SetPoint() end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetFrameStrata(value) self.strata=value end
    function f:SetClampedToScreen(value) self.clamped=value end
    function f:EnableMouse() end
    function f:SetBackdrop(value) self.backdrop=value end
    function f:SetBackdropColor() end
    function f:SetBackdropBorderColor() end
    function f:CreateFontString() return font() end
    function f:SetText(v) self.text=v end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    frames[#frames+1]=f
    return f
end
UIParent={}
local function loadNotice()
    local ns={}
    assert(loadfile("UpdateMessage.lua"))("FossieGearScore",ns)
    assert(loadfile("UpdateNotice.lua"))("FossieGearScore",ns)
    return ns,frames[#frames]
end
FossieGearScoreDB={inspectionPanelAlpha=0.3,otherSetting="keep"}
local NS,events=loadNotice()
check(not NS.updateNoticePanel,"popup waits until login instead of opening at file load")
events.scripts.OnEvent(events,"ADDON_LOADED")
check(not NS.updateNoticePanel,"unrelated events cannot open the notice")
events.scripts.OnEvent(events,"PLAYER_LOGIN")
local panel=NS.updateNoticePanel
check(panel.shown and panel.width==420 and panel.height>=148 and panel.strata=="DIALOG" and panel.clamped,
    "first login shows a compact, clamped update popup")
check(panel.message.text==[[FossieGearScore has been updated. Right-click a player's portrait and select "GearScore" to see their gearscore summary.]],
    "popup displays the requested message exactly")
check(panel.okay.text=="Okay!","popup has the requested dismissal button")
check(not FossieGearScoreDB.acknowledgedUpdateNotice,"opening alone does not acknowledge unread content")
local frameCount=#frames; events.scripts.OnEvent(events,"PLAYER_LOGIN")
check(#frames==frameCount,"repeated login notifications do not allocate duplicate popup controls")
panel.okay.scripts.OnClick(panel.okay)
check(not panel.shown and FossieGearScoreDB.acknowledgedUpdateNotice==NS.UPDATE_NOTICE.id,
    "Okay closes the popup and saves its acknowledgement")
check(FossieGearScoreDB.inspectionPanelAlpha==0.3 and FossieGearScoreDB.otherSetting=="keep","acknowledgement preserves other saved settings")
local reloaded,reloadEvents=loadNotice(); reloadEvents.scripts.OnEvent(reloadEvents,"PLAYER_LOGIN")
check(not reloaded.updateNoticePanel,"acknowledged notice stays hidden across login/reload")
reloaded.UPDATE_NOTICE.text="Text edit without a new flag"; reloaded.ShowUpdateNotice()
check(not reloaded.updateNoticePanel,"editing text alone does not repeat an acknowledged message")
reloaded.UPDATE_NOTICE.id="next-notice"; reloaded.ShowUpdateNotice()
check(reloaded.updateNoticePanel.shown and reloaded.updateNoticePanel.message.text=="Text edit without a new flag",
    "changing the notice id explicitly flags the edited message to show again")
reloaded.updateNoticePanel.okay.scripts.OnClick()
reloaded.UPDATE_NOTICE.id="disabled-notice"; reloaded.UPDATE_NOTICE.enabled=false; reloaded.ShowUpdateNotice()
check(not reloaded.updateNoticePanel.shown and FossieGearScoreDB.acknowledgedUpdateNotice=="next-notice",
    "disabled notices neither open nor consume their flag")
local cold,coldEvents=loadNotice(); FossieGearScoreDB=nil
coldEvents.scripts.OnEvent(coldEvents,"PLAYER_LOGIN")
check(cold.updateNoticePanel.shown and type(FossieGearScoreDB)=="table","first installation can show the notice with no saved database")
local unread,unreadEvents=loadNotice(); unreadEvents.scripts.OnEvent(unreadEvents,"PLAYER_LOGIN")
check(unread.updateNoticePanel.shown,"a notice interrupted before Okay remains available next login")
print("PASS: " .. count .. " update-notice persistence checks (" .. _VERSION .. ")")
