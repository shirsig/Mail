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
	for i = 1, 7 do
		getglobal("MailItem" .. i .. "ExpireTime"):SetPoint("TOPRIGHT", "MailItem" .. i, "TOPRIGHT", 10, -4)
		getglobal("MailItem" .. i):SetWidth(280)
	end

	POSTAL_NUMITEMBUTTONS = 21
	Postal_BagLinks = {}
	Postal_ScheduledStack = {}
	Postal_SelectedItems = {}
	Postal_DELETEDELAY = 1

	PostalFrame.num = 0
	PanelTemplates_SetNumTabs(MailFrame, 3)

	PostalForwardFrame.pickItem = {}
	PostalForwardFrame.process = 0

	PostalGlobalFrame.queue = {}
	PostalGlobalFrame.update = 0
	PostalGlobalFrame.total = 0
	PostalGlobalFrame.sendmail = 0
	PostalGlobalFrame.latency = 2.25

	PostalTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

	PostalInboxFrame.eventFunc = {}
end

function Postal:OnEnable()
	self:RegisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("UI_ERROR_MESSAGE")
	self:RegisterEvent("MAIL_SEND_SUCCESS")
	self:RegisterEvent("MAIL_SEND_INFO_UPDATE")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("BAG_UPDATE")

	self:Hook("ContainerFrameItemButton_OnClick")
	self:Hook("PickupContainerItem")
	self:Hook("UseContainerItem")
	self:Hook("ContainerFrame_Update")
	self:Hook("ClickSendMailItemButton")
	self:HookScript(TradeFrame, "OnShow", "TF_Show")
	self:Hook("InboxFrameItem_OnEnter")
	self:Hook("MailFrameTab_OnClick")
	self:Hook("InboxFrame_OnClick")
	self:Hook("InboxFrame_Update")
	self:Hook("CloseMail")
	self:Hook("OpenMail_Reply")
	oldTakeInboxMoney = OpenMailMoneyButton:GetScript("OnClick")
end

function Postal:MAIL_CLOSED()
	Postal:ClearItems()
	PostalGlobalFrame.total = 0
	PostalGlobalFrame.queue = {}
	-- Hides the minimap unread mail button if there are no unread mail on closing the mailbox.
	-- Does not scan past the first 50 items since only the first 50 are viewable.
	for i = 1, GetInboxNumItems() do
		_, _, _, _, _, _, _, _, wasRead = GetInboxHeaderInfo(i)
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
	if self:GetItemFrame(this:GetParent():GetID(), this:GetID()) then
		return
	end
	self.hooks["ContainerFrameItemButton_OnClick"].orig(btn, ignore)
	self:UpdateItemButtons()
end

function Postal:PickupContainerItem(bag, item, special)
	if (self:GetItemFrame(bag, item) or (Postal_addItem and Postal_addItem[1] == bag and Postal_addItem[2] == item)) and not special then
		return
	end
	if not CursorHasItem() then
		PostalFrame.bag = bag
		PostalFrame.item = item
	end
	self.hooks["PickupContainerItem"].orig(bag, item)
	self:UpdateItemButtons()
end

function Postal:UseContainerItem(bag, item)
	if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
		return self.hooks["UseContainerItem"].orig(bag, item)
	end

	if self:GetItemFrame(bag, item) or (Postal_addItem and Postal_addItem[1] == bag and Postal_addItem[2] == item) then
		return
	end
	if not CursorHasItem() then
		PostalFrame.bag = bag
		PostalFrame.item = item
	end
	if PostalFrame:IsVisible() and not CursorHasItem() then
		local i
		for i = 1, POSTAL_NUMITEMBUTTONS do
			if not getglobal("PostalButton" .. i).item then

				if self:ItemIsMailable(bag, item) then
					Postal:Print("Postal: Cannot attach item.", 1, 0.5, 0)
					return
				end

				self.hooks["PickupContainerItem"].orig(bag, item)
				self:MailButton_OnClick(getglobal("PostalButton" .. i))
				self:UpdateItemButtons()
				return
			end
		end
	elseif SendMailFrame:IsVisible() and not CursorHasItem() then
		self.hooks["PickupContainerItem"].orig(bag, item)
		ClickSendMailItemButton()
		return
	elseif TradeFrame:IsVisible() and not CursorHasItem() then
		for i = 1, 6 do
			if not GetTradePlayerItemLink(i) then
				self.hooks["PickupContainerItem"].orig(bag, item)
				ClickTradeButton(i)
				return
			end
		end
	elseif not CursorHasItem() and (not TradeFrame or not TradeFrame:IsVisible()) and (not AuctionFrame or not AuctionFrame:IsVisible()) and UnitExists("target") and CheckInteractDistance("target", 2) and UnitIsFriend("player", "target") and UnitIsPlayer("target") then
		InitiateTrade("target")
		Postal_addItem = { bag, item, UnitName("target"), 2 }
		for i = 1, NUM_CONTAINER_FRAMES do
			if getglobal("ContainerFrame" .. i):IsVisible() then
				ContainerFrame_Update(getglobal("ContainerFrame" .. i))
			end
		end
		return
	end

	self.hooks["UseContainerItem"].orig(bag, item)
end

function Postal:MailFrameTab_OnClick(tab)
	if not tab then 
		tab = this:GetID()
	end

	if tab == 3 then
		PanelTemplates_SetTab(MailFrame, 3)
		InboxFrame:Hide()
		SendMailFrame:Hide()
		PostalFrame:Show()
		SendMailFrame.sendMode = "massmail"
		MailFrameTopLeft:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopLeft")
		MailFrameTopRight:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopRight")
		MailFrameBotLeft:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-BotLeft")
		MailFrameBotRight:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-BotRight")
		MailFrameTopLeft:SetPoint("TOPLEFT", "MailFrame", "TOPLEFT", 2, -1)
		return
	else
		PostalFrame:Hide()
	end
	self.hooks["MailFrameTab_OnClick"].orig(tab)
	self:Forward_EnableForward()
end

function Postal:ClickSendMailItemButton()
	if not GetSendMailItem() then
		PostalFrame.mailbag = PostalFrame.bag
		PostalFrame.mailitem = PostalFrame.item
	end
	self.hooks["ClickSendMailItemButton"].orig()
end

-- Handle the dragging of items
function Postal:MailButton_OnClick(button)
	if not button then button = this end
	if CursorHasItem() then
		local bag = PostalFrame.bag
		local item = PostalFrame.item
		if not bag or not item then return end
		if self:ItemIsMailable(bag, item) then
			Postal:Print("Postal: Cannot attach item.", 1, 0.5, 0)
			self.hooks["PickupContainerItem"].orig(bag, item)
			return
		end
		self.hooks["PickupContainerItem"].orig(bag, item)
		if this.bag and this.item then
			-- There's already an item there
			-- Pickup that item to replicate Send Mail's behaviour
			self.hooks["PickupContainerItem"].orig(button.bag, button.item)
			PostalFrame.bag = button.bag
			PostalFrame.item = button.item
		else
			PostalFrame.bag = nil
			PostalFrame.item = nil
		end
		local texture, count = GetContainerItemInfo(bag, item)
		getglobal(button:GetName() .. "IconTexture"):Show()
		getglobal(button:GetName() .. "IconTexture"):SetTexture(texture)
		if count > 1 then
			getglobal(button:GetName() .. "Count"):SetText(count)
			getglobal(button:GetName() .. "Count"):Show()
		else
			getglobal(button:GetName() .. "Count"):Hide()
		end
		button.bag = bag
		button.item = item
		button.texture = texture
		button.count = count
	elseif button.item and button.bag then
		self.hooks["PickupContainerItem"].orig(button.bag, button.item)
		getglobal(button:GetName() .. "IconTexture"):Hide()
		getglobal(button:GetName() .. "Count"):Hide()
		PostalFrame.bag = button.bag
		PostalFrame.item = button.item
		button.item = nil
		button.bag = nil
		button.count = nil
		button.texture = nil
	end
	local num = self:GetNumMails()
	PostalFrame.num = num
	self:CanSend(PostalNameEditBox)
	if num == 0 then num = 1 end
	MoneyFrame_Update("PostalCostMoneyFrame", GetSendMailPrice()*num)
	for i = 1, NUM_CONTAINER_FRAMES do
		if getglobal("ContainerFrame" .. i):IsVisible() then
			ContainerFrame_Update(getglobal("ContainerFrame" .. i))
		end
	end
end

function Postal:ItemIsMailable(bag, item)
	-- Make sure tooltip is cleared
	for i = 1, 29 do
		getglobal("PostalTooltipTextLeft" .. i):SetText("")
	end

	PostalTooltip:SetBagItem(bag, item)
	for i = 1, PostalTooltip:NumLines() do
		local text = getglobal("PostalTooltipTextLeft" .. i):GetText()
		if text == ITEM_SOULBOUND or text == ITEM_BIND_QUEST or text == ITEM_CONJURED or text == ITEM_BIND_ON_PICKUP then
			return 1
		end
	end
	return nil
end


function Postal:UpdateItemButtons(frame)
	local i
	for i = 1, POSTAL_NUMITEMBUTTONS do
		local btn = getglobal("PostalButton" .. i)
		if not frame or btn ~= frame then
			local texture, count
			if btn.item and btn.bag then
				texture, count = GetContainerItemInfo(btn.bag, btn.item)
			end
			if not texture then
				getglobal(btn:GetName() .. "IconTexture"):Hide()
				getglobal(btn:GetName() .. "Count"):Hide()
				btn.item = nil
				btn.bag = nil
				btn.count = nil
				btn.texture = nil
			else
				btn.count = count
				btn.texture = texture
				getglobal(btn:GetName() .. "IconTexture"):Show()
				getglobal(btn:GetName() .. "IconTexture"):SetTexture(texture)
				if count > 1 then
					getglobal(btn:GetName() .. "Count"):Show()
					getglobal(btn:GetName() .. "Count"):SetText(count)
				else
					getglobal(btn:GetName() .. "Count"):Hide()
				end
			end
		end
	end
end

function Postal:GetItemFrame(bag, item)
	local i
	for i = 1, POSTAL_NUMITEMBUTTONS do
		local btn = getglobal("PostalButton" .. i)
		if btn.item == item and btn.bag == bag then
			return btn
		end
	end
	return nil
end

function Postal:GetNumMails()
	local i
	local num = 0
	for i = 1, POSTAL_NUMITEMBUTTONS do
		local btn = getglobal("PostalButton" .. i)
		if btn.item and btn.bag then
			num = num + 1
		end
	end
	return num
end

function Postal:ClearItems()
	local i
	local num = 0
	for i = 1, POSTAL_NUMITEMBUTTONS do
		local btn = getglobal("PostalButton" .. i)
		btn.item = nil
		btn.count = nil
		btn.bag = nil
		btn.texture = nil
	end
	self:UpdateItemButtons()
	PostalMailButton:Disable()
	PostalNameEditBox:SetText("")
	PostalSubjectEditBox:SetText("")
	PostalStatusText:SetText("")
	PostalAbortButton:Hide()
	PostalAcceptSendFrame:Hide()
end

function Postal:CanSend(eb)
	if not eb then eb = this end
	if strlen(eb:GetText()) > 0 and PostalFrame.num > 0 and GetSendMailPrice()*PostalFrame.num <= GetMoney() then
		PostalMailButton:Enable()
	else
		PostalMailButton:Disable()
	end
end

function Postal:SendMail()
	for key, val in this.queue do
		PostalStatusText:SetText(format(POSTAL_SENDING, key, this.total))
		PostalAbortButton:Show()

		if GetSendMailItem() and PostalFrame.mailbag and PostalFrame.mailitem then
			-- There's already an item in the slot
			ClickSendMailItemButton()
			self.hooks["PickupContainerItem"].orig(PostalFrame.mailbag, PostalFrame.mailitem)
			PostalFrame.mailbag = nil
			PostalFrame.mailitem = nil
		elseif CursorHasItem() and PostalFrame.bag and PostalFrame.item then
			PickupContainerItem(PostalFrame.bag, PostalFrame.item)
			PostalFrame.bag = nil
			PostalFrame.item = nil
		end

		self.hooks["PickupContainerItem"].orig(val.bag, val.item)

		ClickSendMailItemButton()

		local name, useless, count = GetSendMailItem()

		if not name then 
			Postal:Print("Postal: " .. POSTAL_ERROR, 1, 0, 0)
		else
			local subjectstr = PostalSubjectEditBox:GetText()
			if strlen(subjectstr) > 0 then
				subjectstr = subjectstr .. " "
			end

			if count > 1 then
				subjectstr = subjectstr .. "[" .. name .. " x" .. count .. "]"
			else
				subjectstr = subjectstr .. "[" .. name .. "]"
			end

			SendMail(val.to, subjectstr, format(POSTAL_ITEMNUM, key, this.total))
		end

		PostalGlobalFrame.queue[key] = nil
		return
	end
	PostalStatusText:SetText(format(POSTAL_DONESENDING, this.total))
	PostalAbortButton:Hide()
	PostalGlobalFrame:Hide()

	PostalGlobalFrame.total = 0
	PostalGlobalFrame.queue = {}
end

function Postal:FillItemTable()
	local arr = {}
	for i = 1, POSTAL_NUMITEMBUTTONS do
		local btn = getglobal("PostalButton" .. i)
		if btn.item and btn.bag then
			tinsert(arr, { ["item"] = btn.item, ["bag"] = btn.bag, ["to"] = PostalNameEditBox:GetText() })
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
		if this.total > 0 then
			self:SendMail()
			POSTAL_CANSENDNEXT = nil
		end
	end
end

function Postal:ContainerFrame_Update(frame)
	self.hooks["ContainerFrame_Update"].orig(frame)
	Postal.control.on_next_update(function() 
		local name = frame:GetName()
		for j=1, frame.size, 1 do
			local itemButton = getglobal(name.."Item"..j)
			local locked = self:GetItemFrame(itemButton:GetParent():GetID(), itemButton:GetID()) or (Postal_addItem and Postal_addItem[1] == itemButton:GetParent():GetID() and Postal_addItem[2] == itemButton:GetID())
			if locked then
				SetItemButtonDesaturated(itemButton, true, 0.5, 0.5, 0.5)
			end
		end
	end)
end

function Postal:MAIL_SEND_INFO_UPDATE()
	if not SendMailFrame:IsVisible() then return end
	local name, useless, count = GetSendMailItem()

	if name and strlen(SendMailSubjectEditBox:GetText()) == 0 then
		if count > 1 then
			name = name .. " x" .. count
		end
		SendMailSubjectEditBox:SetText(name)
	end
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
	if Postal_addItem and not CursorHasItem() and UnitName("NPC") == Postal_addItem[3] then
		self.hooks["PickupContainerItem"].orig(Postal_addItem[1], Postal_addItem[2])
		
		ClickTradeButton(1)
	end
	Postal_addItem = nil
end

function Postal:Inbox_OnUpdate(elapsed)
	if Postal_addItem then
		Postal_addItem[4] = Postal_addItem[4] - elapsed
		if Postal_addItem[4] <= 0 then
			Postal_addItem = nil
			for i = 1, NUM_CONTAINER_FRAMES do
				if getglobal("ContainerFrame" .. i):IsVisible() then
					ContainerFrame_Update(getglobal("ContainerFrame" .. i))
				end
			end
		end
	end
end

function Postal:MAIL_INBOX_UPDATE()
end

function Postal:UI_ERROR_MESSAGE()
	if event == "UI_ERROR_MESSAGE" and (arg1 == ERR_INV_FULL or arg1 == ERR_ITEM_MAX_COUNT) then
		if this.num then
			if arg1 == ERR_INV_FULL then
				Postal:Inbox_Abort()
				Postal:Print("Postal: Inventory full. Aborting.", 1, 0, 0)
			elseif arg1 == ERR_ITEM_MAX_COUNT then
				Postal:Print("Postal: You already have the maximum amount of that item. Skipping.", 1, 0, 0)
				this.timeout = Postal_DELETEDELAY
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
	-- Postal:Inbox_DisableClicks(true)
	-- PostalInboxFrame.num = true -- TODO remove
	Postal.open.start(selected, function()
		Postal:Inbox_DisableClicks(false)
		PostalInboxFrame.num = false
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
	if PostalInboxFrame.num then
		Postal:Inbox_DisableClicks(1, 1)
	end
end

function Postal:Inbox_DisableClicks(disable, loopPrevention)
	if disable then
		for i = 1, 7 do
			getglobal("MailItem" .. i .. "ButtonIcon"):SetDesaturated(1)
		end
		if not self:IsHooked("InboxFrame_OnClick") then self:Hook("InboxFrame_OnClick", "DummyFunction") end
	else
		for i = 1, 7 do
			getglobal("MailItem" .. i .. "ButtonIcon"):SetDesaturated(nil)
		end
		if not loopPrevention then
			InboxFrame_Update()
		end
		if self:IsHooked("InboxFrame_OnClick") then self:Unhook("InboxFrame_OnClick") end
	end
end

function Postal:InboxFrame_OnClick()
	this:SetChecked(nil)
end

function Postal:Inbox_Abort()
	Postal.open.stop()
	PostalInboxFrame.num = nil
	PostalInboxFrame.timeout = nil
	PostalInboxFrame.id = {}
	Postal_SelectedItems = {}
	Postal:Inbox_DisableClicks()
end

function Postal:CloseMail()
	self.hooks["CloseMail"].orig()
	Postal:Inbox_Abort()
end

-- function Postal:TakeInboxItem(id)
	-- TakeInboxItem(id)
	-- local name = GetInboxItem(id)
	-- tinsert(PostalForwardFrame.pickItem, name)
-- end

-- Mail Forwarding
function Postal:DisableAttachments(disable)
	if disable then
		OpenMailMoneyButtonIconTexture:SetDesaturated(1)
		OpenMailPackageButtonIconTexture:SetDesaturated(1)
		if not self:IsHooked(OpenMailMoneyButton, "OnClick") then self:HookScript(OpenMailMoneyButton, "OnClick", "DummyFunction") end
		if not self:IsHooked(OpenMailPackageButton, "OnClick") then self:HookScript(OpenMailPackageButton, "OnClick", "DummyFunction") end
	else
		OpenMailMoneyButtonIconTexture:SetDesaturated(nil)
		OpenMailPackageButtonIconTexture:SetDesaturated(nil)
		if self:IsHooked(OpenMailMoneyButton, "OnClick") then self:Unhook(OpenMailMoneyButton, "OnClick") end
		if self:IsHooked(OpenMailPackageButton, "OnClick") then self:Unhook(OpenMailPackageButton, "OnClick") end
	end
end

function Postal:DummyFunction()
end

function Postal:OpenMail_Reply()
	self.hooks["OpenMail_Reply"].orig()
	SendMailMoneyCopper:SetText("")
	SendMailMoneySilver:SetText("")
	SendMailMoneyGold:SetText("")
end


function Postal:OpenReply()
	OpenMail_Reply()
	local _, _, _, subject, money = GetInboxHeaderInfo(InboxFrame.openMailID)
	
	-- Money
	local gold, silver, copper = "", "", ""
	if money and money > 0 then
		gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD))
		silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
		copper = mod(money, COPPER_PER_SILVER)
	end
	SendMailMoneyCopper:SetText(copper)
	SendMailMoneySilver:SetText(silver)
	SendMailMoneyGold:SetText(gold)
	
	-- Items
	local _, itemTexture, count = GetInboxItem(InboxFrame.openMailID)
	SendMailPackageButton:SetNormalTexture(itemTexture)
	if count > 1 then
		SendMailPackageButtonCount:SetText(count)
	else
		SendMailPackageButtonCount:SetText("")
	end
	
	-- Text fields
	SendMailNameEditBox:SetText("")
	local subject = OpenMailSubject:GetText()
	local prefix = "FW:".." "
	if strsub(subject, 1, strlen(prefix)) ~= prefix then
		subject = prefix..subject
	end
	SendMailSubjectEditBox:SetText(subject or "")
	SendMailBodyEditBox:SetText(string.gsub(OpenMailBodyText:GetText() or "", "\n", "\n>"))
	SendMailNameEditBox:SetFocus()

	-- Set the send mode so the work flow can change accordingly
	SendMailFrame.sendMode = "reply"
	
	self:Forward_EnableForward(1)
end

function Postal:SendMailMailButton_OnClick()
	local name = GetInboxItem(InboxFrame.openMailID)
	local _, _, _, _, money = GetInboxHeaderInfo(InboxFrame.openMailID)
	if name then
		PostalForwardFrame.searchItem = name
		PostalForwardFrame.forwardStep = 1
		TakeInboxItem(InboxFrame.openMailID)
	else
		PostalForwardFrame.forwardStep = 2
		if money and money > 0 then
			SetSendMailMoney(money)
			PostalForwardFrame.countDown = 2
			oldTakeInboxMoney(InboxFrame.openMailID)
		else
			PostalForwardFrame.countDown = 0.5
		end
	end
	SendMailMailButton:Disable()
end

function Postal:Forward_OnUpdate(elapsed)
	if this.forwardStep and this.forwardStep > 1 then
		if this.countDown then
			this.countDown = this.countDown - elapsed
			if this.countDown <= 0 then
				if this.forwardStep == 2 then
					this.countDown = 0.5
					this.forwardStep = 3
					-- Send the mail
					SendMail(SendMailNameEditBox:GetText(), SendMailSubjectEditBox:GetText(), SendMailBodyEditBox:GetText())
					SendMailMailButton:Disable()
				elseif this.forwardStep == 3 then
					-- Delete the old one
					local _, _, _, _, money, _, _, itemID = GetInboxHeaderInfo(InboxFrame.openMailID)
					if money == 0 and not itemID then
						DeleteInboxItem(InboxFrame.openMailID)
					end
					self:MailFrameTab_OnClick(1)
					HideUIPanel(OpenMailFrame)
					this.countDown = nil
					this.forwardStep = nil
				end
			end
		end
	end
	this.process = this.process - elapsed
	if this.process <= 0 then
		this.process = 3
		if getn(Postal_ScheduledStack) > 0 then
			self:ProcessStack()
		end
	end
end

function Postal:InboxFrame_OnClick(id)
	self.hooks["InboxFrame_OnClick"].orig(id)
	local _, _, _, _, _, CODAmount = GetInboxHeaderInfo(id)
	if CODAmount and CODAmount > 0 then
		OpenMailForwardButton:Disable()
	else
		OpenMailForwardButton:Enable()
	end
end

function Postal:Forward_EnableForward(enable)
	if enable then
		OpenMailForwardButton:Disable()
		if not self:IsHooked(SendMailPackageButton, "OnEnter") then self:HookScript(SendMailPackageButton, "OnEnter", "SMPBOE") end
		SendMailCODButton:Disable()
		self:DisableAttachments(1)
		if not self:IsHooked("SendMailMailButton_OnClick") then self:Hook("SendMailMailButton_OnClick") end
		if not self:IsHooked("SendMailPackageButton_OnClick") then self:Hook("SendMailPackageButton_OnClick") end
	else
		OpenMailForwardButton:Enable()
		if self:IsHooked(SendMailPackageButton, "OnEnter") then self:Unhook(SendMailPackageButton, "OnEnter") end
		SendMailCODButton:Enable()
		self:DisableAttachments(nil)
		if self:IsHooked("SendMailMailButton_OnClick") then self:Unhook("SendMailMailButton_OnClick") end
		if self:IsHooked("SendMailPackageButton_OnClick") then self:Unhook("SendMailPackageButton_OnClick") end
	end
end

function Postal:SMPBOE()
	GameTooltip:SetOwner(SendMailPackageButton, "ANCHOR_RIGHT")
	GameTooltip:SetInboxItem(InboxFrame.openMailID) 
end

function Postal:SendMailPackageButton_OnClick()
end

function Postal:Forward_AttachSlot(container, item)
	PickupContainerItem(container, item)
	ClickSendMailItemButton()
	PostalForwardFrame.searchItem = nil
	PostalForwardFrame.forwardStep = 2
	PostalForwardFrame.countDown = 1.5
end

function Postal:BAG_UPDATE()
	local old = {}
	for k, v in Postal_BagLinks do
		if type(v) == "table" then
			old[k] = { }
			for key, val in v do
				old[k][key] = val
			end
		end
	end
	Postal_BagLinks = {}
	for i = 0, 4 do
		Postal_BagLinks[i] = {}
		for y = 1, GetContainerNumSlots(i) do
			local curr = GetContainerItemLink(i, y)
			local _, _, name = string.find(( curr or "" ), "%[(.+)%]")
			if name then
				if PostalForwardFrame.searchItem then
					if name and name == PostalForwardFrame.searchItem and not old[i][y] then
						self:Forward_AttachSlot(i, y)
					end
				else
					local _, _, name = string.find(( curr or "" ), "%[(.+)%]")
					if name and name == PostalForwardFrame.pickItem[1] and not old[i][y] then
						tremove(PostalForwardFrame.pickItem, 1)
						for k, v in old do
							local hasFound
							for key, val in v do
								if val == name and ( k ~= i or key ~= y ) then
									local _,_, link = string.find((GetContainerItemLink(k, key) or ""), "(item:[%d:]+)")
									if link then
										local texture, itemCount = GetContainerItemInfo(k,key)
										local tex, iC = GetContainerItemInfo(i, y)
										local sName, sLink, iQuality, iLevel, sType, sSubType, iCount = GetItemInfo(link)
										if sName and itemCount and iCount and iC then
											if iCount >= (itemCount+iC) then
												if getn(Postal_ScheduledStack) == 0 then
													PostalForwardFrame.process = 2
												end
												tinsert(Postal_ScheduledStack, { i, y, k, key })
												hasFound = 1
												break
											end
										end
									end
								end
							end
							if hasFound then
								break
							end
						end
					end
				end
				Postal_BagLinks[i][y] = name
			end
		end
	end
end

function Postal:ProcessStack()
	local val = tremove(Postal_ScheduledStack, 1)
	PickupContainerItem(val[1], val[2])
	PickupContainerItem(val[3], val[4])
end

local oldSMMFfunc = SendMailMoneyFrame.onvalueChangedFunc
SendMailMoneyFrame.onvalueChangedFunc = function()
	if oldSMMFfunc then
		oldSMMFfunc()
	end
	local subject = SendMailSubjectEditBox:GetText()
	if subject == "" or string.find(subject, "%[%d+G, %d+S, %d+C%]") then
		local copper, silver, gold = SendMailMoneyFrameCopper:GetText(), SendMailMoneyFrameSilver:GetText(), SendMailMoneyFrameGold:GetText()
		if not tonumber(copper) then
			copper = 0
		end
		if not tonumber(silver) then
			silver = 0
		end
		if not tonumber(gold) then
			gold = 0
		end
		SendMailSubjectEditBox:SetText(format("[%sG, %sS, %sC]", gold, silver, copper))
	end
end
