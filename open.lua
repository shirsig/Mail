Postal.open = {}

local wait_for_update, open, process, stop

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
	controller().wait(function()
		process(selected, function()
			callback()
		end)
	end)
end

function Postal.open.stop()
	controller().wait(function() end)
end

function process(selected, k)
	if getn(selected) == 0 then
		return k()
	else
		local index = selected[1]
		
		local inbox_count = GetInboxNumItems()
		open(index, inbox_count, function(skipped)
			tremove(selected, 1)
			if not skipped then
				for i, _ in ipairs(selected) do
					selected[i] = selected[i] - 1
				end
			end
			return process(selected, k)
		end)
	end
end

function open(i, inbox_count, k)
	wait_for_update(function()
		local _, _, _, _, money, COD_amount, _, has_item = GetInboxHeaderInfo(i)
		if GetInboxNumItems() < inbox_count then
			return k(false)
		elseif COD_amount > 0 then
			return k(true)
		elseif has_item then
			TakeInboxItem(i)
			controller().wait(function() return not ({GetInboxHeaderInfo(i)})[8] or GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		elseif money > 0 then
			TakeInboxMoney(i)
			controller().wait(function() return ({GetInboxHeaderInfo(i)})[5] == 0 or GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		else
			DeleteInboxItem(i)
			controller().wait(function() return GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		end
	end)
end