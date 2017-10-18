-- tentativa de fazer um wget. Funciona para pequenos arquivios,tentar corrigir para qualquer tamanho

wget = function(endereco,caminho,saida,porta)
    porta = porta or 80
    saida = saida or "output-wget"
    print("salvando "..endereco..":"..porta..caminho.." em "..saida.."!")
    file.open(saida, "w")
	print("Abriu Arquivo\n");
    s=net.createConnection(net.TCP, 0)
    s:on("receive", function(sck, c) file.write(c) file.flush() print("Criou arquivo") end )
    s:on("disconnection", function(c) c = nil; file.close() end)
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
    s:connect(porta, endereco)
	print("Inicio\n")
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
	--wget("151.101.92.133", "/paoloo/nodeMCU-sh/master/wget.lua", "output.txt", 443);
	wget("raw.githubusercontent.com", "/afbranco/Terra/master/README.md", "output.txt", 443);
	--wget("testbed.inf.puc-rio.br","/index.lua", "output.txt", 443);
end);
