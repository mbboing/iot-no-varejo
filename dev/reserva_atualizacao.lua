local updatemanager = {};


local function wget(endereco,arquivo,porta)
    porta = porta or 80;
	local primeira_barra = string.find(endereco,'/');
	local caminho = string.sub(endereco, primeira_barra) .. arquivo;
	endereco = string.sub(endereco, 0, primeira_barra - 1);
    local is_first_package = true;
    print(endereco, caminho, arquivo, porta);
    file.open(arquivo, "w");
	print("Abriu Arquivo\n");
    s=net.createConnection(net.TCP, 0);
    s:on("receive", function(sck, c)
        --Cortando o cabecalho 
        --PEGAR O TAMANHO DO TEXTO NO HTTP E CHAMAR CALLBACK QUANDO ACABAR
        if(is_first_package) then
            local beginning = string.find(c,"\r\n\r\n");
            if beginning ~= nil then
                print(beginning);
                c = string.sub(c,beginning+4);
                is_first_package = false;
            end;
        end;
        file.write(c);
        file.flush();
        print("Criou arquivo");
        end )
    s:on("disconnection", function() file.close(); print("Fechou arquivo"); end)
	s:on("connection", function()
		print("Conectou\n")
		s:send("GET "..caminho.." HTTPS/1.1\r\n"..
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

function updatemanager.update()
	bleEnable(0, function(err)
        wget("mbboing.github.io/iot-no-varejo/", "test.txt");
		--bleEnable(1, files_sent);
    end);
end

--https://raw.githubusercontent.com/paoloo/nodeMCU-sh/master/wget.lua

station_cfg={};
station_cfg.ssid="terra_iot";
station_cfg.pwd="projeto_iot";
wifi.mode(wifi.STATION);
wifi.start();
wifi.sta.config(station_cfg);
wifi.sta.on("got_ip", function(ev, info)
    print("WiFi Connected\n");
    wget("mbboing.github.io/iot-no-varejo/", "test.txt");
end);

--return updatemanager;
