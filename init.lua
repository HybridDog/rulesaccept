--http://minetest.web1337.net/rules.php <rules of zegaton
local rules = {
	"Do not grief!",
	"Do not flood the map with water or lava!",
	"Do not make death holes (holes so deep that players falling in can be hurt or dead)!",
	"Do not insult others!",
	"Do not edit other's signs (including rules signs!).",
	"Do not ask if you can become admin or mod.",
	"Do not ask for privileges.",
	"Do not advertise for other servers on our server!",
	"Respect other users and the mods/admins!",
}
local read_delay = 5

local cnt, corners, fx, fy, text_to_labels, get_formspec, rules_form, plist, waiters, font_size, stuff_defined, disallowed_players, table_contains, save_players
local function define_stuff()

	function table_contains(t, v)
		for _,i in pairs(t) do
			if i == v then
				return true
			end
		end
		return false
	end

	disallowed_players = {}
	local file = io.open(minetest.get_worldpath().."/rulesaccept", "r")
	if file then
		local contents = file:read("*all")
		io.close(file)
		if contents then
			disallowed_players = string.split(contents, " ")
		end
	end

	function save_players()
		local output = ""
		for _,name in ipairs(disallowed_players) do
			output = output..name.." "
		end
		local f = io.open(minetest.get_worldpath().."/rulesaccept", "w")
		f:write(output)
		io.close(f)
	end

	if minetest.is_singleplayer() then
		font_size = tonumber(minetest.setting_get("font_size")) or 13
	else
		font_size = 13
	end

	cnt = #rules
	corners = {x=0.1, y=-0.2}
	fx = 15*font_size
	fy = font_size/65

	function text_to_labels(text, x, y)
		local tab = minetest.splittext(text, fx)
		local l = 0
		text = ""
		for _,str in ipairs(tab) do
			text = text.."label["..0 ..","..y..";"..str.."]"
			y = y+fy
			l = math.max(l, #str)
		end
		x = math.max(x, l/font_size)
		return text, x, y
	end

	function get_formspec(num, cont)
		local rule = rules[num]
		local y = corners.y
		local x = corners.x

		local text, x, y = text_to_labels(rule, x, y)
		x = x+corners.x
		x = math.max(x, 2)
		y = y+1

		local spec = "size["..x..","..y.."]"..
			text..
			"button_exit[0,"..y-0.5 ..";1,1;exit;exit]"
		if cont then
			spec = spec.."button["..x-1 ..","..y-0.5 ..";1,1;accept;accept]"
		end
		return spec
	end

	rules_form = ""
	for _,rule in ipairs(rules) do
		rules_form = rules_form..rule.."\n\n"
	end
	rules_form = string.sub(rules_form, 1, -3)
	local y = corners.y
	local x = corners.x

	local text, x, y = text_to_labels(rules_form, x, y)
	x = x+corners.x
	x = math.max(x, 2)
	y = y+1

	rules_form = "size["..x..","..y.."]"..
		text..
		"button_exit["..x/2-1 ..","..y-0.5 ..";2,1;exit;exit]"

	plist = {}
	waiters = {}
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "rule"
	or not player then
		return
	end

	if not stuff_defined then
		define_stuff()
		stuff_defined = true
	end

	local pname = player:get_player_name()
	if fields.accept then
		local num = plist[pname] or 2
		if pname then
			if num == cnt then
				local privs = minetest.get_player_privs(pname)
				if privs.interact then
					minetest.chat_send_player(pname, "You already have interact.")
					return
				end
				privs.interact = true
				minetest.set_player_privs(pname, privs)
				table.insert(disallowed_players, pname)
				save_players()
				minetest.chat_send_player(pname, "Interact granted!")
			else
				num = num+1
				waiters[pname] = true
				minetest.show_formspec(pname, "rule", get_formspec(num))
				minetest.after(read_delay, function(pname, num)
					if waiters[pname] then
						plist[pname] = num
						minetest.show_formspec(pname, "rule", get_formspec(num, true))
					end
					waiters[pname] = nil
				end, pname, num)
			end
		end
	else
		waiters[pname] = nil
	end
end)

minetest.register_chatcommand("show_rules", {
	description = "show the rules",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end
		local privs = minetest.get_player_privs(name)
		if not privs.shout then
			return true, "This command requires the shout privilege."
		end

		if not stuff_defined then
			define_stuff()
			stuff_defined = true
		end

		if privs.interact
		or table_contains(disallowed_players, name) then
			minetest.show_formspec(name, "rule", rules_form)
			return true, "Showing rules..."
		end
		if waiters[pname] then
			return false, "Command used too often"
		end
		plist[name] = plist[name] or 1
		local num = plist[name]
		minetest.show_formspec(name, "rule", get_formspec(num, true))
		return true, "Showing rules...."
	end,
})

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not minetest.get_player_privs(name).interact then
		minetest.chat_send_player(name, "Welcome, "..name..", write /show_rules into the chat and accept these rules if you want to get interact.")
	end
end)
