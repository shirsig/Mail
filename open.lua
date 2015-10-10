Postal.open = {}

local wait_for_update, open, process, inventory_count

local controller = (function()
	local controller
	return function()
		controller = controller or Postal.control.controller()
		return controller
	end
end)()

function wait_for_update(k)
	return controller().wait(function() return true end, k)
end

function Postal.open.start(selected, callback)
	Postal.control.on_next_update(function()
		process(selected, function()
		callback()
		end)
	end)
end

function Postal.open.stop()
	Postal.control.on_next_update(function()
		controller().reset()
	end)
end

function process(selected, k)
	if getn(selected) == 0 then
		return k()
	else
		local index = selected[1]
		GetInboxText(index)
		controller().wait(function() return GetInboxText(index) or not (({ GetInboxHeaderInfo })[11] or ({ GetInboxText(index) })[3]) end, function()
		local _, _, _, _, money, CODAmount, _, hasItem = GetInboxHeaderInfo(index)
		local bodyText, _, _, isInvoice = GetInboxText(index)
		
		if CODAmount > 0 then
			tremove(selected, 1)
			return process(selected, k)
		end
		
		local inbox_count_before = GetInboxNumItems()
		open(index, hasItem, money > 0, bodyText and not isInvoice, function()
		controller().wait(function() return GetInboxNumItems() < inbox_count_before end, function()
		tremove(selected, 1)
		for i, _ in selected do
			selected[i] = selected[i] - 1
		end
		return process(selected, k)
		end)end)end)
	end
end

function open(i, has_item, has_money, has_message, k)
	wait_for_update(function()
		if has_item then
			local inventory_count_before = inventory_count()
			TakeInboxItem(i)
			controller().wait(function() return inventory_count() > inventory_count_before end, function()
			return open(i, false, has_money, has_message, k)
			end)
		elseif has_money then
			local money_before = GetMoney()
			TakeInboxMoney(i)
			controller().wait(function() return GetMoney() > money_before end, function()
			return open(i, false, false, has_message, k)
			end)
		elseif has_message then
			local _, _, _, _, money, _, _, hasItem = GetInboxHeaderInfo(i)
			if not (money > 0) and not hasItem then
				DeleteInboxItem(i)
			end
			return open(i, false, false, false, k)
		else
			return k()
		end
	end)
end

function open_alternative(i, k, inbox_count)
	wait_for_update(function()
		local _, _, _, _, money, CODAmount, _, has_item = GetInboxHeaderInfo(index)
		if CODAmount > 0 then
			return k()
		elseif has_item then
			TakeInboxItem(i)
			open_alternative(i, k, inbox_count)
		elseif money > 0 then
			TakeInboxMoney(i)
			open_alternative(i, k, inbox_count)
		else
			if GetInboxNumItems() == inbox_count then
				DeleteInboxItem(i)
			end
			controller().wait(function() return GetInboxNumItems() < inbox_count end, k)
		end
	end)
end

function inventory_count()
	local acc = 0
	for bag = 0, 4 do
		if GetBagName(bag) then
			for slot = 1, GetContainerNumSlots(bag) do
				local _, count = GetContainerItemInfo(bag, slot)
				acc = acc + (count or 0)
			end
		end
	end
	return acc
end