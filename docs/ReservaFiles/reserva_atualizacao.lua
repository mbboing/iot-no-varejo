wificonfig = require "reserva_wifi_config";
local updatemanager = {};

local versao_local, versao_atual;
local arquivos = {};
local qnt_arquivos_baixados = 0;
local wget_retries = 0;
local wgetTimeout = tmr.create();

--Funcao que retorna verdadeiro se a data 1 for posterior a data 2
local function compara_datas(data1, data2)
	local ano1, mes1, dia1, hora1, min1 = string.match(data1,'(%d+):(%d+):(%d+):(%d+):(%d+)');
	local ano2, mes2, dia2, hora2, min2 = string.match(data2,'(%d+):(%d+):(%d+):(%d+):(%d+)');

	local data_numerica_1 = tonumber(min1) + 60*( tonumber(hora1) + 24*( tonumber(dia1) + 31*( tonumber(mes1) + 12*( tonumber(ano1) - 2017))))
	local data_numerica_2 = tonumber(min2) + 60*( tonumber(hora2) + 24*( tonumber(dia2) + 31*( tonumber(mes2) + 12*( tonumber(ano2) - 2017))))

    return (data_numerica_1 > data_numerica_2);
end

--Funcao que cancela o processo de atualizacao dos arquivos
local function cancel_update()
    --Remove os arquivos temporarios
    for file_name,_ in pairs(file.list()) do
        if string.find(file_name,"_temp.") then
            file.remove(file_name);
        end
    end
    print("Cancel update");
    reset();
end

--Funcao que baixa um arquivo de um endereco dado
local function wget(endereco, arquivo, saida, callback, porta)
    porta = porta or 80;
	local primeira_barra = string.find(endereco,'/');
	local caminho = string.sub(endereco, primeira_barra) .. arquivo;
	endereco = string.sub(endereco, 0, primeira_barra - 1);
	local file_content = {}
	local file_size = 0;
    local total_size = 0;
    local is_first_package = true;
	local receiving_flag = false;
   
    print(endereco, caminho, arquivo, saida, porta);
	wgetTimeout:alarm(5000, tmr.ALARM_SINGLE, function()
		receiving_flag = false;
		s:close();
        file_content = nil;
		callback(0);
	end);
    s=net.createConnection(net.TCP, 0);
    s:on("receive", function(sck, c)
        sck:hold();
		if receiving_flag == true then
		    if(is_first_package) then
		        --Pegando tamanho do arquivo
		        if string.match(c,"Length: %d+") ~= nil then
					total_size = tonumber(string.sub(string.match(c,'Length: %d+'),9));
		        end
		        --Cortando o cabecalho 
		        local beginning = string.find(c,"\r\n\r\n");
		        if beginning ~= nil then
		            --print(string.sub(c,0,beginning));
		            c = string.sub(c,beginning+4);
		            is_first_package = false;
		        end;
		    end;
		    
			table.insert(file_content, c);
		    
		    file_size = file_size + string.len(c);
		    print("Tamanho lido: ", file_size .. '/' .. total_size);
		    if file_size >= total_size then
				wgetTimeout:stop()
				--Cria o arquivo com o conteudo lido
				file.open(saida, "w");
				for _,i in pairs(file_content) do
					file.write(i);
				end
		        file.close();
                s:close();
                file_content = nil;
		        callback(total_size);
		    end
		end
        sck:unhold();
    end )
    s:on("disconnection", function() 
		print("Disconnected");
		receiving_flag = false;
		callback(0);
	end)
	s:on("connection", function()
		print("Conectou\n")
		receiving_flag = true;
		s:send("GET "..caminho.." HTTP/1.1\r\n"..
		       "Host: "..endereco.."\r\n"..
		       "Connection: keep-alive\r\n"..
		       "User-Agent: uPNP/1.0\r\n"..
		       "Accept-Charset: utf-8\r\n"..
		       "Accept: */*\r\n\r\n"
		      )
	end)
	print("Registrou callbacks\n");
	print("Port:",porta);
    s:connect(porta, endereco);
	print("Inicio\n");
end

--Funcao que gerencia qual deve ser o proximo arquivo a ser baixado
local function update_next_file(last_file_size)

    if last_file_size >= versao_atual[arquivos[qnt_arquivos_baixados + 1]] then
		qnt_arquivos_baixados = qnt_arquivos_baixados + 1;
		wget_retries = 0;
		if qnt_arquivos_baixados < #arquivos then

			local file_name = arquivos[qnt_arquivos_baixados+1];
			wget(config.update_addr, file_name, string.gsub(file_name,".lua","_temp.lua"), update_next_file);

		else
			--Remove os arquivos antigos, menos o de configuracao de wifi
			for file_name,_ in pairs(file.list()) do
     			if string.find(file_name,"_temp.") == nil and file_name ~= "reserva_wifi_config.lua" and file_name ~= "init.lua" then
          			file.remove(file_name)
     			end
			end
			--Renomeia os arquivos temporarios
			for file_name,_ in pairs(file.list()) do
     			if string.find(file_name,"_temp.") then
          			file.rename(file_name,string.gsub(file_name,"_temp",""))
     			end
			end

			-- Reset the system	
   			log("Files updated.");
    		reset();
		end
	else
		wget_retries = wget_retries + 1;
		if wget_retries < 5 then
			local file_name = arquivos[qnt_arquivos_baixados+1];
			wget(config.update_addr, file_name, string.gsub(file_name,".lua","_temp.lua"), update_next_file);
		else
			cancel_update();
		end;
	end

end

--Funcao que compara os arquivos de versao e verifica se deve ser feita uma atualizacao
local function check_version(file_size)
	if file_size ~= 0 then
		versao_local = dofile("versao.lua");
		versao_atual = dofile("versao_temp.lua");

		print("Checando versoes");
		if compara_datas(versao_atual.data, versao_local.data) then
		    print("Versao desatualizada");
			-- Fazer a atualizacao dos arquivos
			for k,_ in pairs(versao_atual) do
				if k ~= "data" then
					table.insert(arquivos, k);
				end
			end
			local file_name = arquivos[qnt_arquivos_baixados+1];
			wget(config.update_addr, file_name, string.gsub(file_name,"%.","_temp."), update_next_file);

		else
		    print("Versão atual");
		    cancel_update();
		end
	else
		cancel_update();
	end
end

--Funcao que inicia o processo de atualizacao dos arquivos
function updatemanager.update(updatefiles_cb)
    station_cfg={};
    station_cfg.ssid=wificonfig.ssid;
    station_cfg.pwd=wificonfig.pwd;
    wifi.mode(wifi.STATION);
    wifi.start();
    wifi.sta.config(station_cfg);
    wifi.sta.on("got_ip", function(ev, info)
        print("WiFi Connected\n");
        wget(config.update_addr, "versao.lua", "versao_temp.lua", check_version);
    end);
end

--Funcao que cria o arquivo de flag para a atualizacao
function updatemanager.setup_update()
    print("Antes de criar o arquivo de flag");
    bleEnable(0, function()
        file.open("update_flag_file.txt",'w');
        print("Depois de criar o arquivo de flag");
        file.close();
        reset();
    end);
end

return updatemanager;
