Postal.util = {}

function Postal.util.set_add(set, key)
    set[key] = true
end

function Postal.util.set_remove(set, key)
    set[key] = nil
end

function Postal.util.set_contains(set, key)
    return set[key] ~= nil
end

function Postal.util.set_size(set)
    local size = 0
	for _,_ in pairs(set) do
		size = size + 1
	end
	return size
end

function Postal.util.set_to_array(set)
	local array = {}
	for element, _ in pairs(set) do
		tinsert(array, element)
	end
	return array
end

function Postal.util.any(xs, p)
	holds = false
	for _, x in ipairs(xs) do
		holds = holds or p(x)
	end
	return holds
end

function Postal.util.all(xs, p)
	holds = true
	for _, x in ipairs(xs) do
		holds = holds and p(x)
	end
	return holds
end

function Postal.util.set_filter(xs, p)
	ys = {}
	for x, _ in pairs(xs) do
		if p(x) then
			Postal.util.set_add(ys, x)
		end
	end
	return ys
end

function Postal.util.filter(xs, p)
	ys = {}
	for _, x in ipairs(xs) do
		if p(x) then
			tinsert(ys, x)
		end
	end
	return ys
end

function Postal.util.map(xs, f)
	ys = {}
	for _, x in ipairs(xs) do
		tinsert(ys, f(x))
	end
	return ys
end

function Postal.util.take(n, xs)
	ys = {}
	for i=1,n do
		if xs[i] then
			tinsert(ys, xs[i])
		end
	end
	return ys
end