local redis = require "resty.redis"
local resty_sha1 = require "resty.sha1"
local str = require "resty.string"
local shell = require "resty.lua-resty-shell.shell"

local remote_ip = ngx.var.remote_addr
local domain = ngx.var.host
local useragent = ngx.req.get_headers()['User-Agent']
if useragent == nil then
	useragent = "nilua"
end
local uri = ngx.var.request_uri
local auth = 0
local timestamp = 0
local question = 0
local answer = 0

local sha1 = resty_sha1:new()
local str_hash = sha1:update(remote_ip .. domain .. useragent)
local digest = sha1:final()
local usr_hash = str.to_hex(digest)

local math_random = math.random
local math_floor = math.floor
local string_gmatch = string.gmatch
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_char = string.char

local maxFailedChallengeAttempts = ngx.var.max_failed_challenge_attempts
local maxTimeWindowChallenges = ngx.var.max_time_window_challenges

local red = redis:new()
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
	ngx.header["Content-type"] = "text/html"
	ngx.say("failed to connect to redis, please reload to try again.")
	return
end

local shellSockArgs = { socket = "unix:/tmp/shell.sock" }

function GENINT()
	local randloop = math_random(10)
	local genplace
	local genanswer = 0
	local genstring = ""
	local tabbed = ""
	local spaced = ""
	for i = 0, randloop do
		genplace = 0;
		local genint = math_floor(math_random(15))
		genanswer = genanswer + genint
		while genplace ~= genint do
			genplace = genplace + 1
			if (math_random(9) > math_random(9)) then
				genstring = genstring .. "+(" .. GEN(1) .. ")"
			else 
				local randlooptab = math_floor(math_random(2))
				for i = 0, randlooptab do
					tabbed = tabbed .. "		"
				end	
				local randloopspace = math_floor(math_random(2))
				for i = 0, randloopspace do
					spaced = spaced .. "  "
				end	
				genstring = genstring .. "+(" .. GEN(1) .. ")" .. tabbed .. spaced
			end	
		end
	end
	return genstring, genanswer
end

function GEN(id)
	local gen = "";
	if id == 1 then
		local count = math_floor(math_random(2))
		local randcount = math_floor(math_random(count))
		for i = 1, count do
			local rand = math_floor(math_random(3))
			if (i == randcount) then
				if (rand == 1) then
					gen = gen .. "+(" .. math_random(99) + 55 .. " > " .. math_random(34) + 10 .. ")"
				end
				if (rand == 2) then
					gen = gen .. "+(" .. math_random(74) + 5 .. " < " .. math_random(44) + 85 .. ")"
				end
				if (rand == 3) then
					local randint = math_random(149) + 30
					gen = gen .. "+(" .. randint .. " == " .. randint .. ")"
				end
			else 
				if (rand == 1) then
					gen = gen .. "+(" .. math_random(34) + 15 .. " > " .. math_random(64) + 65 .. ")"
				end	
				if (rand == 2) then
					gen = gen .. "+(" .. math_random(74) + 55 .. " < " .. math_random(14) + 25 .. ")"
				end
				if (rand == 3) then
					gen = gen .. "+(" .. math_random(74) + 55 .. " == " .. math_random(14) + 24 .. ")"
				end
			end
		end
	else 
		local count = math_floor(math_random(9))
		for i = 0, count do
			local rand = math_floor(math_random(3))
			if (rand == 1) then 
				gen = gen .. "+(" .. math_random(34) + 15 .. " > " .. math_random(64) + 55 .. ")"
			end
			if (rand == 2) then 
				gen = gen .. "+(" .. math_random(74) + 45 .. " < " .. math_random(14) + 25 .. ")"
			end
			if (rand == 3) then 
				gen = gen .. "+(" .. math_floor(math_random(74) + 35) .. " == " .. math_floor(math_random(14) + 24) .. ")"
			end
		end
	end
	return gen
end

function genString(l)
	local s = ""
	for i = 1, l do
		s = s .. string_char(math_random(97, 122))
	end
	return s
end

function CHALLENGE() 
	
	if (string_find(useragent, "WordPress")) then
		shell.execute("ipset add siteshield-droplist " .. remote_ip, shellSockArgs)	
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(444)
		return
	end
	
	if (string_find(useragent, "Googlebot") or 
		string_find(useragent, "bingbot") or 
		string_find(useragent, "Yahoo") or 
		string_find(useragent, "DuckDuckBot")) then
		
		local getHostname = io.popen("dig -x " .. remote_ip .. " +short")
		local resolvedHostname = getHostname:read("*a")
		getHostname:close()
		
		local getIP = io.popen("getent hosts " .. resolvedHostname)
		local resolvedIP = getIP:read("*a")
		getIP:close()
		
		if (string_find(resolvedHostname, "google.com") or 
			string_find(resolvedHostname, "googlebot.com") or 
			string_find(resolvedHostname, "search.msn.com") or 
			string_find(resolvedHostname, "crawl.yahoo.net") or 
			string_find(resolvedHostname, "duckduckbot.duckduckgo.com")) then
			
			if (string_find(resolvedIP, remote_ip)) then
				
				red:hmset(usr_hash, "auth", 1, "timestamp", os.time() + 7200, "question", 0, "answer", 0, "hitcount", 0, "hitcounttimestamp", 0, "questionarg", 0, "answerarg", 0)
				red:persist(usr_hash)
				red:close()	
					
				ngx.header["Content-type"] = "text/html"
				ngx.exit(555)
				
				return
				
			end
			
		end
		
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(444)
		return
	
	end
	
	local res, err = red:hmget(usr_hash, "hitcount", "hitcounttimestamp")
	local hitcount = res[1]
	local timestamp = res[2]
	
	if tonumber(hitcount) == 0 then
		red:hmset(usr_hash, "hitcount", 1, "hitcounttimestamp", os.time())
	else
		red:hincrby(usr_hash, "hitcount", 1)
		if (tonumber(hitcount) >= tonumber(maxFailedChallengeAttempts)) then
			local diff = os.time() - timestamp
			if (tonumber(diff) <= tonumber(maxTimeWindowChallenges)) then
				shell.execute("ipset add siteshield-droplist " .. remote_ip, shellSockArgs)
				red:close()
				ngx.header["Content-type"] = "text/html"	
				ngx.exit(444)
				return
			end
			if (tonumber(diff) >= tonumber(maxTimeWindowChallenges)) then
				red:hmset(usr_hash, "hitcount", 0, "hitcounttimestamp", 0)
			end
		end
	end

	local jsvar = genString(math_random(15))
	local question = genString(math_random(30))
	local randloop = math_random(5)
	local buff = 0
	local answertotal = 0
	local jstotal = ""
	local jstype
	
	for i = 0, tonumber(randloop) do
		local js, jsanswer = GENINT()
		if (buff == 0) then
			jstotal = jstotal .. "var " .. jsvar .. " = " .. js .. ";"
			answertotal = jsanswer
			buff = buff + 1
		else 
			local randtype = math_floor(math_random(4))
			if (randtype == 1) then
				answertotal = answertotal + jsanswer
				jstype = "+"
			end
			if (randtype == 2) then
				answertotal = answertotal - jsanswer
				jstype = "-"
			end
			if (randtype == 3) then
				answertotal = answertotal * jsanswer
				jstype = "*"
			end
			if (randtype == 4) then
				answertotal = answertotal / jsanswer
				jstype = "/"
			end
			jstotal = jstotal .. jsvar .. jstype .. "= " .. js .. ";"
		end
	end
	
	if (string_find(answertotal, "0.")) then
		local forceRange = math_floor(math_random(51))
		jstotal = jstotal .. jsvar .. " += " .. forceRange .. ";"
		answertotal = answertotal + forceRange
	end
	
	local stringsub = math_floor(math_random(10))
	answertotal = string_sub(answertotal, 0, stringsub)
	local reloadtime = math_random(4) * 1000
	local expectedAuthenticationTime = math_random(2, 5) * 1000

	red:hmset(usr_hash, "question", question, "answer", answertotal, "eAT", expectedAuthenticationTime, "eATTime", os.time())
	red:close()
	
	local func_name = genString(math_random(32))	
	local response = "<html><head><title>DDoS Protection by SiteShield</title><link href='https://fonts.googleapis.com/css?family=Teko:400,700' rel='stylesheet'><style>body{font-family:'Teko';padding-top:5%;background-color:#fdfdfe}.m{padding:50px;border:3px solid #4062BB;border-radius:20px;width:25%;margin:0 auto;text-align:center;box-shadow:5px 5px 5px 5px #F2F2F2}.f{text-align:center;text-transform:uppercase}.f a{color:#4062BB}</style><script>setTimeout(function " .. func_name .. "() {\r\n" .. jstotal .. "\r\nvar xmlhttp;\r\nif (window.XMLHttpRequest) {\r\nxmlhttp = new XMLHttpRequest();\r\n} else {\r\nxmlhttp = new ActiveXObject('Microsoft.XMLHTTP');\r\n}\r\nxmlhttp.onreadystatechange = function () {\r\nif (xmlhttp.readyState == 4 && xmlhttp.status == 200) {\r\nif (xmlhttp.responseText.indexOf('success') >= 0) {\r\nsetTimeout(function() {\r\nwindow.location.reload();\r\n}, 500);\r\n} else {\r\nalert(xmlhttp.responseText);\r\n}\r\n}\r\n}\r\nxmlhttp.open('GET', '/SiteShield/Authenticate?q=" .. question .. "&a=' + " .. jsvar .. ".toString().substring(0, " .. stringsub .. "), true);\r\nxmlhttp.send();\r\n}, " .. expectedAuthenticationTime .. ");\r\n</script></head><body><div class='m'><svg version='1.0' xmlns='http://www.w3.org/2000/svg' width='100%' height='25%' viewBox='0 0 456.000000 465.000000' preserveAspectRatio='xMidYMid meet'><style type='text/css'>@keyframes colorChange{0%{fill:#4062BB;}100%{fill:#414042;}}.st0{fill:#4062BB}.st1{fill:#414042;animation:colorChange 0.77s infinite}</style><g transform='translate(0.000000,465.000000) scale(0.100000,-0.100000)' fill='#000000' stroke='none'><path class='st1' d='M1940 4273 c-456 -44 -798 -125 -1170 -275 -234 -95 -416 -193 -599 -322 -63 -45 -118 -84 -123 -87 -9 -6 87 -354 158 -573 251 -771 656 -1524 1119 -2081 189 -228 436 -475 625 -626 66 -52 324 -229 335 -229 13 0 305 231 419 331 690 607 1288 1565 1641 2634 87 262 171 595 153 607 -42 28 -533 264 -640 307 -405 163 -827 267 -1237 306 -138 13 -576 19 -681 8z m768 -217 c510 -69 958 -209 1431 -446 l139 -69 -14 -63 c-58 -248 -194 -639 -344 -983 -315 -723 -793 -1425 -1270 -1863 -126 -116 -355 -302 -371 -302 -6 0 -38 19 -72 42 -244 163 -568 484 -832 823 -120 153 -336 480 -445 670 -266 466 -483 997 -639 1563 l-20 73 75 52 c373 260 962 455 1555 517 131 13 675 4 807 -14z'/><path class='st0' d='M2110 3924 c-481 -26 -919 -124 -1304 -293 -177 -77 -356 -179 -356 -201 0 -26 74 -280 120 -415 89 -257 248 -621 382 -875 84 -158 197 -358 206 -364 4 -2 80 102 169 231 l162 235 -28 42 c-103 151 -402 792 -387 831 7 19 115 77 240 130 132 55 362 129 379 122 6 -3 59 -109 117 -236 58 -127 108 -231 111 -231 3 0 157 227 342 504 268 403 333 506 319 510 -23 6 -390 14 -472 10z'/><path class='st0' d='M2808 3728 c-51 -78 -238 -365 -415 -637 l-321 -494 64 -103 c150 -243 340 -518 486 -702 l90 -112 -32 -38 c-18 -20 -118 -123 -221 -229 l-188 -191 -54 61 c-131 151 -374 461 -510 650 l-55 78 -60 -83 c-150 -210 -272 -388 -272 -397 0 -14 161 -228 276 -366 128 -153 286 -322 394 -423 89 -83 270 -232 280 -232 16 0 218 177 349 305 212 207 386 408 548 635 69 96 173 260 173 272 0 4 -35 47 -79 95 -283 317 -651 798 -651 852 0 10 415 627 441 655 17 19 381 -114 423 -154 6 -6 4 -26 -3 -52 -31 -103 -181 -465 -247 -596 l-72 -142 166 -204 167 -204 33 56 c132 229 351 703 447 967 61 170 139 441 131 460 -11 30 -397 195 -641 275 -130 42 -433 122 -512 135 l-42 7 -93 -144z'/></g></svg><h3 class='ar'>Authenticating Request<span id='wait'>.</span></h3></div><div class='f'><h3>DDoS Protection by <b><a href='https://github.com/dbContext/SiteShield-OpenResty' target='_blank'>Site Shield</a></b></h3></div><script>;setInterval(function(){var e=document.getElementById('wait');if(e.innerHTML.length==3){e.innerHTML=''}else{e.innerHTML+='.'}},1000);</script></body></html>"
	
	ngx.header["Content-type"] = "text/html"
	ngx.say(response)
	return
	
end

function AUTH() 
	if (string_find(useragent, "WordPress")) then
		shell.execute("ipset add siteshield-droplist " .. remote_ip, shellSockArgs)
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(444)
		return
	end
	
	local res, err = red:hmget(usr_hash, "hitcount", "hitcounttimestamp")
	local hitcount = res[1]
	local timestamp = res[2]
	
	if tonumber(hitcount) == 0 then
		red:hmset(usr_hash, "hitcount", 1, "hitcounttimestamp", os.time())
	else
		red:hincrby(usr_hash, "hitcount", 1)
		if (tonumber(hitcount) >= tonumber(maxFailedChallengeAttempts)) then
			local diff = os.time() - timestamp
			if (tonumber(diff) <= tonumber(maxTimeWindowChallenges)) then
				shell.execute("ipset add siteshield-droplist " .. remote_ip, shellSockArgs)
				red:close()
				ngx.header["Content-type"] = "text/html"	
				ngx.exit(444)
				return
			end
			if (tonumber(diff) >= tonumber(maxTimeWindowChallenges)) then
				red:hmset(usr_hash, "hitcount", 0, "hitcounttimestamp", 0)
			end
		end
	end
	
	local res, err = red:hmget(usr_hash, "question", "answer", "eAT", "eATTime")
	local correctQuestion = ""
	local correctAnswer = ""
	local eAT = "";
	local eATTime = "";
	
	if res then 
		correctQuestion = res[1]
		correctAnswer = res[2]
		eAT = tonumber(res[3])
		eATTime = res[4]
	end
	
	local expectedDiff = tonumber((os.time() - eATTime) * 1000)
	local eATSec = tonumber(eAT + 1000)
	if (expectedDiff < eAT or expectedDiff > eATSec) then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.say("Authentication failed, please reload.")
		return
	end
	
	local get_args = ngx.req.get_uri_args(2)
	local getQuestion = ""
	local getAnswer = ""
	
	for key, val in pairs(get_args) do
		if (key == "q") then
			getQuestion = val
		end
		if (key == "a") then
			getAnswer = val
		end
	end

	if (getQuestion == "" or 
		getAnswer == "" or 
		getQuestion ~= correctQuestion or 
		getAnswer ~= correctAnswer) then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.say("Authentication failed, please reload.")
		return
	end

	local authenticationTime = tonumber(ngx.var.auth_time)
	
	red:hmset(usr_hash, "auth", 1, "timestamp", os.time() + authenticationTime, "question", 0, "answer", 0, "hitcount", 0, "hitcounttimestamp", 0, "questionarg", 0, "answerarg", 0)
	red:persist(usr_hash)
	red:close()

	ngx.header["Content-type"] = "text/html"
	ngx.say("success")
	return	
end

local allowIPs = ngx.var.allow_ip

for IP in string_gmatch(allowIPs, '([^;]+)') do
	if (remote_ip == IP) then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(555)
		return
	end
end

local blockIPs = ngx.var.block_ip

for IP in string_gmatch(blockIPs, '([^;]+)') do
	if (remote_ip == IP) then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(403)
		return
	end
end

local allowURIs = ngx.var.allow_uri

for get_uri in string_gmatch(allowURIs, '([^;]+)') do
	if (get_uri == uri) then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(555)
		return
	end
end

local blockURIs = ngx.var.block_uri

for get_uri in string_gmatch(blockURIs, '([^;]+)') do
	if (get_uri == uri) then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(403)
		return
	end
end

local res, err = red:get(usr_hash)

if (res == ngx.null) then
	red:hmset(usr_hash, "auth", 0, "timestamp", 0, "question", 0, "answer", 0, "hitcount", 0, "hitcounttimestamp", 0)
	red:expire(usr_hash, 300)
	auth = 0
	timestamp = 0
	question = 0
	answer = 0
	CHALLENGE()	
	return
end

if (res ~= ngx.null) then 
	local res, err = red:hmget(usr_hash, "auth", "timestamp")
	if res then 
		auth = res[1]
		timestamp = res[2]
	end
end 

if (tonumber(auth) == 1) then 
	if (tonumber(timestamp) < os.time()) then 
		red:hmset(usr_hash, "auth", 0, "timestamp", 0, "question", 0, "answer", 0, "hitcount", 0, "hitcounttimestamp", 0)
		CHALLENGE()
		return
	end
	red:close()	
	ngx.header["Content-type"] = "text/html"
	ngx.exit(555)
	return
end

if (tonumber(auth) == 0) then	
	if (string_find(uri, "/SiteShield/Authenticate")) then
		AUTH()
		return
	end
	if (uri == "/favicon.ico") then
		red:close()
		ngx.header["Content-type"] = "text/html"
		ngx.exit(503)
		return
	end
	CHALLENGE()
	return
end
