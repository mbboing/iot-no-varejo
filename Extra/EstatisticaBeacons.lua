local beacons = {}
local janelas_de_tempo = {}
local tempo_inicial = {}
local tempo_final = {}

--local files = {"20170704_240ac407169c.txt","20170705_240ac407169c.txt","20170706_240ac407169c.txt"}
local files = {"20170704_240ac4803844.txt","20170705_240ac4803844.txt","20170705_240ac4803844.txt"}
for _,file_name in pairs(files) do
	file = io.open(file_name, "r")
	if file then
		local line = file:read()
		while line ~= nil do
			if line:byte() ~= 35 then
				--print(line)
				local line_numbers = {}
				for number in string.gmatch(line, "%d") do table.insert(line_numbers,number) end
				local dia = line_numbers[7]*10 + line_numbers[8]
				local hora = line_numbers[9]*10 + line_numbers[10]
				local minuto = line_numbers[11]*10 + line_numbers[12]
				local segundo = line_numbers[13]*10 + line_numbers[14]
				local beaconId = line_numbers[18]*10 + line_numbers[19]
				local total_de_segundos = ((dia*24 + hora)*60 + minuto)*60 + segundo
				--print(dia,hora,minuto,segundo,beaconId, total_de_segundos)
				if beacons[beaconId] == nil then
					beacons[beaconId] = {}
				end
				table.insert(beacons[beaconId], total_de_segundos)
			end
			line = file:read()
		end
		file:close()
	end
end

for i,v in pairs(beacons) do
	table.sort(v)
	local tempo_anterior = v[1]
	tempo_inicial[i] = v[1]
	tempo_final[i] = 0
	janelas_de_tempo[i] = {}
	for _,j in pairs(v) do
		if j < tempo_inicial[i] then tempo_inicial[i] = j end
		if j > tempo_final[i] then tempo_final[i] = j end

		local janela = j - tempo_anterior
		tempo_anterior = j
		if janelas_de_tempo[i][janela] == nil then
			janelas_de_tempo[i][janela] = 1
		else
			janelas_de_tempo[i][janela] = janelas_de_tempo[i][janela] + 1
		end
		--print(i, j, janela)
	end
end

--file = io.open("Total_240ac407169c.txt", "w")
file = io.open("Total_240ac4803844.txt", "a+")
if file then
	for beacon,v in pairs(janelas_de_tempo) do
		print("Beacon:",beacon)
		file:write("Beacon:" .. beacon .. '\n')
		local total_de_beacons = 0
		for janela,qnt in pairs(v) do
			local porcentagem = 100*qnt/(tempo_final[beacon] - tempo_inicial[beacon])
			total_de_beacons = total_de_beacons + qnt
			print(janela,qnt,porcentagem)
			file:write(janela ..'\t'.. qnt ..'\t'.. porcentagem ..'\n')
		end
		local porcentagem = 100*total_de_beacons/(tempo_final[beacon] - tempo_inicial[beacon])
		print("Total:", total_de_beacons, porcentagem)
		file:write("Total:" .. '\t' .. total_de_beacons .. '\t' .. porcentagem ..'\n')
	end
	file:close()
end

