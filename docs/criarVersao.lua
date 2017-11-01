-- Lua implementation of PHP scandir function
function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls -a "'..directory..'"')
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end

-- Get a file size
function fsize (file)
  local current = file:seek()      -- get current position
  local size = file:seek("end")    -- get file size
  file:seek("set", current)        -- restore position
  return size
end

local files = {}

for _,i in pairs(scandir(".")) do
	if i ~= "." and i ~= ".." and i ~= "criarVersao.lua" and i ~= "index.html" and i ~= "_config.yml" and i ~= "versao.lua" then
		f = io.open(i)
		print(i, fsize(f))
		files[i] = fsize(f)
		f:close()
	end
end


output = io.open("versao.lua","w")
output:write("local versao = {\n\n--[\"data\"] = \"AAAA:MM:DD:HH:mm\"\n")
output:write(os.date("[\"data\"] = \"%Y:%m:%d:%H:%M\",\n\n"))
output:write("--[\"nome_do_arquivo\"] = tamanho do arquido em bytes\n")

for k,i in pairs(files) do
	output:write("[\""..k.."\"] = "..i..",\n")
end

output:write("\n}\n\nreturn versao;")
output:close()
