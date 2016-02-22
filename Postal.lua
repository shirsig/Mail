Postal = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceHook-2.0")

function Postal:OnInitialize()

	-- Allows the mail frame to be pushed
	if UIPanelWindows["MailFrame"] then
		UIPanelWindows["MailFrame"].pushable = 1
	else
		UIPanelWindows["MailFrame"] = { area = "left", pushable = 1 }
	end

	-- Close FriendsFrame will close if you try to open a mail with mailframe+friendsframe open
	if UIPanelWindows["FriendsFrame"] then
		UIPanelWindows["FriendsFrame"].pushable = 2
	else
		UIPanelWindows["FriendsFrame"] = { area = "left", pushable = 2 }
	end

	MailItem1:SetPoint("TOPLEFT", "InboxFrame", "TOPLEFT", 48, -80)
	for i=1,7 do
		getglobal("MailItem" .. i .. "ExpireTime"):SetPoint("TOPRIGHT", "MailItem" .. i, "TOPRIGHT", 10, -4)
		getglobal("MailItem" .. i):SetWidth(280)
	end

	ATTACHMENTS_MAX = 21
	ATTACHMENTS_PER_ROW_SEND = 7
	ATTACHMENTS_MAX_ROWS_SEND = 3

	Postal_SelectedItems = {}

	PostalGlobalFrame.sendmail = 0

	PostalTooltip:SetOwner(WorldFrame, 'ANCHOR_NONE')
end

function Postal:SendMailFrame_Update()

	MoneyFrame_Update('SendMailCostMoneyFrame', GetSendMailPrice() * max(1, self:GetNumMails()))

	local itemCount = 0
	local itemTitle
	local gap
	-- local last = 0
	local last = self:GetNumMails()
	for i=1,ATTACHMENTS_MAX do
		local btn = getglobal('PostalAttachment' .. i)

		local texture, count
		if btn.bag and btn.slot then
			texture, count = GetContainerItemInfo(btn.bag, btn.slot)
		end
		if not texture then
			btn:SetNormalTexture(nil)
			getglobal(btn:GetName()..'Count'):Hide()
			btn.slot = nil
			btn.bag = nil
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

	-- Determine how many rows of attachments to show
	local itemRowCount = 1
	local temp = last
	while temp > ATTACHMENTS_PER_ROW_SEND and itemRowCount < ATTACHMENTS_MAX_ROWS_SEND do
		itemRowCount = itemRowCount + 1;
		temp = temp - ATTACHMENTS_PER_ROW_SEND
	end

	if not gap and temp == ATTACHMENTS_PER_ROW_SEND and itemRowCount < ATTACHMENTS_MAX_ROWS_SEND then
		itemRowCount = itemRowCount + 1;
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
			getglobal("PostalAttachment"..i):Enable()
			getglobal("PostalAttachment"..i):Show()
			getglobal("PostalAttachment"..i):SetPoint("TOPLEFT", "SendMailFrame", "BOTTOMLEFT", indentx + (tabx * cursorx), indenty + (taby * cursory));
			
			cursorx = cursorx + 1
			if cursorx >= ATTACHMENTS_PER_ROW_SEND then
				cursory = cursory - 1
				cursorx = 0
			end
		else
			getglobal("PostalAttachment"..i):Hide()
		end
	end
	for i=ATTACHMENTS_MAX+1,ATTACHMENTS_MAX do
		getglobal("PostalAttachment"..i):Hide()
	end

	if self:GetNumMails() > 0 then
		SendMailCODButton:Enable();
		SendMailCODButtonText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	else
		SendMailRadioButton_OnClick(1);
		SendMailCODButton:Disable();
		SendMailCODButtonText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	end

	Postal:SendMailFrame_CanSend()
end

function Postal:OnEnable()
	self:RegisterEvent('UI_ERROR_MESSAGE')
	self:RegisterEvent('MAIL_SEND_SUCCESS')
	self:RegisterEvent('MAIL_CLOSED')

	self:Hook('ContainerFrameItemButton_OnClick')
	self:Hook('PickupContainerItem')
	self:Hook('UseContainerItem')
	self:Hook('SendMailFrame_Update')
	self:Hook('SendMailFrame_CanSend')
	self:Hook('ContainerFrame_Update')
	self:Hook('InboxFrame_OnClick')
	self:Hook('ClickSendMailItemButton')
	self:HookScript(TradeFrame, 'OnShow', 'TF_Show')
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
		PostalGlobalFrame.first = true
		PostalGlobalFrame.to = SendMailNameEditBox:GetText()
		PostalGlobalFrame.subject = PostalSubjectEditBox:GetText() ~= '' and PostalSubjectEditBox:GetText()
		PostalGlobalFrame.body = SendMailBodyEditBox:GetText()
		PostalGlobalFrame.money = MoneyInputFrame_GetCopper(SendMailMoney)
		PostalGlobalFrame.cod = SendMailCODButton:GetChecked()
		PostalGlobalFrame.queue = Postal:AttachmentList()
		PostalGlobalFrame.total = getn(PostalGlobalFrame.queue)
		PostalGlobalFrame:Show()
		POSTAL_CANSENDNEXT = 1

		Postal:ClearItems()
		Postal:SendMailFrame_Update()
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

	Postal:SendMailFrame_Update()
end

function Postal:MAIL_CLOSED()
	PostalGlobalFrame:Hide()
	Postal:Inbox_Abort()
	Postal:ClearItems()

	-- Hides the minimap unread mail button if there are no unread mail on closing the mailbox.
	-- Does not scan past the first 50 items since only the first 50 are viewable.
	for i=1,GetInboxNumItems() do
		local wasRead = ({ GetInboxHeaderInfo(i) })[9]
		if not wasRead then
			return
		end
	end
	MiniMapMailFrame:Hide()
	-- There may be an UPDATE PENDING MAIL event after closing which would make the frame reappear, the following prevents that
	local t = GetTime()
	MiniMapMailFrame.Show = function()
		if GetTime() - t > 2 then
			MiniMapMailFrame.Show = Postal_MiniMapMailFrame_Show_Orig
			MiniMapMailFrame:Show()
		end
	end
end

function Postal:MAIL_SEND_SUCCESS() 
	POSTAL_CANSENDNEXT = 1 
end

function Postal:ContainerFrameItemButton_OnClick(btn, ignore)
	local bag, slot = this:GetParent():GetID(), this:GetID()
	if self:GetAttachmentFrame(bag, slot) or self:QueuedAttachment(bag, slot) then
		return
	end
	self.hooks["ContainerFrameItemButton_OnClick"].orig(btn, ignore)
end

function Postal:PickupContainerItem(bag, slot)
	if (self:GetAttachmentFrame(bag, slot) or (Postal_itemToTrade and Postal_itemToTrade[1] == bag and Postal_itemToTrade[2] == slot)) then
		return
	end
	if not CursorHasItem() then
		PostalFrame.bag = bag
		PostalFrame.slot = slot
	end
	self.hooks["PickupContainerItem"].orig(bag, slot)
end

function Postal:UseContainerItem(bag, slot)
	if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
		return self.hooks["UseContainerItem"].orig(bag, slot)
	end

	if self:GetAttachmentFrame(bag, slot) or (Postal_itemToTrade and Postal_itemToTrade[1] == bag and Postal_itemToTrade[2] == slot) then
		return
	end
	if not CursorHasItem() then
		PostalFrame.bag = bag
		PostalFrame.slot = slot
	end
	if SendMailFrame:IsVisible() and not CursorHasItem() then
		local i
		for i = 1, ATTACHMENTS_MAX do
			if not getglobal("PostalAttachment" .. i).slot then

				if self:ItemIsMailable(bag, slot) then
					Postal:Print("Postal: Cannot attach item.", 1, 0.5, 0)
					return
				end

				self.hooks["PickupContainerItem"].orig(bag, slot)
				self:AttachmentButton_OnClick(getglobal("PostalAttachment" .. i))
				return
			end
		end
	elseif TradeFrame:IsVisible() and not CursorHasItem() then
		for i = 1, 6 do
			if not GetTradePlayerItemLink(i) then
				self.hooks["PickupContainerItem"].orig(bag, slot)
				ClickTradeButton(i)
				return
			end
		end
	elseif not CursorHasItem() and (not TradeFrame or not TradeFrame:IsVisible()) and (not AuctionFrame or not AuctionFrame:IsVisible()) and UnitExists("target") and CheckInteractDistance("target", 2) and UnitIsFriend("player", "target") and UnitIsPlayer("target") then
		InitiateTrade("target")
		Postal_itemToTrade = { bag, slot, UnitName("target"), 2 }
		for i = 1, NUM_CONTAINER_FRAMES do
			if getglobal("ContainerFrame" .. i):IsVisible() then
				ContainerFrame_Update(getglobal("ContainerFrame" .. i))
			end
		end
		return
	end

	self.hooks["UseContainerItem"].orig(bag, slot)
end

function Postal:ClickSendMailItemButton()
	if not GetSendMailItem() then
		PostalFrame.mailbag = PostalFrame.bag
		PostalFrame.mailitem = PostalFrame.slot
	end
	self.hooks["ClickSendMailItemButton"].orig()
end

-- Handle the dragging of items
function Postal:AttachmentButton_OnClick(button)
	if not button then button = this end
	if CursorHasItem() then
		local bag = PostalFrame.bag
		local slot = PostalFrame.slot
		if not bag or not slot then return end
		if self:ItemIsMailable(bag, slot) then
			Postal:Print("Postal: Cannot attach item.", 1, 0.5, 0)
			self.hooks["PickupContainerItem"].orig(bag, slot)
			return
		end
		self.hooks["PickupContainerItem"].orig(bag, slot)
		if this.bag and this.slot then
			-- There's already an item there
			-- Pickup that item to replicate Send Mail's behaviour
			self.hooks["PickupContainerItem"].orig(button.bag, button.slot)
			PostalFrame.bag = button.bag
			PostalFrame.slot = button.slot
		else
			PostalFrame.bag = nil
			PostalFrame.slot = nil
		end

		button.bag = bag
		button.slot = slot
	elseif button.slot and button.bag then
		self.hooks["PickupContainerItem"].orig(button.bag, button.slot)

		PostalFrame.bag = button.bag
		PostalFrame.slot = button.slot
		button.slot = nil
		button.bag = nil
	end

	for i=1,NUM_CONTAINER_FRAMES do
		if getglobal("ContainerFrame" .. i):IsVisible() then
			ContainerFrame_Update(getglobal("ContainerFrame" .. i))
		end
	end

	Postal:SendMailFrame_Update()
end

function Postal:ItemIsMailable(bag, slot)
	-- Make sure tooltip is cleared
	for i=1,29 do
		getglobal("PostalTooltipTextLeft" .. i):SetText("")
	end

	PostalTooltip:SetBagItem(bag, slot)
	for i=1,PostalTooltip:NumLines() do
		local text = getglobal("PostalTooltipTextLeft" .. i):GetText()
		if text == ITEM_SOULBOUND or text == ITEM_BIND_QUEST or text == ITEM_CONJURED or text == ITEM_BIND_ON_PICKUP then
			return 1
		end
	end
	return nil
end

function Postal:GetAttachmentFrame(bag, slot)
	for i=1,ATTACHMENTS_MAX do
		local btn = getglobal("PostalAttachment" .. i)
		if btn.slot == slot and btn.bag == bag then
			return btn
		end
	end
end

function Postal:QueuedAttachment(bag, slot)
	for _, attachment in ipairs(PostalGlobalFrame.queue or {}) do
		if attachment.slot == slot and attachment.bag == bag then
			return true
		end
	end
end

function Postal:GetNumMails()
	local num = 0
	for i=1,ATTACHMENTS_MAX do
		local btn = getglobal("PostalAttachment" .. i)
		if btn.slot and btn.bag then
			num = num + 1
		end
	end
	return num
end

function Postal:ClearItems()
	local num = 0
	for i=1,ATTACHMENTS_MAX do
		local btn = getglobal("PostalAttachment" .. i)
		btn.slot = nil
		btn.bag = nil
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
	if strlen(SendMailNameEditBox:GetText()) > 0 and (SendMailSendMoneyButton:GetChecked() and MoneyInputFrame_GetCopper(SendMailMoney) or 0) + GetSendMailPrice() * self:GetNumMails() <= GetMoney() then
		PostalMailButton:Enable()
	else
		PostalMailButton:Disable()
	end
end

function Postal:SendMail()

	local item = tremove(this.queue, 1)

	if item or this.first then

		local subject = this.subject or '[No Subject]'
		if this.total > 1 then
			subject = subject..format(' (Part %d of %d)', this.total - getn(this.queue), this.total)
		end

		if item then
			if GetSendMailItem() and PostalFrame.mailbag and PostalFrame.mailitem then
				-- There's already an item in the slot
				ClickSendMailItemButton()
				self.hooks["PickupContainerItem"].orig(PostalFrame.mailbag, PostalFrame.mailitem)
				PostalFrame.mailbag = nil
				PostalFrame.mailitem = nil
			elseif CursorHasItem() and PostalFrame.bag and PostalFrame.slot then
				ClearCursor()
				PostalFrame.bag = nil
				PostalFrame.slot = nil
			end

			self.hooks["PickupContainerItem"].orig(item.bag, item.slot)

			ClickSendMailItemButton()

			local name, _, count = GetSendMailItem()

			if not name then 
				Postal:Print("Postal: An error occured in POSTAL. This might be related to lag, trying to send items with an item placed in the normal send mail window, or trying to send items that cannot be sent.", 1, 0, 0)
				PostalGlobalFrame:Hide()
				return
			end
		end

		if this.first then
			this.first = false

			if this.money then
				if this.cod then
					SetSendMailCOD(this.money)
				else
					SetSendMailMoney(this.money)
				end
			end
		end

		SendMail(this.to, subject, this.body)
		return
	end

	PostalGlobalFrame:Hide()
end

function Postal:AttachmentList()
	local arr = {}
	for i = 1, ATTACHMENTS_MAX do
		local btn = getglobal("PostalAttachment" .. i)
		if btn.slot and btn.bag then
			tinsert(arr, { slot = btn.slot, bag = btn.bag })
		end
	end
	return arr
end

function Postal:ProcessQueue(elapsed)
	if not POSTAL_CANSENDNEXT then
		return
	end
	this.sendmail = this.sendmail + elapsed
	if this.sendmail > 0.5 then
		this.sendmail = 0

		self:SendMail()
		POSTAL_CANSENDNEXT = nil
	end
end

function Postal:ContainerFrame_Update(frame)
	self.hooks["ContainerFrame_Update"].orig(frame)
	Postal.control.on_next_update(function() 
		local name = frame:GetName()
		for j=1, frame.size, 1 do
			local itemButton = getglobal(name.."Item"..j)
			local bag, slot = itemButton:GetParent():GetID(), itemButton:GetID()
			local locked = self:GetAttachmentFrame(bag, slot) or self:QueuedAttachment(bag, slot) or (Postal_itemToTrade and Postal_itemToTrade[1] == bag and Postal_itemToTrade[2] == slot)
			if locked then
				SetItemButtonDesaturated(itemButton, true, 0.5, 0.5, 0.5)
			end
		end
	end)
end

function Postal:InboxFrameItem_OnEnter()
	local didSetTooltip
	if this.index then
		if GetInboxItem(this.index) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetInboxItem(this.index)
			didSetTooltip = 1
		end
	end
	if not didSetTooltip then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	end
	if this.money then
		GameTooltip:AddLine(ENCLOSED_MONEY, "", 1, 1, 1)
		SetTooltipMoney(GameTooltip, this.money)
		SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	elseif this.cod then
		GameTooltip:AddLine(COD_AMOUNT, "", 1, 1, 1)
		SetTooltipMoney(GameTooltip, this.cod)
		if this.cod > GetMoney() then
			SetMoneyFrameColor("GameTooltipMoneyFrame", RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		else
			SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	end
	if didSetTooltip and (this.money or this.cod) then
		GameTooltip:SetHeight(GameTooltip:GetHeight()+getglobal("GameTooltipTextLeft" .. GameTooltip:NumLines()):GetHeight())
		if GameTooltipMoneyFrame:IsVisible() then
			GameTooltip:SetHeight(GameTooltip:GetHeight()+GameTooltipMoneyFrame:GetHeight())
		end
	end
	GameTooltip:Show()
end

function Postal:TF_Show()
	self.hooks[TradeFrame].OnShow.orig()
	if Postal_itemToTrade and not CursorHasItem() and UnitName("NPC") == Postal_itemToTrade[3] then
		self.hooks["PickupContainerItem"].orig(Postal_itemToTrade[1], Postal_itemToTrade[2])
		
		ClickTradeButton(1)
	end
	Postal_itemToTrade = nil
end

function Postal:Inbox_OnUpdate(elapsed)
	if Postal_itemToTrade then
		Postal_itemToTrade[4] = Postal_itemToTrade[4] - elapsed
		if Postal_itemToTrade[4] <= 0 then
			Postal_itemToTrade = nil
			for i = 1, NUM_CONTAINER_FRAMES do
				if getglobal("ContainerFrame" .. i):IsVisible() then
					ContainerFrame_Update(getglobal("ContainerFrame" .. i))
				end
			end
		end
	end
end

function Postal:UI_ERROR_MESSAGE()
	if event == "UI_ERROR_MESSAGE" and (arg1 == ERR_INV_FULL or arg1 == ERR_ITEM_MAX_COUNT) then
		if this.num then
			if arg1 == ERR_INV_FULL then
				Postal:Inbox_Abort()
				Postal:Print("Postal: Inventory full. Aborting.", 1, 0, 0)
			elseif arg1 == ERR_ITEM_MAX_COUNT then
				Postal:Print("Postal: You already have the maximum amount of that item. Skipping.", 1, 0, 0)
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

function Postal_Inbox_SetSelected()
	local id = this:GetID() + (InboxFrame.pageNum - 1) * 7
	if not this:GetChecked() then
		for k, v in Postal_SelectedItems do
			if v == id then
				tremove(Postal_SelectedItems, k)
				break
			end
		end
	else
		tinsert(Postal_SelectedItems, id)
	end
end

function Postal_Inbox_OpenSelected(open_all)
	local selected = {}
	if open_all then
		for i = 1, GetInboxNumItems() do
			tinsert(selected, i)
		end
	else
		for _, i in Postal_SelectedItems do
			tinsert(selected, i)
		end
	end
	PostalInboxFrame.opening = true
	Postal:Inbox_DisableClicks()
	Postal.open.start(selected, function()
		PostalInboxFrame.opening = false
		Postal:Inbox_DisableClicks()
	end)
	Postal_SelectedItems = {}
end

function Postal:InboxFrame_Update()
	self.hooks["InboxFrame_Update"].orig()
	for i = 1, 7 do
		local index = (i + (InboxFrame.pageNum - 1) * 7)
		if index > GetInboxNumItems() then
			getglobal("PostalBoxItem" .. i .. "CB"):Hide()
		else
			getglobal("PostalBoxItem" .. i .. "CB"):Show()
			getglobal("PostalBoxItem" .. i .. "CB"):SetChecked(nil)
			for k, v in Postal_SelectedItems do
				if v == index then
					getglobal("PostalBoxItem" .. i .. "CB"):SetChecked(1)
					break
				end
			end
		end
	end
	Postal:Inbox_DisableClicks()
end

function Postal:Inbox_DisableClicks()
	for i=1,7 do
		getglobal('MailItem'..i..'ButtonIcon'):SetDesaturated(PostalInboxFrame.opening)
		if PostalInboxFrame.opening then
			getglobal('MailItem'..i..'Button'):SetChecked(nil)
		end
	end
end

function Postal:InboxFrame_OnClick(index)
	if PostalInboxFrame.opening then
		this:SetChecked(nil)
		return
	end
	self.hooks['InboxFrame_OnClick'].orig(index)
end

function Postal:Inbox_Abort()
	Postal.open.stop()
	PostalInboxFrame.opening = false
	Postal:Inbox_DisableClicks()
	PostalInboxFrame.id = {}
	Postal_SelectedItems = {}
end