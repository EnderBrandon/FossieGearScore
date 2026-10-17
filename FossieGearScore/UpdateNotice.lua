local _, NS = ...
local panel
local offered={}

function NS.ShowUpdateNotice()
    local notice=NS.UPDATE_NOTICE
    if not notice or not notice.enabled or type(notice.id)~="string" or notice.id==""
        or type(notice.text)~="string" or notice.text=="" then return end
    if type(FossieGearScoreDB)~="table" then FossieGearScoreDB={} end
    if FossieGearScoreDB.acknowledgedUpdateNotice==notice.id or offered[notice.id] then return end
    if not panel then
        panel=CreateFrame("Frame","FossieGearScoreUpdateNotice",UIParent,"BackdropTemplate")
        panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG"); panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
        panel:SetBackdropColor(0.09,0.07,0.05,0.95)
        panel:SetBackdropBorderColor(0.72,0.49,0.25,1)
        local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOPLEFT",22,-16); title:SetText("FossieGearScore")
        panel.message=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        panel.message:SetPoint("TOPLEFT",22,-44); panel.message:SetWidth(376)
        panel.message:SetJustifyH("LEFT")
        panel.okay=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        panel.okay:SetPoint("BOTTOM",0,14); panel.okay:SetSize(88,24)
        panel.okay:SetScript("OnClick",function()
            -- Acknowledge the notice actually displayed, even if config changes.
            if type(FossieGearScoreDB)~="table" then FossieGearScoreDB={} end
            FossieGearScoreDB.acknowledgedUpdateNotice=panel.noticeID
            panel:Hide()
        end)
        NS.updateNoticePanel=panel
    end
    panel.noticeID=notice.id
    panel.message:SetText(notice.text)
    panel.okay:SetText(notice.buttonText or "Okay!")
    panel:SetSize(420,math.max(148,panel.message:GetStringHeight()+98))
    offered[notice.id]=true
    panel:Show()
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event) if event=="PLAYER_LOGIN" then NS.ShowUpdateNotice() end end)
