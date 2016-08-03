Postal = AceLibrary('AceAddon-2.0'):new('AceEvent-2.0', 'AceHook-2.0')

local ATTACHMENTS_MAX = 21
local ATTACHMENTS_PER_ROW_SEND = 7
local ATTACHMENTS_MAX_ROWS_SEND = 3

do
    local state
    function Postal:UPDATE()
        if state and state.p() then
            local callback = state.callback
            state = nil
            return callback()
        end

        if self.Send_State and self.Send_Ready then
            self:Send_SendMail()
        end
    end

    function Postal:When(p, callback)
        state = {
            p = p,
            callback = callback,
        }
    end

    function Postal:Wait(callback)
        state = {
            p = function() return true end,
            callback = callback,
        }
    end

    function Postal:Kill()
        state = nil
    end
end

function Postal:OnEnable()
    self:RegisterEvent('UI_ERROR_MESSAGE')
    self:RegisterEvent('MAIL_SEND_SUCCESS')
    self:RegisterEvent('MAIL_CLOSED')
    self:RegisterEvent('CURSOR_UPDATE')

    self:Hook('ContainerFrameItemButton_OnClick')
    self:Hook('PickupContainerItem')
    self:Hook('UseContainerItem')
    self:Hook('ClickSendMailItemButton')
    self:Hook('SendMailFrame_Update')
    self:Hook('SendMailFrame_CanSend')
    self:Hook('SetItemButtonDesaturated')
    self:Hook('InboxFrame_OnClick')
    self:Hook('InboxFrameItem_OnEnter')
    self:Hook('InboxFrame_Update')

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

    do
        SendMailMoneyText:SetPoint('TOPLEFT', 0, -2)
        SendMailMoney:ClearAllPoints()
        SendMailMoney:SetPoint('TOPLEFT', SendMailMoneyText, 'BOTTOMLEFT', 5, -3)
        SendMailSendMoneyButton:SetPoint('TOPLEFT', SendMailMoney, 'TOPRIGHT', 0, 12)
    end

    PostalMailButton:SetScript('OnClick', function()
        local attachments = self:Send_Attachments()
        self.Send_State = {
            first = true,
            to = SendMailNameEditBox:GetText(),
            subject = PostalSubjectEditBox:GetText(),
            body = SendMailBodyEditBox:GetText(),
            money = MoneyInputFrame_GetCopper(SendMailMoney),
            cod = SendMailCODButton:GetChecked(),
            attachments = attachments,
            total = getn(attachments),
        }

        self:Send_Clear()
        SendMailFrame_Update()
    end)

    -- hack to avoid automatic subject setting/button enabling
    SendMailMailButton:Hide()
    SendMailSubjectEditBox:Hide()
    SendMailSubjectEditBox.SetText = function(self, text) PostalSubjectEditBox:SetText(text) end
    SendMailNameEditBox:SetScript('OnTabPressed', function()
        PostalSubjectEditBox:SetFocus()
    end)
    SendMailNameEditBox:SetScript('OnEnterPressed', function()
        PostalSubjectEditBox:SetFocus()
    end)
    SendMailBodyEditBox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            PostalSubjectEditBox:SetFocus()
        else
            SendMailMoneyGold:SetFocus()
        end
    end)

    SendMailFrame_Update()
end

function Postal:OnInitialize()

	-- Allows the mail frame to be pushed
	if UIPanelWindows['MailFrame'] then
		UIPanelWindows['MailFrame'].pushable = 1
	else
		UIPanelWindows['MailFrame'] = { area = 'left', pushable = 1 }
	end

	-- Close FriendsFrame will close if you try to open a mail with mailframe+friendsframe open
	if UIPanelWindows['FriendsFrame'] then
		UIPanelWindows['FriendsFrame'].pushable = 2
	else
		UIPanelWindows['FriendsFrame'] = { area = 'left', pushable = 2 }
	end

	MailItem1:SetPoint('TOPLEFT', 'InboxFrame', 'TOPLEFT', 48, -80)
	for i=1,7 do
		getglobal('MailItem' .. i .. 'ExpireTime'):SetPoint('TOPRIGHT', 'MailItem' .. i, 'TOPRIGHT', 10, -4)
		getglobal('MailItem' .. i):SetWidth(280)
	end

    CreateFrame('GameTooltip', 'PostalTooltip', nil, 'GameTooltipTemplate')
    PostalTooltip:SetOwner(WorldFrame, 'ANCHOR_NONE')

    self.MiniMapMailFrame_Show_Orig = MiniMapMailFrame.Show

    self.Inbox_selectedItems = {}
    self.Send_Ready = true
end

function Postal:SendMailFrame_Update()

    local itemCount = 0
    local itemTitle
    local gap
    -- local last = 0
    local last = self:Send_NumAttachments()

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

    if self:Send_NumAttachments() > 0 then
        SendMailCODButton:Enable()
        SendMailCODButtonText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
        SendMailRadioButton_OnClick(1)
        SendMailCODButton:Disable()
        SendMailCODButtonText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    end

    MoneyFrame_Update('SendMailCostMoneyFrame', GetSendMailPrice() * max(1, self:Send_NumAttachments()))

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

	self:SendMailFrame_CanSend()
end

function Postal:MAIL_CLOSED()
	self.Send_State = nil
	self:Inbox_Abort()
	self:Send_Clear()

	-- Hides the minimap unread mail button if there are no unread mail on closing the mailbox.
	-- Does not scan past the first 50 items since only the first 50 are viewable.
	for i=1,GetInboxNumItems() do
		if not ({GetInboxHeaderInfo(i)})[9] then
			return
		end
	end
	MiniMapMailFrame:Hide()
	-- There may be an UPDATE PENDING MAIL event after closing which would make the frame reappear, the following prevents that
	local t = GetTime()
	MiniMapMailFrame.Show = function()
		if GetTime() - t > 2 then
			MiniMapMailFrame.Show = self.MiniMapMailFrame_Show_Orig
			MiniMapMailFrame:Show()
		end
	end
end

function Postal:MAIL_SEND_SUCCESS()
	self.Send_Ready = true
end

function Postal:ContainerFrameItemButton_OnClick(btn, ignore)
	local item = {this:GetParent():GetID(), this:GetID()}
	if self:Send_Attached(item) then
		return
	else
	    return self.hooks['ContainerFrameItemButton_OnClick'].orig(btn, ignore)
    end
end

function Postal:Send_Attached(item)
    for i=1,ATTACHMENTS_MAX do
        local btn = getglobal('PostalAttachment' .. i)
        if btn.item and btn.item[1] == item[1] and btn.item[2] == item[2] then
            return true
        end
    end
    if not self.Send_State then
        return
    end
    for _, attachment in self.Send_State.attachments do
        if attachment.item and attachment.item[1] == item[1] and attachment.item[2] == item[2] then
            return true
        end
    end
end

function Postal:AttachmentButton_OnClick()
    local buttonItem = this.item
    local cursorItem = self:CursorItem()

    if cursorItem then
        ClearCursor()
        if not self:Send_Mailable(cursorItem) then
            return self:Print('Postal: Cannot attach item.', 1, 0.5, 0)
        end
        this.item = cursorItem
    end

    if buttonItem then
        this.item = nil
        PickupContainerItem(unpack(buttonItem))
    end

    SendMailFrame_Update()
end

-- requires an item lock changed event for a proper update
function Postal:Send_AttachItem(item)
	for i = 1,ATTACHMENTS_MAX do
		if not getglobal('PostalAttachment'..i).item then
			if not self:Send_Mailable(item) then
                return self:Print('Postal: Cannot attach item.', 1, 0.5, 0)
            end
			getglobal('PostalAttachment'..i).item = item
            SendMailFrame_Update()
            return
		end
	end
end

-- handle the weird built-in mail body textbox onclick
function Postal:ClickSendMailItemButton()
    self:Send_AttachItem(self:CursorItem())
    ClearCursor()
end

function Postal:SetItemButtonDesaturated(itemButton, locked)
    local item = { itemButton:GetParent():GetID(), itemButton:GetID() }
    if self:Send_Attached(item) then
        return self.hooks['SetItemButtonDesaturated'].orig(itemButton, true)
    end
    return self.hooks['SetItemButtonDesaturated'].orig(itemButton, locked)
end

function Postal:UseContainerItem(bag, slot)
    local item = {bag, slot}
    if self:Send_Attached(item) then
        return
    end

    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
        self.hooks['UseContainerItem'].orig(unpack(item))
    elseif SendMailFrame:IsVisible() then
        self:Send_AttachItem(item)
        self.hooks['PickupContainerItem'].orig(unpack(item))
        ClearCursor()
    elseif TradeFrame:IsVisible() then
        for i = 1,6 do
            if not GetTradePlayerItemLink(i) then
                self.hooks['PickupContainerItem'].orig(unpack(item))
                ClickTradeButton(i)
                return
            end
        end
    else
        self.hooks['UseContainerItem'].orig(unpack(item))
    end
end

do
	local lastPickedUp

    function Postal:CURSOR_UPDATE()
        lastPickedUp = nil
    end

	function Postal:CursorItem()
		return CursorHasItem() and lastPickedUp
	end

	function Postal:PickupContainerItem(bag, slot)
		local item = {bag, slot}
		if self:Send_Attached(item) then
			return
		end
        self:Wait(function()
            lastPickedUp = item
        end)
		return self.hooks['PickupContainerItem'].orig(unpack(item))
	end
end

function Postal:Send_Mailable(item)
--	PostalTooltip:ClearLines() TODO
	PostalTooltip:SetBagItem(unpack(item))
	for i=1,PostalTooltip:NumLines() do
		local text = getglobal('PostalTooltipTextLeft' .. i):GetText()
		if text == ITEM_SOULBOUND or text == ITEM_BIND_QUEST or text == ITEM_CONJURED or text == ITEM_BIND_ON_PICKUP then
			return false
		end
	end
	return true
end

function Postal:Send_NumAttachments()
	local num = 0
	for i=1,ATTACHMENTS_MAX do
		if getglobal('PostalAttachment'..i).item then
			num = num + 1
		end
	end
	return num
end

function Postal:Send_Attachments()
    local arr = {}
    for i = 1,ATTACHMENTS_MAX do
        local btn = getglobal('PostalAttachment' .. i)
        if btn.item then
            tinsert(arr, btn.item)
        end
    end
    return arr
end

function Postal:Send_Clear()
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
end

function Postal:SendMailFrame_CanSend()
	if strlen(SendMailNameEditBox:GetText()) > 0 and (SendMailSendMoneyButton:GetChecked() and MoneyInputFrame_GetCopper(SendMailMoney) or 0) + GetSendMailPrice() * max(1, self:Send_NumAttachments()) <= GetMoney() then
		PostalMailButton:Enable()
	else
		PostalMailButton:Disable()
	end
end

function Postal:Send_SendMail()
	local item = tremove(self.Send_State.attachments, 1)

	if item or self.Send_State.first then
		local subject = self.Send_State.subject
		subject = subject ~= '' and subject or '[No Subject]'
		if self.Send_State.total > 1 then
			subject = subject..format(' (Part %d of %d)', self.Send_State.total - getn(self.Send_State.attachments), self.Send_State.total)
		end

		if item then
			ClearCursor()
			self.hooks['ClickSendMailItemButton'].orig()
			ClearCursor()
			self.hooks['PickupContainerItem'].orig(unpack(item))
			self.hooks['ClickSendMailItemButton'].orig()

			if not GetSendMailItem() then
                return self:Print('Postal: An error occured in POSTAL. This might be related to lag, trying to send items with an item placed in the normal send mail window, or trying to send items that cannot be sent.', 1, 0, 0)
			end
		end

		if self.Send_State.first then
			self.Send_State.first = false

			if self.Send_State.money then
				if self.Send_State.cod then
					SetSendMailCOD(self.Send_State.money)
				else
					SetSendMailMoney(self.Send_State.money)
				end
			end
        end
        self.Send_Ready = nil
		return SendMail(self.Send_State.to, subject, self.Send_State.body)
    else
        self.Send_State = nil
    end
end

function Postal:Inbox_OpenMail(selected)
	if getn(selected) == 0 then
		self.Inbox_Opening = false
		self:Inbox_Lock()
	else
		self:Inbox_OpenItem(selected[1], GetInboxNumItems(), selected)
	end
end

function Postal:Inbox_OpenItem(i, inboxCount, selected)
	self:Wait(function()
		local _, _, _, _, money, COD, _, item = GetInboxHeaderInfo(i)
		local newInboxCount = GetInboxNumItems()

		if newInboxCount < inboxCount or COD > 0 then
			tremove(selected, 1)
			if newInboxCount < inboxCount then
				for j, _ in selected do
					selected[j] = selected[j] - 1
				end
			end
			return self:Inbox_OpenMail(selected)
		elseif item then
			TakeInboxItem(i)
			self:When(function() return not ({GetInboxHeaderInfo(i)})[8] or GetInboxNumItems() < inboxCount end, function()
				return self:Inbox_OpenItem(i, inboxCount, selected)
			end)
		elseif money > 0 then
			TakeInboxMoney(i)
			self:When(function() return ({GetInboxHeaderInfo(i)})[5] == 0 or GetInboxNumItems() < inboxCount end, function()
				return self:Inbox_OpenItem(i, inboxCount, selected)
			end)
		else
			DeleteInboxItem(i)
			self:When(function() return GetInboxNumItems() < inboxCount end, function()
				return self:Inbox_OpenItem(i, inboxCount, selected)
			end)
		end
	end)
end

function Postal:InboxFrameItem_OnEnter()
	local didSetTooltip
	GameTooltip:SetOwner(this, 'ANCHOR_RIGHT')
	if this.index then
		if GetInboxItem(this.index) then
			GameTooltip:SetInboxItem(this.index)
			didSetTooltip = 1
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
	if didSetTooltip and (this.money or this.cod) then
		GameTooltip:SetHeight(GameTooltip:GetHeight()+getglobal('GameTooltipTextLeft' .. GameTooltip:NumLines()):GetHeight())
		if GameTooltipMoneyFrame:IsVisible() then
			GameTooltip:SetHeight(GameTooltip:GetHeight()+GameTooltipMoneyFrame:GetHeight())
		end
	end
	GameTooltip:Show()
end

function Postal:UI_ERROR_MESSAGE()
	if event == 'UI_ERROR_MESSAGE' and (arg1 == ERR_INV_FULL or arg1 == ERR_ITEM_MAX_COUNT) then
		if this.num then
			if arg1 == ERR_INV_FULL then
				self:Inbox_Abort()
				self:Print('Postal: Inventory full. Aborting.', 1, 0, 0)
			elseif arg1 == ERR_ITEM_MAX_COUNT then
				self:Print('Postal: You already have the maximum amount of that item. Skipping.', 1, 0, 0)
				if this.lastVal then
					for key, va in this.id do
						if va >= this.lastVal then
							this.id[key] = va + 1
						end
					end
				end
			end
		end
	end
end

function Postal:Print(msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
end

function Postal:Inbox_SetSelected()
	local index = this:GetID() + (InboxFrame.pageNum - 1) * 7
	self.Inbox_selectedItems[index] = this:GetChecked()
end

function Postal:Inbox_OpenSelected(all)
	local selected = {}
	if all then
		for i = 1,GetInboxNumItems() do
			tinsert(selected, i)
		end
	else
		for i, _ in self.Inbox_selectedItems do
			tinsert(selected, i)
		end
		sort(selected)
	end
	self.Inbox_Opening = true
	self:Inbox_Lock()
	self:Inbox_OpenMail(selected)
	self.Inbox_selectedItems = {}
end

function Postal:InboxFrame_Update()
	self.hooks['InboxFrame_Update'].orig()
	for i = 1,7 do
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

function Postal:Inbox_Lock()
	for i=1,7 do
		getglobal('MailItem'..i..'ButtonIcon'):SetDesaturated(self.Inbox_Opening)
		if self.Inbox_Opening then
			getglobal('MailItem'..i..'Button'):SetChecked(nil)
		end
	end
end

function Postal:InboxFrame_OnClick(index)
	if self.Inbox_Opening then
		this:SetChecked(nil)
		return
	else
		return self.hooks['InboxFrame_OnClick'].orig(index)
	end
end

function Postal:Inbox_Abort()
	self:Kill()
	self.Inbox_Opening = false
	self:Inbox_Lock()
	self.Inbox_selectedItems = {}
end