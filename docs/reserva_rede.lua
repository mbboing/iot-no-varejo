wificonfig = require "reserva_wifi_config";
upload = require "reserva_submit";

local netmanager = {};

local last_file;
local last_file_pending = 0;

local sendFilesRetries=0;
local wifiLost = true;

--Funcao que retorna a hora
function getTime()
    local now = node.date("*t");
    return now.sec + (now.min*60) + (now.hour*60*60) + (now.day*60*60*24);
end

--Funcao que le um sntp para pegar a data e hora
local function ajust_date(ajust_date_cb)
    local sntpTimer = tmr.create();
    sntpTimer:alarm(1000, tmr.ALARM_AUTO,
        function ()
            if (node.date("*t").year <= 1970) then
                wifi.sntp("UTC");
                uart.write(0,'t');
            else
               sntpTimer:unregister();
               node.task.post(ajust_date_cb);
            end
        end
        )
end;

--Callback de quando os arquivos forem enviados, configurada por outra parte do codigo
local function send_files_done() print("Sem callback do envio de arquivos") end;

function submit_done(result_OK)
	uart.write(0," : submit_done!");
	uart.write(0, (result_OK and "Success " or "Fail ") );
    if result_OK then
        sendFilesRetries = 0; -- reset the fails counter
        -- remove last file and try next one
        bleEnable(0, function(err)
            file.remove(last_file);
            if (last_file_pending % 5) == 0 then
                bleEnable(1, function() tmr.create():alarm(2500,tmr.ALARM_SINGLE,netmanager.sendfiles); end);
            else
                bleEnable(1, netmanager.sendfiles);
            end
        end);
     else
        bleEnable(1, send_files_done);
     end
end;

--Funcao que gerencia o upload dos arquivos
function netmanager.sendfiles(sendfiles_cb)
    uart.write(0," - sendFilesRetries="..sendFilesRetries);

    if type(sendfiles_cb)=="function" then
        send_files_done = sendfiles_cb;
    end

    -- Reconect the Esp32 if it continuously fails to send messages.
    sendFilesRetries = sendFilesRetries + 1;
    if sendFilesRetries >= ((wifiLost and 3) or 10) then
    	wifi.stop();
    end
    
    bleEnable(0, function(err)
        --print("SendErr:", err);
		last_file = nil;
        local l = file.list();
        local flist={}
        for file_name,_ in pairs(l) do
            if string.find(file_name,"Data") then
                table.insert(flist,file_name);
            end;
        end;
        table.sort(flist)
        uart.write(0," - pending files = ".. #flist .. "\n");
        last_file = flist[1];
        last_file_pending = #flist;
		if last_file then
			if file.open(last_file, "r") then
		        local msg_list = {}
                local line = file.read();
		        while line do
                    table.insert(msg_list,line)
		            line = file.read();
                end
		        file.close();
				if string.find(last_file,"Log") then
					upload.isLogUpload = true;
				else
					upload.isLogUpload = false;
				end
                upload.submit(msg_list);
			else
                sendFilesRetries = 0; -- reset the fails counter
				bleEnable(1, send_files_done);
		    end;
		else
            sendFilesRetries = 0; -- reset the fails counter
			bleEnable(1, send_files_done);
		end;
    end);
end;

--Funcao que inicia e configura a conexao com a rede
function netmanager.start(start_cb)
    local sntpTimer = tmr.create();
    station_cfg={};
    station_cfg.ssid=wificonfig.ssid;
    station_cfg.pwd=wificonfig.pwd;
    wifi.mode(wifi.STATION);
    wifi.start();
    wifi.sta.config(station_cfg);
    wifi.sta.on("got_ip", function(ev, info)
        log("WiFi Connected\n");
        wifiLost = false;
        ajust_date(start_cb);
    end);
    -- Update WIFI status
    wifi.sta.on("disconnected", function(ev,info)
        -- Force flag wifiLost to be true when reason code 201 - NO_AP_FOUND
        -- NO_AP_FOUND happens after a bad disconnection.
        local lastLost = wifiLost;
        wifiLost = (info.reason == 201 and true) or false;
        if wifiLost == true and lastLost == false then
            log(" WiFi disconnected - Reason=" .. info.reason);
        end
    end);
    wifi.sta.on("stop", function(ev, info)
        log("WiFi Stopped\n");
        wifi.start();
    end);
end;

return netmanager;
