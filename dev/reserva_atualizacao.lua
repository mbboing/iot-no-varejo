local updatemanager = {};

local versao_local, versao_atual;
local arquivos = {};
local qnt_arquivos_baixados = 0;
local wget_retries = 0;
local wgetTimeout = tmr.create();

local function update_files_done() print("Sem callback da atualizacao de arquivos") end;

local function compara_datas(data1, data2)
	local ano1, mes1, dia1, hora1, min1 = string.match(data1,'(%d+):(%d+):(%d+):(%d+):(%d+)');
	local ano2, mes2, dia2, hora2, min2 = string.match(data2,'(%d+):(%d+):(%d+):(%d+):(%d+)');

	local data_numerica_1 = tonumber(min1) + 60*( tonumber(hora1) + 24*( tonumber(dia1) + 31*( tonumber(mes1) + 12*( tonumber(ano1) - 2017))))
	local data_numerica_2 = tonumber(min2) + 60*( tonumber(hora2) + 24*( tonumber(dia2) + 31*( tonumber(mes2) + 12*( tonumber(ano2) - 2017))))

    print(data_numerica_1);
    print(data_numerica_2);

	return (data_numerica_1 > data_numerica_2);
end

local function cancel_update()
    --Remove os arquivos temporarios
    for file_name,_ in pairs(file.list()) do
        if string.find(file_name,"_temp.") then
            file.remove(file_name);
        end
    end
    bleEnable(1, update_files_done);
    print("Cancel update");
end

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
		callback(0);
	end);
    s=net.createConnection(net.TCP, 0);
    s:on("receive", function(sck, c)
		if receiving_flag == true then
		    if(is_first_package) then
		        --Pegando tamanho do arquivo
		        if string.match(c,"Length: %d+") ~= nil then
					total_size = tonumber(string.sub(string.match(c,'Length: %d+'),9));
		        end
		        --Cortando o cabecalho 
		        local beginning = string.find(c,"\r\n\r\n");
		        if beginning ~= nil then
		            print(beginning);
		            c = string.sub(c,beginning+4);
		            is_first_package = false;
		        end;
		    end;
		    
			table.insert(file_content, c);
		    
		    file_size = file_size + string.len(c);
		    print("Tamanho lido: ", file_size .. '/' .. total_size);
			if file_size > 5000 then
				--Escreve no arquivo o conteudo lido
                --REMOVER ESSA PARTE QUANDO RESOLVER O WGET DO RESERVA_REDE
				file.open(saida, "w");
				for k,i in pairs(file_content) do
					file.write(i);
					table.remove(file_content, k);
				end
		        file.close();
		    end
		    if file_size >= total_size then
				wgetTimeout:stop()
				--Cria o arquivo com o conteudo lido
				file.open(saida, "w");
				for _,i in pairs(file_content) do
					file.write(i);
				end
		        file.close();
		        callback(total_size);
		    end
		end
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

local function update_next_file(last_file_size)

    print("Tamanho baixado: ", last_file_size);
    print("Tamanho correto: ", versao_atual[arquivos[qnt_arquivos_baixados + 1]]);
    
	if last_file_size >= versao_atual[arquivos[qnt_arquivos_baixados + 1]] then
		qnt_arquivos_baixados = qnt_arquivos_baixados + 1;
		wget_retries = 0;
		if qnt_arquivos_baixados < #arquivos then

			local file_name = arquivos[qnt_arquivos_baixados+1];
			wget("mbboing.github.io/iot-no-varejo/", file_name, string.gsub(file_name,".lua","_temp.lua"), update_next_file);

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
			wget("mbboing.github.io/iot-no-varejo/", file_name, string.gsub(file_name,".lua","_temp.lua"), update_next_file);
		else
			cancel_update();
		end;
	end

end

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
			wget("mbboing.github.io/iot-no-varejo/", file_name, string.gsub(file_name,"%.","_temp."), update_next_file);
		else
		    print("Versão atual");
		    cancel_update();
		end
	else
		cancel_update();
	end
end

function updatemanager.update(updatefiles_cb)
    if type(updatefiles_cb)=="function" then
        print("Parametro eh uma funcao");
        update_files_done = updatefiles_cb;
    end
	bleEnable(0, function(err)
		print("Desligou o bluetooth");
        wget("mbboing.github.io/iot-no-varejo/", "versao.lua", "versao_temp.lua", check_version);
    end);
end

--https://raw.githubusercontent.com/paoloo/nodeMCU-sh/master/wget.lua

--station_cfg={};
--station_cfg.ssid="terra_iot";
--station_cfg.pwd="projeto_iot";
--wifi.mode(wifi.STATION);
--wifi.start();
--wifi.sta.config(station_cfg);
--wifi.sta.on("got_ip", function(ev, info)
--    print("WiFi Connected\n");
--    wget("mbboing.github.io/iot-no-varejo/", "versao.lua", "versao_temp.lua");
--end);

return updatemanager;
