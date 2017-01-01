package.path = package.path .. ";../?.lua"
local test = require('gambiarra')

local tests_passed = 0
local tests_failed = 0
require('gambiarra')(function(e, test, msg)
	if e == 'pass' then
		print("[32m✔[0m "..test..': '..msg)
		tests_passed = tests_passed + 1
	elseif e == 'fail' then
		print("[31m✘[0m "..test..': '..msg)
		tests_failed = tests_failed + 1
	elseif e == 'except' then
		print("[31m✘[0m "..test..': '..msg)
		tests_failed = tests_failed + 1
	end
end)

local sh = require('sh')

test('Check command output', function()
	ok(tostring(seq(1, 5)) == '1\n2\n3\n4\n5', 'seq 1 5')
end)

test('Check command input', function()
	local r = grep('a.*b', {
		__input = 'arc\narabic\nabbey\n'
	})
	ok(tostring(r) == 'arabic\nabbey', 'grep a.*b')
end)

test('Check command pipeline', function()
	local r = wc(seq(1, 10), '-l')
	ok(tonumber(tostring(r)) == 10, 'seq 1 10 | wc -l')

	local r = seq(1, 10) : wc('-l')
	ok(tonumber(tostring(r)) == 10, 'seq 1 10 | wc -l')

	local r = wc(seq(1, 10), seq(20, 25), '-l')
	ok(tonumber(tostring(r)) == 16, '(seq 1 10 ; seq 20 25) | wc -l')
end)

test('Check command structure', function()
	local r = seq(1, 3)
	ok(r.__input == '1\n2\n3\n', 'seq 1 3: output')
	if _VERSION ~= 'Lua 5.1' then
		ok(r.__signal == 0, 'seq 1 3: signal')
		ok(r.__exitcode == 0, 'seq 1 3: exit code')
		local r = sh.command('false')()
		ok(r.__exitcode ~= 0, 'false: exit code')
		local r = sh.command('true')()
		ok(r.__exitcode == 0, 'true: exit code')
		local r = ls('/missing')
		ok(r.__exitcode == 2, 'ls /missing: exit code')
	end
end)

test('Check command with predefined args', function()
	local seq10 = sh.command('seq', 10)
	ok(tostring(seq10(12)) == '10\n11\n12', 'seq 10 12')
	ok(tostring(seq10(15)) == '10\n11\n12\n13\n14\n15', 'seq 10 15')
	ok(tostring(seq10('-1', 8)) == '10\n9\n8', 'seq 10 9 8')
end)

test('Check sh called as function', function()
	local seq10 = sh('seq', 10)
	ok(type(seq10) == 'function', 'sh() returns a command function')
	ok(tostring(seq10(12)) == '10\n11\n12', 'seq 10 12')
end)

test('Check command with table args', function()
	local r = stat('/bin', {format='%a %n'})
	ok(tostring(r) == '755 /bin', 'stat --format "%a %n" /bin')
end)

if tests_failed > 0 then os.exit(1) end

