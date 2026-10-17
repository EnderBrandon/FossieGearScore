local _, NS = ...
local panel, selection, refreshQueued, pollGeneration = nil, nil, false, 0
local menuHooks = {}
local ARMOR_SLOTS = {1,3,5,6,7,8,9,10,15}
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PANEL_WIDTH, PADDING, CONTENT_WIDTH = 620, 16, 588
local CARD_GAP, CARD_HEIGHT, DUNGEON_ROW_HEIGHT = 8, 78, 32
local DUNGEON_HEADER_HEIGHT, FOOTER_HEIGHT = 44, 36
local refresh, request, createPanel

local function call(fn, ...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e,f,g=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g end
end
local function safeString(value)
    return NS.IsSafe(value) and type(value)=="string" and value~="" and value or nil
end
local function guidFor(unit) return safeString(call(UnitGUID,unit)) end
local function now() return NS.GetNumber(call(GetTime)) or 0 end
local function matches(unit,guid)
    return safeString(unit) and guidFor(unit)==guid and call(UnitIsPlayer,unit)==true
end
local function selectedUnit(who)
    local unit=call(UnitTokenFromGUID,who.guid)
    if matches(unit,who.guid) then return unit end
    for _,candidate in ipairs({who.unit or "","player","target","focus","mouseover"}) do
        if matches(candidate,who.guid) then return candidate end
    end
end
function NS.CaptureInspectionSelection(unit)
    if not safeString(unit) or call(UnitIsPlayer,unit)~=true then return end
    local guid=guidFor(unit)
    if not guid then return end
    local name,realm=call(UnitName,unit)
    local className,classToken=call(UnitClass,unit)
    local level=NS.GetNumber(call(UnitLevel,unit))
    if guidFor(unit)~=guid then return end
    name=safeString(name) or "Unknown player"
    realm=safeString(realm)
    return {guid=guid,unit=unit,name=name .. (realm and "-" .. realm or ""),
        className=safeString(className),classToken=safeString(classToken),level=level and level>0 and level or nil}
end

local function metadata(link,item)
    local _,_,_,loc,icon,_,subclass=call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,link)
    local name=call(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
    return {equipLoc=safeString(loc) or item and item.equipLoc,icon=NS.IsSafe(icon) and icon~=0 and icon or nil,
        subclass=NS.GetNumber(subclass),name=safeString(name) or link:match("%[([^]]+)%]") or "Loading item..."}
end
local function enhancement(item,link)
    if not item or item.dataPending then return {state="unknown"} end
    local enchant=item.enchantment
    if enchant then
        if item.enchantmentUnknown or enchant.unknown then return {state="unsupported",enchanted=true} end
        local tier=NS.GetNumber(enchant.tier)
        if tier then return {state="enchanted",enchanted=true,tier=tier,ambiguous=enchant.ambiguous==true} end
    end
    -- A zero/empty link field and complete native permanent-line coverage establish
    -- absence. An unavailable API, truncated link or empty tooltip does not.
    local permanent=Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    local id=link:match("item:%d+:([^:|]*):")
    if permanent and (id=="0" or id=="") and item.lines and #item.lines>0 and not item.partial and not item.enchantmentUnknown then
        return {state="missing",enchanted=false}
    end
    return {state="unknown"}
end
local function enchantmentText(enchant)
    return enchant and enchant.enchanted and "Enchanted" or ""
end
local function talentText(who)
    if who.level and who.level<NS.TALENT_RULES.minLevel then return "Spec unknown","0/0/0" end
    local actual=NS.talentProfiles and NS.talentProfiles[who.guid]
    if not actual or actual.guid~=who.guid or actual.classToken~=who.classToken then return "Spec unknown","Talents unknown" end
    local points=actual.points
    local a,b,c=points and NS.GetNumber(points[1]),points and NS.GetNumber(points[2]),points and NS.GetNumber(points[3])
    local split=a and b and c and string.format("%.0f/%.0f/%.0f",a,b,c) or "Talents unknown"
    return actual.available and actual.name or "Spec unknown",split
end
local function itemView(record,slot,allMetadata)
    local item=record and record.itemDetails[slot]
    local link=record and record.links[slot]
    -- Known empty slots have no highlight. Unavailable data stays distinct
    -- from an empty slot and is explained by the panel's loading status.
    if not link then return end
    local view={slot=slot,link=link,item=item}
    local info=allMetadata[slot]
    view.name,view.icon=info.name,info.icon
    view.loading=not item or item.partial or item.dataPending
    if not view.loading then view.score,view.dynamicScore=item.score,item.dynamicScore end
    if NS.IsPermanentEnhancementEligible(info.equipLoc,info.subclass) then
        view.enchantment=enchantmentText(enhancement(item,link))
    end
    return view
end

-- Project GUID-bound snapshots without inventory scans or inspection requests.
-- Alternative spec estimates reuse captured item data and cache per snapshot.
function NS.BuildInspectionPanelData(who)
    local model={name=who.name,className=who.className,level=who.level,guid=who.guid,highlights={}}
    model.spec,model.talents=talentText(who)
    local record=NS.gearSnapshots and NS.gearSnapshots[who.guid] or NS.gearCache and NS.gearCache[who.guid]
    if record and (record.guid~=who.guid or record.classToken~=who.classToken) then record=nil end
    model.record=record
    local complete=record and not record.partial and not record.dataPending and next(record.links)~=nil
    model.complete=complete==true
    model.assessment=NS.BuildGearAssessment(who.level,record,model.complete)
    model.dungeons,model.dungeonStatus,model.dungeonScoreType=NS.BuildDungeonRatings(who.level,record,model.complete)
    local allMetadata={}
    local coverage={eligible=0,enchanted=0,missing=0,unknown=0,unsupported=0,unresolved=0,tiers={},ambiguous=0}
    model.coverage=coverage
    if record then
        for slot,link in pairs(record.links) do
            local item=record.itemDetails[slot]
            local info=metadata(link,item)
            allMetadata[slot]=info
            local eligible=NS.IsPermanentEnhancementEligible(info.equipLoc,info.subclass)
            if eligible==nil then coverage.unresolved=coverage.unresolved+1
            elseif eligible then
                coverage.eligible=coverage.eligible+1
                local enchant=enhancement(item,link)
                if enchant.enchanted then coverage.enchanted=coverage.enchanted+1 end
                if enchant.state=="enchanted" then
                    if enchant.ambiguous then coverage.ambiguous=coverage.ambiguous+1
                    else coverage.tiers[enchant.tier]=(coverage.tiers[enchant.tier] or 0)+1 end
                else coverage[enchant.state]=coverage[enchant.state]+1 end
            end
        end
    end
    if record and next(record.missingSlots or {}) then coverage.unresolved=coverage.unresolved+1 end
    local normal,dynamic="Loading...","Unavailable"
    if complete then
        normal=NS.FormatGearTotal(record,false,false,"character")
        if record.dynamicAvailable and record.dynamicScore~=nil then dynamic=NS.FormatGearTotal(record,false,true,"character") end
    end
    model.gs,model.dgs=normal,dynamic
    model.override=record and record.dynamicProfile and record.dynamicProfile.overridden and record.dynamicProfile.name or nil
    local function highlight(slot)
        local view=itemView(record,slot,allMetadata)
        if view then model.highlights[#model.highlights+1]=view end
    end
    if who.classToken=="HUNTER" then
        highlight(18)
    else
        highlight(16)
        local main=allMetadata[16]
        if not main or main.equipLoc~="INVTYPE_2HWEAPON" then highlight(17) end
    end
    local best
    if complete then
        for _,slot in ipairs(ARMOR_SLOTS) do
            local item=record.itemDetails[slot]
            if item and not item.partial and not item.dataPending and item.score~=nil
                and (not best or item.score>record.itemDetails[best].score) then best=slot end
        end
    end
    if best then highlight(best) end
    local known=complete and coverage.unknown==0 and coverage.unresolved==0
    local fraction=string.format("%d/%d eligible pieces enchanted",coverage.enchanted,coverage.eligible)
    model.enchantments=complete and coverage.unresolved==0 and fraction or "Enhancement data unavailable"
    local details={}
    if coverage.missing>0 then details[#details+1]=coverage.missing .. " missing" end
    if coverage.unknown>0 then details[#details+1]=coverage.unknown .. " unknown" end
    if coverage.unsupported>0 then details[#details+1]=coverage.unsupported .. " unsupported tiers" end
    if coverage.ambiguous>0 then details[#details+1]=coverage.ambiguous .. " uncertain tiers" end
    if coverage.unresolved>0 then details[#details+1]="Slot eligibility incomplete" end
    model.enchantmentDetails=table.concat(details,"; ")
    local tiers={}
    for tier=1,#NS.ENCHANTMENT_REFERENCE.tierPoints do
        if coverage.tiers[tier] then tiers[#tiers+1]="Tier " .. tier .. ": " .. coverage.tiers[tier] end
    end
    model.tiers=table.concat(tiers,"   ")
    if not known then model.summary="Inspection incomplete; no equipment assessment available."
    elseif coverage.eligible==0 then model.summary="No eligible equipped pieces."
    else
        model.summary=coverage.enchanted==coverage.eligible and "Fully enchanted" or fraction
        if #tiers>1 then model.summary=model.summary .. "; mixed enchant tiers" end
        if coverage.unsupported>0 or coverage.ambiguous>0 then model.summary=model.summary .. "; some tiers unknown" end
        model.summary=model.summary .. "."
    end
    return model
end

local function label(owner,font,x,y,width,height)
    local text=owner:CreateFontString(nil,"OVERLAY",font)
    text:SetPoint("TOPLEFT",owner,"TOPLEFT",x,y)
    text:SetSize(width,height)
    text:SetJustifyH("LEFT"); text:SetJustifyV("TOP")
    text:SetTextColor(0.92,0.88,0.78)
    text:SetShadowColor(0,0,0,1); text:SetShadowOffset(1,-1)
    return text
end
local function divider(owner,x,y,width,height)
    local texture=owner:CreateTexture(nil,"ARTWORK")
    texture:SetPoint("TOPLEFT",owner,"TOPLEFT",x,y)
    texture:SetSize(width,height or 1)
    texture:SetColorTexture(0.55,0.48,0.34,0.45)
    return texture
end
local function createDungeonSection(owner)
    local section=CreateFrame("Frame",nil,owner)
    section:SetSize(CONTENT_WIDTH,200)
    section.title=label(section,"GameFontNormal",0,0,360,18); section.title:SetText("Dungeons & raids")
    section.bracket=label(section,"GameFontHighlightSmall",380,-1,208,16); section.bracket:SetJustifyH("RIGHT")
    label(section,"GameFontHighlightSmall",8,-23,340,14):SetText("Instance")
    section.referenceHeader=label(section,"GameFontHighlightSmall",358,-23,90,14)
    section.referenceHeader:SetJustifyH("RIGHT")
    section.ratingHeader=label(section,"GameFontHighlightSmall",462,-23,110,14)
    divider(section,0,-40,CONTENT_WIDTH)
    section.scroll=CreateFrame("ScrollFrame",nil,section)
    section.scroll:SetPoint("TOPLEFT",section,"TOPLEFT",0,-DUNGEON_HEADER_HEIGHT)
    section.scroll:SetWidth(CONTENT_WIDTH-16)
    section.content=CreateFrame("Frame",nil,section.scroll)
    section.content:SetSize(CONTENT_WIDTH-16,1)
    section.scroll:SetScrollChild(section.content)
    section.slider=CreateFrame("Slider",nil,section)
    section.slider:EnableMouse(true)
    section.slider:SetPoint("TOPRIGHT",section,"TOPRIGHT",-1,-DUNGEON_HEADER_HEIGHT)
    section.slider:SetWidth(10); section.slider:SetOrientation("VERTICAL")
    section.slider:SetMinMaxValues(0,0); section.slider:SetValueStep(1)
    section.slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb=section.slider:GetThumbTexture()
    thumb:SetSize(10,28); thumb:SetColorTexture(0.66,0.49,0.27,1)
    local track=section.slider:CreateTexture(nil,"BACKGROUND"); track:SetAllPoints(section.slider)
    track:SetColorTexture(0.18,0.16,0.12,1)
    section.slider:SetScript("OnValueChanged",function(_,value)
        value=NS.GetNumber(value)
        if value then section.scroll:SetVerticalScroll(value) end
    end)
    section.scroll:EnableMouseWheel(true)
    section.scroll:SetScript("OnMouseWheel",function(self,delta)
        local current=NS.GetNumber(call(self.GetVerticalScroll,self)) or 0
        section.slider:SetValue(math.max(0,math.min(self.limit or 0,current-delta*DUNGEON_ROW_HEIGHT)))
    end)
    section.empty=label(section,"GameFontHighlightSmall",8,-DUNGEON_HEADER_HEIGHT-6,CONTENT_WIDTH-16,24)
    section.rows={}
    -- Allocate once, bounded by the configured catalogue. Redraws only update
    -- text/visibility, so filtering and scrolling never request another scan.
    for i=1,#NS.DUNGEON_CATALOGUE do
        local row=CreateFrame("Frame",nil,section.content)
        row:SetSize(CONTENT_WIDTH-16,DUNGEON_ROW_HEIGHT)
        row:SetPoint("TOPLEFT",section.content,"TOPLEFT",0,-(i-1)*DUNGEON_ROW_HEIGHT)
        row.background=row:CreateTexture(nil,"BACKGROUND"); row.background:SetAllPoints(row)
        row.background:SetColorTexture(0.55,0.48,0.34,i%2==0 and 0.12 or 0)
        row.name=label(row,"GameFontHighlightSmall",8,-3,340,28)
        call(row.name.SetMaxLines,row.name,2)
        row.baseline=label(row,"GameFontHighlightSmall",358,-8,90,16); row.baseline:SetJustifyH("RIGHT")
        row.rating=label(row,"GameFontHighlightSmall",462,-8,110,16)
        row.divider=divider(row,0,-DUNGEON_ROW_HEIGHT+1,CONTENT_WIDTH-16)
        section.rows[i]=row
    end
    return section
end
local function updateDungeonSection(section,model,top)
    section:ClearAllPoints(); section:SetPoint("TOPLEFT",panel,"TOPLEFT",PADDING,-top)
    section.bracket:SetText(model.level and "Level " .. model.level .. " bracket" or "Level unknown")
    section.referenceHeader:SetText(model.dungeonScoreType and "Reference " .. model.dungeonScoreType or "Reference")
    section.ratingHeader:SetText("Your rating" .. (model.dungeonScoreType and " (" .. model.dungeonScoreType .. ")" or ""))
    local rows=model.dungeons
    local contentHeight=0
    for i,data in ipairs(rows) do
        local row=section.rows[i]
        local lines={}
        for _,instance in ipairs(data.instances) do
            lines[#lines+1]=instance.name .. "  |cffa9a18f(" .. instance.minLevel .. "-" .. instance.maxLevel .. ")|r"
        end
        local rowHeight=math.max(DUNGEON_ROW_HEIGHT,#lines*16+8)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",section.content,"TOPLEFT",0,-contentHeight)
        row:SetHeight(rowHeight)
        row.name:SetHeight(rowHeight-8); call(row.name.SetMaxLines,row.name,#lines)
        row.name:SetText(table.concat(lines,"\n"))
        row.baseline:ClearAllPoints(); row.baseline:SetPoint("TOPLEFT",row,"TOPLEFT",358,-(rowHeight-16)/2)
        row.rating:ClearAllPoints(); row.rating:SetPoint("TOPLEFT",row,"TOPLEFT",462,-(rowHeight-16)/2)
        row.divider:ClearAllPoints(); row.divider:SetPoint("TOPLEFT",row,"TOPLEFT",0,-rowHeight+1)
        contentHeight=contentHeight+rowHeight
    end
    local screenHeight=NS.GetNumber(call(UIParent.GetHeight,UIParent)) or 768
    local available=screenHeight-top-DUNGEON_HEADER_HEIGHT-FOOTER_HEIGHT-32
    local budget=math.max(DUNGEON_ROW_HEIGHT,math.floor(available/DUNGEON_ROW_HEIGHT)*DUNGEON_ROW_HEIGHT)
    local height=math.max(DUNGEON_ROW_HEIGHT,math.min(4*DUNGEON_ROW_HEIGHT,contentHeight,budget))
    section.scroll:SetHeight(height)
    section.slider:SetHeight(height)
    section.content:SetHeight(math.max(1,contentHeight))
    for i,row in ipairs(section.rows) do
        local data=rows[i]
        if data then
            row.baseline:SetText(tostring(data.baseline))
            row.rating:SetText(data.rating and data.rating.label or model.dungeonStatus or "Score unavailable")
            local color=data.rating and data.rating.color or {0.65,0.65,0.65}
            row.rating:SetTextColor(unpack(color)); row:Show()
        else row:Hide() end
    end
    if #rows>0 then section.scroll:Show(); section.empty:Hide()
    else
        height=24; section.scroll:Hide(); section.empty:Show()
        section.empty:SetText(not model.level and "Player level unavailable." or "No dungeon benchmarks for this level.")
    end
    local offset=NS.GetNumber(call(section.scroll.GetVerticalScroll,section.scroll)) or 0
    if section.guid~=model.guid or section.level~=model.level then offset=0 end
    local limit=math.max(0,contentHeight-height)
    section.scroll.limit=limit
    section.slider:SetMinMaxValues(0,limit)
    offset=math.max(0,math.min(offset,limit))
    section.slider:SetValue(offset); section.scroll:SetVerticalScroll(offset)
    if limit>0 then section.slider:Show() else section.slider:Hide() end
    section.guid,section.level=model.guid,model.level
    section:SetHeight(DUNGEON_HEADER_HEIGHT+height)
    return top+DUNGEON_HEADER_HEIGHT+height+FOOTER_HEIGHT
end
local function showItem(row)
    if not row.link or not GameTooltip then return end
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    -- A full instance hyperlink stays valid if the selected player's unit
    -- token disappears or the shared inspect buffer belongs to someone else.
    GameTooltip:SetHyperlink(row.link)
    GameTooltip:Show()
end
function NS.GetInspectionTooltipResult(tooltip,link)
    if not panel or not panel:IsShown() or not selection or not panel.model then return end
    local owner=call(tooltip.GetOwner,tooltip)
    for _,row in ipairs(panel.rows) do
        if owner==row and row.link==link then
            local record=panel.model.record
            local item=record and record.guid==selection.guid and record.itemDetails[row.slot]
            if not item or item.link~=link then return end
            -- Tooltip decoration/debug may attach comparison fields. Preserve
            -- the equipped snapshot while reusing its owner-specific scores.
            local copy={}
            for key,value in pairs(item) do copy[key]=value end
            return copy
        end
    end
end
local function hideItem(row)
    if GameTooltip and call(GameTooltip.GetOwner,GameTooltip)==row then GameTooltip:Hide() end
end
local function showEnhancements(owner)
    local model=panel and panel.model
    if not model or not GameTooltip then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(model.enchantments,1,0.82,0)
    if model.enchantmentDetails~="" then GameTooltip:AddLine(model.enchantmentDetails,1,1,1,true) end
    if model.tiers~="" then GameTooltip:AddLine(model.tiers,1,1,1,true) end
    if model.summary~=model.enchantments .. "." then GameTooltip:AddLine(model.summary,1,1,1,true) end
    GameTooltip:Show()
end
function NS.RefreshInspectionPanelOpacity()
    if not panel then return end
    local alpha=NS.GetInspectionPanelAlpha()
    panel:SetBackdropColor(0.09,0.07,0.05,alpha)
    for _,row in ipairs(panel.rows) do row:SetBackdropColor(0.04,0.04,0.03,0.65*alpha) end
    for i,row in ipairs(panel.dungeons.rows) do
        row.background:SetColorTexture(0.55,0.48,0.34,i%2==0 and 0.12*alpha or 0)
    end
end
createPanel=function()
    if panel then return panel end
    panel=CreateFrame("Frame","FossieGearScoreInspectionPanel",UIParent,"BackdropTemplate")
    panel:SetSize(PANEL_WIDTH,420); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true); panel:SetMovable(true); panel:EnableMouse(true)
    -- Use an opaque source texture: the dialog background has transparency
    -- baked into its pixels, so a tint alpha of 1 cannot make it fully opaque.
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
    panel:SetBackdropBorderColor(0.72,0.49,0.25,1)
    panel:Hide()
    panel:SetScript("OnHide",function()
        pollGeneration=pollGeneration+1
        for _,row in ipairs(panel.rows) do hideItem(row) end
        hideItem(panel.enhancements)
    end)
    local drag=CreateFrame("Frame",nil,panel)
    drag:SetPoint("TOPLEFT",12,-8); drag:SetPoint("TOPRIGHT",-40,-8); drag:SetHeight(34)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() panel:StartMoving() end)
    drag:SetScript("OnDragStop",function() panel:StopMovingOrSizing() end)
    panel.title=label(panel,"GameFontNormalLarge",PADDING,-12,550,22); panel.title:SetText("FossieGearScore")
    panel.title:SetTextColor(1,0.82,0)
    local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-3,-3); close:SetScript("OnClick",function() panel:Hide() end)
    panel.player=label(panel,"GameFontHighlightLarge",PADDING,-40,CONTENT_WIDTH,22)
    panel.identity=label(panel,"GameFontHighlightSmall",PADDING,-65,CONTENT_WIDTH,16)
    panel.spec=label(panel,"GameFontHighlightSmall",PADDING,-84,CONTENT_WIDTH,30)
    panel.scoreTop=divider(panel,PADDING,-116,CONTENT_WIDTH)
    panel.scoreMiddle=divider(panel,PANEL_WIDTH/2,-124,1,52)
    panel.scoreBottom=divider(panel,PADDING,-182,CONTENT_WIDTH)
    panel.gs=label(panel,"GameFontNormalLarge",PADDING,-124,276,22)
    panel.dgs=label(panel,"GameFontNormalLarge",326,-124,276,22)
    panel.gs:SetTextColor(1,0.82,0); panel.dgs:SetTextColor(1,0.82,0)
    panel.gsCaption=label(panel,"GameFontHighlightSmall",PADDING,-148,276,28)
    panel.dgsCaption=label(panel,"GameFontHighlightSmall",326,-148,276,28)
    panel.suggestions=label(panel,"GameFontHighlightSmall",PADDING,-190,CONTENT_WIDTH,28)
    panel.suggestions:SetTextColor(0.56,0.80,0.48)
    panel.status=label(panel,"GameFontDisableSmall",PADDING,-190,CONTENT_WIDTH,26)
    panel.equipmentTitle=label(panel,"GameFontNormal",PADDING,-176,CONTENT_WIDTH,16)
    panel.equipmentTitle:SetText("Equipment highlights")
    panel.rows={}
    for i=1,3 do
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate")
        row:SetSize(190,CARD_HEIGHT)
        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        row:SetBackdropColor(0.04,0.04,0.03,0.65); row:SetBackdropBorderColor(0.55,0.48,0.34,0.45)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("TOPLEFT",8,-10)
        row.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        row.name=label(row,"GameFontHighlightSmall",44,-8,136,30)
        call(row.name.SetMaxLines,row.name,2)
        row.scores=label(row,"GameFontHighlightSmall",8,-44,174,14)
        row.enchant=label(row,"GameFontDisableSmall",8,-61,174,13)
        row.enchant:SetTextColor(1,0.4,0.7)
        row:SetScript("OnEnter",showItem); row:SetScript("OnLeave",hideItem)
        panel.rows[i]=row
    end
    panel.enhancements=CreateFrame("Frame",nil,panel)
    panel.enhancements:SetSize(CONTENT_WIDTH,24); panel.enhancements:EnableMouse(true)
    panel.enhancements:SetScript("OnEnter",showEnhancements)
    panel.enhancements:SetScript("OnLeave",hideItem)
    panel.enchantHeading=label(panel.enhancements,"GameFontNormal",0,0,138,18)
    panel.enchantHeading:SetText("Enchantments")
    panel.enchantDivider=divider(panel,PADDING,-282,CONTENT_WIDTH)
    panel.enchantSegments={}
    for i=1,19 do
        local segment=panel.enhancements:CreateTexture(nil,"ARTWORK")
        panel.enchantSegments[i]=segment
    end
    panel.dungeons=createDungeonSection(panel)
    local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    button:SetSize(68,20); button:SetPoint("BOTTOMRIGHT",-PADDING,10); button:SetText("Refresh")
    button:SetScript("OnClick",function() request(true) end)
    panel.refreshButton=button
    NS.RefreshInspectionPanelOpacity()
    if type(UISpecialFrames)=="table" then UISpecialFrames[#UISpecialFrames+1]="FossieGearScoreInspectionPanel" end
    NS.inspectionPanel=panel
    return panel
end

refresh=function()
    if not panel or not panel:IsShown() or not selection then return end
    local unit=selectedUnit(selection)
    local level=unit and NS.GetNumber(call(UnitLevel,unit))
    if level and level>0 then selection.level=level end
    local model=NS.BuildInspectionPanelData(selection)
    panel.model=model
    panel.player:SetText(model.name)
    panel.identity:SetText((model.level and "Level " .. model.level or "Level unknown") .. "  " .. (model.className or "Class unknown"))
    local failed=unit and NS.BackgroundInspectFailed and NS.BackgroundInspectFailed(unit)
    local status
    if model.complete then
        status=model.record.inspectedAt and (not unit or now()-model.record.inspectedAt>60) and "Cached inspection; player data may be outdated."
            or ""
    elseif failed then status="Inspection unavailable. Move closer and try Refresh."
    elseif not unit then status="Player unavailable. Showing any captured data."
    elseif selection.waitUntil and now()>=selection.waitUntil then status="Inspection incomplete. Try Refresh when the player is available."
    elseif call(InCombatLockdown)==true then status="Waiting for combat to end..."
    else status="Loading inspection and item data..." end
    if model.complete and model.spec=="Spec unknown" then
        status=status~="" and status .. " Spec unknown." or "Spec unknown."
    end
    if not model.complete and (failed or not unit or selection.waitUntil and now()>=selection.waitUntil) then
        model.gs,model.dgs="Unavailable","Unavailable"
    end
    panel.gs:SetText("GS: " .. model.gs); panel.dgs:SetText("DGS: " .. model.dgs)
    panel.spec:SetText(model.spec .. "  |  " .. model.talents .. (model.override and "\nDGS preview: " .. model.override or ""))
    panel.status:SetText(status)
    local assessment=model.assessment
    panel.gsCaption:SetText(assessment.rating and assessment.rating.label .. " for level " .. model.level or "Level rating unavailable")
    panel.gsCaption:SetTextColor(unpack(assessment.rating and assessment.rating.color or {0.65,0.65,0.65}))
    local fit="Spec fit unavailable"
    local color={0.65,0.65,0.65}
    if assessment.fit then
        local percent=math.floor(assessment.fitPercent)
        if assessment.fit=="optimal" then fit="Gear optimal for " .. assessment.spec; color={0.56,0.80,0.48}
        elseif assessment.fit=="suboptimal" then
            fit="Gear suboptimal for " .. assessment.spec .. " (" .. percent .. "%)"; color={1,0.48,0.40}
        else fit="Spec fit: " .. percent .. "% (" .. assessment.spec .. ")" end
    end
    panel.dgsCaption:SetText(fit); panel.dgsCaption:SetTextColor(unpack(color))
    local names={}
    for _,alternative in ipairs(assessment.alternatives) do names[#names+1]=alternative.name end
    local suggestion=#names>0 and "Better fit: " .. table.concat(names," / ")
        .. " (" .. math.floor(assessment.alternatives[1].percent) .. "% of GS)" or ""
    panel.suggestions:SetText(suggestion)
    local suggestionHeight=suggestion~="" and 32 or 0
    panel.status:ClearAllPoints(); panel.status:SetPoint("TOPLEFT",panel,"TOPLEFT",PADDING,-190-suggestionHeight)
    for i,row in ipairs(panel.rows) do
        local view=model.highlights[i]
        if view then
            if row.link~=view.link then hideItem(row) end
            row.link,row.slot=view.link,view.slot; row.name:SetText(view.name)
            row.icon:SetTexture(view.icon or UNKNOWN_ICON)
            local scores=view.score~=nil and "GS: " .. view.score or view.loading and "Scores unavailable" or ""
            if view.score~=nil and view.dynamicScore~=nil and view.dynamicScore~=view.score then
                scores=scores .. "  DGS: " .. view.dynamicScore
            end
            row.scores:SetText(scores)
            row.enchant:SetText(view.enchantment or ""); row:Show()
        else row.link=nil; hideItem(row); row:Hide() end
    end
    -- All enhancement counts, tier information and summaries live on hover.
    local coverage=model.coverage
    local top=(status=="" and 212 or 238)+suggestionHeight
    panel.equipmentTitle:ClearAllPoints()
    panel.equipmentTitle:SetPoint("TOPLEFT",panel,"TOPLEFT",PADDING,-top+20)
    local count=#model.highlights
    panel.equipmentTitle:SetText(count>0 and "Equipment highlights" or "")
    local cardWidth=count>0 and (CONTENT_WIDTH-(count-1)*CARD_GAP)/count or 190
    for i,row in ipairs(panel.rows) do
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",panel,"TOPLEFT",PADDING+(i-1)*(cardWidth+CARD_GAP),-top)
        row:SetSize(cardWidth,CARD_HEIGHT)
        row.name:SetWidth(cardWidth-54); row.scores:SetWidth(cardWidth-16); row.enchant:SetWidth(cardWidth-16)
    end
    local bottom=top+(count>0 and CARD_HEIGHT or 0)+18
    panel.enchantDivider:ClearAllPoints(); panel.enchantDivider:SetPoint("TOPLEFT",panel,"TOPLEFT",PADDING,-bottom+10)
    panel.enhancements:ClearAllPoints(); panel.enhancements:SetPoint("TOPLEFT",panel,"TOPLEFT",PADDING,-bottom)
    panel:SetHeight(updateDungeonSection(panel.dungeons,model,bottom+36))
    -- One segment per eligible equipped piece. Green means installed, gray
    -- means confirmed missing; blue preserves unknown coverage without judging tiers.
    local installed=coverage.enchanted
    local total=model.complete and coverage.unresolved==0 and math.min(coverage.eligible,#panel.enchantSegments) or 0
    for i,segment in ipairs(panel.enchantSegments) do
        if i<=total then
            local width=(442-(total-1)*4)/total
            segment:ClearAllPoints(); segment:SetPoint("TOPLEFT",panel.enhancements,"TOPLEFT",146+(i-1)*(width+4),-3)
            segment:SetSize(width,8)
            if i<=installed then segment:SetColorTexture(0.56,0.76,0.47,1)
            elseif i<=installed+coverage.missing then segment:SetColorTexture(0.27,0.27,0.22,1)
            else segment:SetColorTexture(0.42,0.53,0.63,1) end
            segment:Show()
        else segment:Hide() end
    end
    if call(GameTooltip and GameTooltip.GetOwner,GameTooltip)==panel.enhancements then showEnhancements(panel.enhancements) end
end
function NS.RefreshInspectionPanel()
    if refreshQueued or not panel or not panel:IsShown() then return end
    refreshQueued=true
    local function run() refreshQueued=false; refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0,run) else run() end
end
request=function(explicit)
    if not panel or not panel:IsShown() or not selection then return end
    local who=selection
    if explicit then
        who.waitUntil=now()+15
        pollGeneration=pollGeneration+1
    end
    local generation=pollGeneration
    local function step()
        if generation~=pollGeneration or not panel:IsShown() or selection~=who then return end
        local unit=selectedUnit(who)
        if unit then
            if guidFor("player")==who.guid then NS.GetGearScore("player")
            elseif NS.RequestBackgroundInspect then
                NS.RequestBackgroundInspect(unit,function()
                    return generation==pollGeneration and panel:IsShown() and selection==who
                        and matches(unit,who.guid) or false
                end)
            end
        end
        refresh()
        local record=panel.model.record
        if record and panel.model.complete then return end
        if now()<who.waitUntil and C_Timer and C_Timer.After then C_Timer.After(1,step) end
    end
    step()
end
function NS.OpenGearScoreInspection(unitOrSelection)
    local who=type(unitOrSelection)=="table" and unitOrSelection or NS.CaptureInspectionSelection(unitOrSelection)
    if not who or not safeString(who.guid) then return false end
    selection=who
    createPanel():Show()
    request(true)
    return true
end

-- Verified in Blizzard's Forever UI source (172a387e): TargetFrame_OpenMenu
-- uses these tags, not MENU_UNIT_TARGET, for actual players. ModifyMenu is
-- the supported extension point; never mutate secure UnitPopup tables.
function NS.AttachGearScorePortraitMenu()
    if not Menu or type(Menu.ModifyMenu)~="function" then return end
    for _,tag in ipairs({"SELF","PLAYER","ENEMY_PLAYER","PARTY","RAID_PLAYER"}) do
        if not menuHooks[tag] then
            local ok=pcall(Menu.ModifyMenu,"MENU_UNIT_" .. tag,function(_,root,context)
                -- PlayerFrame's SELF menu does not set fromTargetFrame.
                -- Restrict this exception to the local player's own menu.
                if not context then return end
                if context.fromTargetFrame~=true
                    and not (tag=="SELF" and context.fromPlayerFrame==true and context.unit=="player") then return end
                local who=NS.CaptureInspectionSelection(context.unit)
                if not who then return end
                root:CreateDivider()
                root:CreateButton("|cff3399ffGearScore|r",function() NS.OpenGearScoreInspection(who) end)
            end)
            menuHooks[tag]=ok or nil
        end
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED"); events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED"); events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:RegisterEvent("UI_SCALE_CHANGED"); events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent",function(_,event,arg)
    if event=="PLAYER_LOGIN" or event=="ADDON_LOADED" then NS.AttachGearScorePortraitMenu()
    elseif event=="PLAYER_REGEN_ENABLED" and panel and panel:IsShown() then request(true)
    elseif event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        local record=panel and panel:IsShown() and panel.model and panel.model.record
        local id=NS.GetNumber(arg)
        if record and id and record.itemIDs and record.itemIDs[id] then NS.RefreshInspectionPanel() end
    else NS.RefreshInspectionPanel() end
end)
NS.AttachGearScorePortraitMenu()
