
local bletimer = tmr.create();
local blecounter = 0;

bleEnable = function(flag,cb)bthci.scan.enable(flag,cb); end;

beacons = require "reserva_beacons";
netmanager = require "reserva_rede";
updatemanager = require "reserva_atualizacao";
config = require "reserva_config";

local mainTimer = tmr.create();
local updateTimer = tmr.create();
local bluetooth_period = config.bluetooth_period;
local upload_period = config.upload_period;
local bluetooh_period_counter = -1;
local firstInit = false;
local firstMinute = true;
local update_time = false;
local initHeap = node.heap();
local lastHeap = initHeap;
log_list = {};

--Funcao que insere uma mensagem na tabela de logs a serem enviados
function log(string)
	if #log_list < 100 then
    	table.insert(log_list,node.date("%Y-%m-%d %H:%M:%S.000\t"..string));
	end
end

--Funcao para resetar o sistema, mas salvando antes os logs em um arquivo
function reset()
	bleEnable(0, function(err)
    	-- Salva arqivo de logs:
		if #log_list > 0 then
			local log_file_name = node.date("Data_Log_%Y_%m_%d_%H_%M.txt");
			fstat, ferrmsg = file.open(log_file_name,"w");
			if fstat then
				  for k,v in ipairs(log_list) do
				    file.write(v);
				  end
				log_list = {};
				file.flush();
				file.close();
			end
		end
    	bleEnable(1, node.restart);
	end);
end

--Funcao que verifica se esta na hora de fazer a atualizacao remota
function is_update_time()
	if firstMinute == true then
		firstMinute = false;
	else
        local d = tonumber(node.date("%d"));
		local h = tonumber(node.date("%H"));
		local min = tonumber(node.date("%M"));
		if ((d*24+h)*60+min)%config.update_period then
			print("\n\n\nUpdate Time!!!!!\n\n\n");
			update_time = true;
		end
	end
	updateTimer:alarm(60000, tmr.ALARM_SINGLE, is_update_time);
end

--Callback de quando o buffer dos beacons forem salvos em um arquivo
function buffer_saved()
    mainTimer:alarm(config.bluetooth_period * 1000, tmr.ALARM_SINGLE, alarm_fired);
end

--Callback de quando os arquivos forem enviados
function files_sent()
    if update_time == true then
        update_time = false;
        updatemanager.setup_update();
    else
        beacons.saveBuffer(buffer_saved,bluetooh_period_counter);
        --mainTimer:alarm(config.bluetooth_period * 1000, tmr.ALARM_SINGLE, alarm_fired);
	end
end

--Callback chamada pelo alarme periodico, salva o buffer dos beacons ou faz upload dos arquivos e printa a memória para debug
function alarm_fired()
    local remaining, used, total=file.fsinfo()
    local currHeap = node.heap();
    print("Versao 1");
    uart.write(0,"\n**** Heap=".. currHeap .. " " .. string.format("%.2f",(currHeap/initHeap)*100) .. "% [" .. lastHeap - currHeap .. "] Remaining disk=".. remaining)
    lastHeap = currHeap;
    if  node.heap() < 20000 then 
        log("Reset forçado - Min Heap size")
        node.restart();
    end
    bluetooh_period_counter = bluetooh_period_counter + 1;
    if bluetooh_period_counter == upload_period then
        netmanager.sendfiles(files_sent); 
        bluetooh_period_counter = 0;
    else
        beacons.saveBuffer(buffer_saved,bluetooh_period_counter);
    end;
end;

--Callback de quando o bluetooth estiver configurado. Ativa um alarme periodico
function beacons_ready()
    mainTimer:alarm(config.bluetooth_period * 1000, tmr.ALARM_SINGLE, alarm_fired);
end;

--Callback de quando a rede estiver configurada
function net_ready()
    if firstInit == false then
        firstInit = true;
        beacons.start(beacons_ready);
		updateTimer:alarm(60000, tmr.ALARM_SINGLE, is_update_time);
    end
end;

--Inicialmente, verifica se deve fazer a atualizacao, atraves do arquivo de flag
if file.open("update_flag_file.txt",'r') then
    file.close();
    file.remove("update_flag_file.txt");
    updatemanager.update();
else
    --Senão inicia o programa normalmente, comecando com a configuracao de rede
    netmanager.start(net_ready);
end
