local self = CreateFrame('Frame', nil, MailFrame)
Postal = self
self:SetScript('OnUpdate', function() this:UPDATE() end)
self:SetScript('OnEvent', function() this[event](this) end)
for _, event in {'ADDON_LOADED', 'VARIABLES_LOADED', 'UI_ERROR_MESSAGE', 'CURSOR_UPDATE', 'BAG_UPDATE', 'MAIL_CLOSED', 'MAIL_SEND_SUCCESS'} do
	self:RegisterEvent(event)
end

local ATTACHMENTS_MAX = 21
local ATTACHMENTS_PER_ROW_SEND = 7
local ATTACHMENTS_MAX_ROWS_SEND = 3

self.hook, self.orig = {}, {}
function self:Hook(...)
	for i=1,arg.n do
		self.orig[arg[i]] = getglobal(arg[i])
		setglobal(arg[i], self.hook[arg[i]])
	end
end

do
    local state
    function self:UPDATE()
        if state and state.predicate() then
            local callback = state.callback
            state = nil
            return callback()
        end
    end
    function self:When(predicate, callback)
        state = {predicate = predicate, callback = callback}
    end
    function self:Wait(callback)
        state = {predicate = function() return true end, callback = callback}
    end
    function self:Kill()
        state = nil
    end
end

do
	local cursorItem
    function self:CURSOR_UPDATE()
        cursorItem = nil
    end
	function self:GetCursorItem()
		return cursorItem
	end
	function self:SetCursorItem(item)
        self:Wait(function() cursorItem = item end)
	end
end

function self:BAG_UPDATE()
	SendMailFrame_Update()
end

function self:MAIL_CLOSED()
	self:Abort()
	self.Inbox_selectedItems = {}
	self:SendMail_Clear()

	-- Hides the minimap unread mail button if there are no unread mail on closing the mailbox.
	-- Does not scan past the first 50 items since only the first 50 are viewable.
	for i=1,GetInboxNumItems() do
		if not ({GetInboxHeaderInfo(i)})[9] then return end
	end
	MiniMapMailFrame:Hide()
end

function self:MAIL_SEND_SUCCESS()
	self.SendMail_ready = true
end

function self:UI_ERROR_MESSAGE()
	if self.Inbox_opening then
		if arg1 == ERR_INV_FULL then
			self:Print('Inventory full. Aborting.', 1, 0, 0)
			self:Abort()
		elseif arg1 == ERR_ITEM_MAX_COUNT then
			self:Print('You already have the maximum amount of that item. Skipping.', 1, 0, 0)
			self.Inbox_skip = true
		end
	end
end

function self:ADDON_LOADED()
	if arg1 ~= 'Postal' then return end

	UIPanelWindows['MailFrame'].pushable = 1
	UIPanelWindows['FriendsFrame'].pushable = 2

	MailItem1:SetPoint('TOPLEFT', 'InboxFrame', 'TOPLEFT', 48, -80)
	for i=1,7 do
		getglobal('MailItem' .. i .. 'ExpireTime'):SetPoint('TOPRIGHT', 'MailItem' .. i, 'TOPRIGHT', 10, -4)
		getglobal('MailItem' .. i):SetWidth(280)
	end

    SendMailFrame:CreateTexture('PostalHorizontalBarLeft', 'BACKGROUND')
    PostalHorizontalBarLeft:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-HorizontalBar]])
    PostalHorizontalBarLeft:SetWidth(256)
    PostalHorizontalBarLeft:SetHeight(16)
    PostalHorizontalBarLeft:SetTexCoord(0, 1, 0, 0.25)
    SendMailFrame:CreateTexture('PostalHorizontalBarRight', 'BACKGROUND')
    PostalHorizontalBarRight:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-HorizontalBar]])
    PostalHorizontalBarRight:SetWidth(75)
    PostalHorizontalBarRight:SetHeight(16)
    PostalHorizontalBarRight:SetTexCoord(0, 0.29296875, 0.25, 0.5)
    PostalHorizontalBarRight:SetPoint('LEFT', PostalHorizontalBarLeft, 'RIGHT')

    do
        local background = ({SendMailPackageButton:GetRegions()})[1]
        background:Hide()
        local count = ({SendMailPackageButton:GetRegions()})[3]
        count:Hide()
        SendMailPackageButton:Disable()
        SendMailPackageButton:SetScript('OnReceiveDrag', nil)
        SendMailPackageButton:SetScript('OnDragStart', nil)
    end

    SendMailMoneyText:SetPoint('TOPLEFT', 0, -2)
    SendMailMoney:ClearAllPoints()
    SendMailMoney:SetPoint('TOPLEFT', SendMailMoneyText, 'BOTTOMLEFT', 5, -3)
    SendMailSendMoneyButton:SetPoint('TOPLEFT', SendMailMoney, 'TOPRIGHT', 0, 12)

    -- hack to avoid automatic subject setting and button disabling from weird blizzard code
	PostalMailButton = SendMailMailButton
	SendMailMailButton = setmetatable({}, {__index = function() return function() end end})
    SendMailMailButton_OnClick = self.PostalMailButton_OnClick
    PostalSubjectEditBox = SendMailSubjectEditBox
    SendMailSubjectEditBox = setmetatable({}, {
    	__index = function(_, key)
    		return function(_, ...)
    			return PostalSubjectEditBox[key](PostalSubjectEditBox, unpack(arg))
    		end
    	end,
    })

	SendMailNameEditBox._SetText = SendMailNameEditBox.SetText
	function SendMailNameEditBox:SetText(...)
		if not Postal_To then
			return self:_SetText(unpack(arg))
		end
	end
	SendMailNameEditBox:SetScript('OnShow', function()
		if Postal_To then
			this:_SetText(Postal_To)
		end
    end)
	SendMailNameEditBox:SetScript('OnChar', function()
		Postal_To = nil
		SendMailFrame_SendeeAutocomplete()
    end)

	for _, editBox in {SendMailNameEditBox, SendMailSubjectEditBox} do
		editBox:SetScript('OnEditFocusGained', function()
			this:HighlightText()
	    end)
	    editBox:SetScript('OnEditFocusLost', function()
	    	this:HighlightText(0, 0)
	    end)
	    do
	        local lastClick
		    editBox:SetScript('OnMouseUp', function()
	            local x, y = GetCursorPosition()
	            if lastClick and GetTime() - lastClick.t < .5 and x == lastClick.x and y == lastClick.y then
		            lastClick = nil
	                this:HighlightText()
	            else
	                lastClick = {t=GetTime(), x=x, y=y}
	            end
	        end)
    	end
	end

    self.Inbox_selectedItems = {}
    self.SendMail_ready = true
end

function self:VARIABLES_LOADED()
	self:Hook(
		'OpenMail_Reply',
		'InboxFrame_Update','InboxFrame_OnClick', 'InboxFrameItem_OnEnter',
		'SendMailFrame_Update', 'SendMailFrame_CanSend', 'ClickSendMailItemButton', 'GetContainerItemInfo', 'PickupContainerItem', 'SplitContainerItem', 'UseContainerItem'
	)
end

function self.hook.OpenMail_Reply(...)
	Postal_To = nil
	return self.orig.OpenMail_Reply(unpack(arg))
end

function self:Print(msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage('Postal: '..msg, r, g, b)
end

function self:Present(value)
	return value ~= nil and {[value]=true} or {}
end

function self:Abort()
	self:Kill()
	self.Inbox_opening = false
	self:Inbox_Lock()
end

function self.hook.InboxFrame_Update()
	self.orig.InboxFrame_Update()
	for i=1,7 do
		local index = (i + (InboxFrame.pageNum - 1) * 7)
		if index > GetInboxNumItems() then
			getglobal('PostalBoxItem'..i..'CB'):Hide()
		else
			getglobal('PostalBoxItem'..i..'CB'):Show()
			getglobal('PostalBoxItem'..i..'CB'):SetChecked(self.Inbox_selectedItems[index])
		end
	end
	self:Inbox_Lock()
end

function self.hook.InboxFrame_OnClick(index)
	if self.Inbox_opening then
		this:SetChecked(nil)
	else
		return self.orig.InboxFrame_OnClick(index)
	end
end

function self.hook.InboxFrameItem_OnEnter()
	local tooltipSet
	GameTooltip:SetOwner(this, 'ANCHOR_RIGHT')
	if this.index then
		if GetInboxItem(this.index) then
			GameTooltip:SetInboxItem(this.index)
			tooltipSet = true
		end
	end
	if this.money then
		GameTooltip:AddLine(ENCLOSED_MONEY, '', 1, 1, 1)
		SetTooltipMoney(GameTooltip, this.money)
		SetMoneyFrameColor('GameTooltipMoneyFrame', HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	elseif this.cod then
		GameTooltip:AddLine(COD_AMOUNT, '', 1, 1, 1)
		SetTooltipMoney(GameTooltip, this.cod)
		if this.cod > GetMoney() then
			SetMoneyFrameColor('GameTooltipMoneyFrame', RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		else
			SetMoneyFrameColor('GameTooltipMoneyFrame', HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	end
	if tooltipSet and (this.money or this.cod) then
		GameTooltip:SetHeight(GameTooltip:GetHeight()+getglobal('GameTooltipTextLeft' .. GameTooltip:NumLines()):GetHeight())
		if GameTooltipMoneyFrame:IsVisible() then
			GameTooltip:SetHeight(GameTooltip:GetHeight()+GameTooltipMoneyFrame:GetHeight())
		end
	end
	GameTooltip:Show()
end

function self:Inbox_SetSelected()
	local index = this:GetID() + (InboxFrame.pageNum - 1) * 7
	self.Inbox_selectedItems[index] = this:GetChecked()
end

function self:Inbox_OpenSelected(all)
	self:Abort()

	local selected = {}
	if all then
		for i=1,GetInboxNumItems() do
			tinsert(selected, i)
		end
	else
		for i, _ in self.Inbox_selectedItems do
			tinsert(selected, i)
		end
		sort(selected)
	end
	self.Inbox_selectedItems = {}
	self.Inbox_opening = true
	self:Inbox_Lock()
	self:Inbox_OpenMail(selected)
end

function self:Inbox_OpenMail(selected)
	if getn(selected) == 0 then
		self.Inbox_opening = false
		self:Inbox_Lock()
	else
		self:Inbox_OpenItem(selected[1], GetInboxNumItems(), selected)
	end
end

function self:Inbox_OpenItem(i, inboxCount, selected)
	self:Wait(function()
		local _, _, _, _, money, COD, _, item = GetInboxHeaderInfo(i)
		local newInboxCount = GetInboxNumItems()

		if newInboxCount < inboxCount or COD > 0 or self.Inbox_skip then
			self.Inbox_skip = false
			tremove(selected, 1)
			if newInboxCount < inboxCount then
				for j, _ in selected do
					selected[j] = selected[j] - 1
				end
			end
			return self:Inbox_OpenMail(selected)
		elseif item then
			TakeInboxItem(i)
			self:When(function() return not ({GetInboxHeaderInfo(i)})[8] or GetInboxNumItems() < inboxCount or self.Inbox_skip end, function()
				return self:Inbox_OpenItem(i, inboxCount, selected)
			end)
		elseif money > 0 then
			TakeInboxMoney(i)
			self:When(function() return ({GetInboxHeaderInfo(i)})[5] == 0 or GetInboxNumItems() < inboxCount or self.Inbox_skip end, function()
				return self:Inbox_OpenItem(i, inboxCount, selected)
			end)
		else
			DeleteInboxItem(i)
			self:When(function() return GetInboxNumItems() < inboxCount or self.Inbox_skip end, function()
				return self:Inbox_OpenItem(i, inboxCount, selected)
			end)
		end
	end)
end

function self:Inbox_Lock()
	for i=1,7 do
		getglobal('MailItem'..i..'ButtonIcon'):SetDesaturated(self.Inbox_opening)
		if self.Inbox_opening then
			getglobal('MailItem'..i..'Button'):SetChecked(nil)
		end
	end
end

function self.hook.SendMailFrame_Update()
    local itemCount = 0
    local itemTitle
    local gap
    -- local last = 0 blizzlike
    local last = self:SendMail_NumAttachments()

	for i=1,ATTACHMENTS_MAX do
		local btn = getglobal('PostalAttachment' .. i)

		local texture, count
		if btn.item then
			texture, count = GetContainerItemInfo(unpack(btn.item))
		end
		if not texture then
			btn:SetNormalTexture(nil)
			getglobal(btn:GetName()..'Count'):Hide()
			btn.item = nil
		else
			btn:SetNormalTexture(texture)
			if count > 1 then
				getglobal(btn:GetName()..'Count'):Show()
				getglobal(btn:GetName()..'Count'):SetText(count)
			else
				getglobal(btn:GetName()..'Count'):Hide()
			end
		end
	end

    if self:SendMail_NumAttachments() > 0 then
        SendMailCODButton:Enable()
        SendMailCODButtonText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
        SendMailRadioButton_OnClick(1)
        SendMailCODButton:Disable()
        SendMailCODButtonText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    end

    MoneyFrame_Update('SendMailCostMoneyFrame', GetSendMailPrice() * max(1, self:SendMail_NumAttachments()))

	-- Determine how many rows of attachments to show
	local itemRowCount = 1
	local temp = last
	while temp > ATTACHMENTS_PER_ROW_SEND and itemRowCount < ATTACHMENTS_MAX_ROWS_SEND do
		itemRowCount = itemRowCount + 1
		temp = temp - ATTACHMENTS_PER_ROW_SEND
	end

	if not gap and temp == ATTACHMENTS_PER_ROW_SEND and itemRowCount < ATTACHMENTS_MAX_ROWS_SEND then
		itemRowCount = itemRowCount + 1
	end
	if SendMailFrame.maxRowsShown and last > 0 and itemRowCount < SendMailFrame.maxRowsShown then
		itemRowCount = SendMailFrame.maxRowsShown
	else
		SendMailFrame.maxRowsShown = itemRowCount
	end

	-- Compute sizes
	local cursorx = 0
	local cursory = itemRowCount - 1
	local marginxl = 8 + 6
	local marginxr = 40 + 6
	local areax = SendMailFrame:GetWidth() - marginxl - marginxr
	local iconx = PostalAttachment1:GetWidth() + 2
	local icony = PostalAttachment1:GetHeight() + 2
	local gapx1 = floor((areax - (iconx * ATTACHMENTS_PER_ROW_SEND)) / (ATTACHMENTS_PER_ROW_SEND - 1))
	local gapx2 = floor((areax - (iconx * ATTACHMENTS_PER_ROW_SEND) - (gapx1 * (ATTACHMENTS_PER_ROW_SEND - 1))) / 2)
	local gapy1 = 5
	local gapy2 = 6
	local areay = (gapy2 * 2) + (gapy1 * (itemRowCount - 1)) + (icony * itemRowCount)
	local indentx = marginxl + gapx2 + 17
	local indenty = 170 + gapy2 + icony - 13
	local tabx = (iconx + gapx1) - 3 --this magic number changes the attachment spacing
	local taby = (icony + gapy1)
	local scrollHeight = 249 - areay

	PostalHorizontalBarLeft:SetPoint('TOPLEFT', SendMailFrame, 'BOTTOMLEFT', 2 + 15, 184 + areay - 14)

	SendMailScrollFrame:SetHeight(scrollHeight)
	SendMailScrollChildFrame:SetHeight(scrollHeight)

	local SendMailScrollFrameTop = ({SendMailScrollFrame:GetRegions()})[3]
	SendMailScrollFrameTop:SetHeight(scrollHeight)
	SendMailScrollFrameTop:SetTexCoord(0, 0.484375, 0, scrollHeight / 256)

	StationeryBackgroundLeft:SetHeight(scrollHeight)
	StationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, scrollHeight / 256)


	StationeryBackgroundRight:SetHeight(scrollHeight)
	StationeryBackgroundRight:SetTexCoord(0, 1.0, 0, scrollHeight / 256)

    -- Set Items
	for i=1,ATTACHMENTS_MAX do
		if cursory >= 0 then
			getglobal('PostalAttachment'..i):Enable()
			getglobal('PostalAttachment'..i):Show()
			getglobal('PostalAttachment'..i):SetPoint('TOPLEFT', 'SendMailFrame', 'BOTTOMLEFT', indentx + (tabx * cursorx), indenty + (taby * cursory))
			
			cursorx = cursorx + 1
			if cursorx >= ATTACHMENTS_PER_ROW_SEND then
				cursory = cursory - 1
				cursorx = 0
			end
		else
			getglobal('PostalAttachment'..i):Hide()
		end
	end

	SendMailFrame_CanSend()
end

function self.hook.SendMailFrame_CanSend()
	if strlen(SendMailNameEditBox:GetText()) > 0 and (SendMailSendMoneyButton:GetChecked() and MoneyInputFrame_GetCopper(SendMailMoney) or 0) + GetSendMailPrice() * max(1, self:SendMail_NumAttachments()) <= GetMoney() then
		PostalMailButton:Enable()
	else
		PostalMailButton:Disable()
	end
end

function self.hook.ClickSendMailItemButton()
    self:SendMail_SetAttachment(self:GetCursorItem())
end

function self.hook.GetContainerItemInfo(...)
    local item = {arg[1], arg[2]}
    local ret = {self.orig.GetContainerItemInfo(unpack(arg))}
    ret[3] = ret[3] or self:SendMail_Attached(item) 
    return unpack(ret)
end

function self.hook.PickupContainerItem(...)
	local item = {arg[1], arg[2]}
	if self:SendMail_Attached(item) then return end
	if GetContainerItemInfo(unpack(item)) then self:SetCursorItem(item) end
	return self.orig.PickupContainerItem(unpack(arg))
end

function self.hook.SplitContainerItem(...)
    local item = {arg[1], arg[2]}
    if self:SendMail_Attached(item) then return end
    return self.orig.SplitContainerItem(unpack(arg))
end

function self.hook.UseContainerItem(...)
    local item = {arg[1], arg[2]}
    if self:SendMail_Attached(item) then return end
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
        return self.orig.UseContainerItem(unpack(arg))
    elseif SendMailFrame:IsVisible() then
        self:SendMail_SetAttachment(item)
    elseif TradeFrame:IsVisible() then
        for i=1,6 do
            if not GetTradePlayerItemLink(i) then
                self.orig.PickupContainerItem(unpack(arg))
                ClickTradeButton(i)
                return
            end
        end
    else
        return self.orig.UseContainerItem(unpack(arg))
    end
end

function self.PostalMailButton_OnClick()
	self:Abort()

	Postal_To = SendMailNameEditBox:GetText()
	SendMailNameEditBox:HighlightText()

	self.SendMail_state = {
	    to = Postal_To,
	    subject = PostalSubjectEditBox:GetText(),
	    body = SendMailBodyEditBox:GetText(),
	    money = MoneyInputFrame_GetCopper(SendMailMoney),
	    cod = SendMailCODButton:GetChecked(),
	    attachments = self:SendMail_Attachments(),
	    numMessages = max(1, self:SendMail_NumAttachments()),
	}

	self:SendMail_Clear()

	self:When(function()
		return self.SendMail_ready
	end, function()
		self:SendMail_Send()
	end)
end

function self:SendMail_Attached(item)
    for i=1,ATTACHMENTS_MAX do
        local btn = getglobal('PostalAttachment' .. i)
        if btn.item and btn.item[1] == item[1] and btn.item[2] == item[2] then
            return true
        end
    end
    if not self.SendMail_state then
        return
    end
    for _, attachment in self.SendMail_state.attachments do
        if attachment.item and attachment.item[1] == item[1] and attachment.item[2] == item[2] then
            return true
        end
    end
end

function self:AttachmentButton_OnClick()
	local attachedItem = this.item
	local cursorItem = self:GetCursorItem()
	if self:SendMail_SetAttachment(cursorItem, this) then
		if attachedItem then
			if arg1 == 'LeftButton' then self:SetCursorItem(attachedItem) end
			self.orig.PickupContainerItem(unpack(attachedItem))
			if arg1 ~= 'LeftButton' then ClearCursor() end -- for the lock changed event
	    end
	end
end

-- requires an item lock changed event for a proper update
function self:SendMail_SetAttachment(item, slot)
	if item and not self:SendMail_PickupMailable(item) then
		return
    elseif not slot then
		for i=1,ATTACHMENTS_MAX do
			if not getglobal('PostalAttachment'..i).item then
				slot = getglobal('PostalAttachment'..i)
	            break
			end
		end
	end
	if slot then
		if not (item or slot.item) then return true end
		slot.item = item
		ClearCursor()
	    SendMailFrame_Update()
	    return true
	end
end

function self:SendMail_PickupMailable(item)
	ClearCursor()
	self.orig.ClickSendMailItemButton()
	ClearCursor()
	self.orig.PickupContainerItem(unpack(item))
	self.orig.ClickSendMailItemButton()
	local mailable = GetSendMailItem() and true or false
	self.orig.ClickSendMailItemButton()
	return mailable
end

function self:SendMail_NumAttachments()
	local num = 0
	for i=1,ATTACHMENTS_MAX do
		if getglobal('PostalAttachment'..i).item then
			num = num + 1
		end
	end
	return num
end

function self:SendMail_Attachments()
    local arr = {}
    for i=1,ATTACHMENTS_MAX do
        local btn = getglobal('PostalAttachment'..i)
        if btn.item then
            tinsert(arr, btn.item)
        end
    end
    return arr
end

function self:SendMail_Clear()
	for i=1,ATTACHMENTS_MAX do
        getglobal('PostalAttachment'..i).item = nil
	end
	PostalMailButton:Disable()
	SendMailNameEditBox:SetText('')
	SendMailNameEditBox:SetFocus()
	PostalSubjectEditBox:SetText('')
	SendMailBodyEditBox:SetText('')
	MoneyInputFrame_ResetMoney(SendMailMoney)
	SendMailRadioButton_OnClick(1)

	SendMailFrame_Update()
end

function self:SendMail_Send()
	for item in self:Present(tremove(self.SendMail_state.attachments, 1)) do
		ClearCursor()
		self.orig.ClickSendMailItemButton()
		ClearCursor()
		self.orig.PickupContainerItem(unpack(item))
		self.orig.ClickSendMailItemButton()

		if not GetSendMailItem() then
            return self:Print('Unknown error. Aborting.', 1, 0, 0)
		end
	end

	for amount in self:Present(self.SendMail_state.money) do
		self.SendMail_state.money = nil
		if self.SendMail_state.cod then
			SetSendMailCOD(amount)
		else
			SetSendMailMoney(amount)
		end
	end

	local subject = self.SendMail_state.subject
	subject = subject ~= '' and subject or '[No Subject]'
	if self.SendMail_state.numMessages > 1 then
		subject = subject..format(' (Part %d of %d)', self.SendMail_state.numMessages - getn(self.SendMail_state.attachments), self.SendMail_state.numMessages)
	end

    SendMail(self.SendMail_state.to, subject, self.SendMail_state.body)
    self.SendMail_ready = false

    if getn(self.SendMail_state.attachments) > 0 then
	    self:When(function()
	    	return self.SendMail_ready
	    end, function()
	    	self:SendMail_Send()
	    end)
    end
end