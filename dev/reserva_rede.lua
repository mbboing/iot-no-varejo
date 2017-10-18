wificonfig = require "reserva_wifi_config";

local netmanager = {};

local last_file;
local last_file_pending = 0;
local submit_state = "IDLE";

local lastRequestTime=0;
local http_list = {}

local sendFilesRetries=0;
local wifiLost = true;

local isLogUpload = false;


local xml_1_a = [[
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://tempuri.org/">
  <SOAP-ENV:Body>
    <ns1:WriteBeaconLog>
      <ns1:token>]]
local xml_1_b = [[</ns1:token>
      <ns1:deviceId>]]
local xml_1_c = [[</ns1:deviceId>
      <ns1:message>]]                      
local xml_2 = [[</ns1:message>
    </ns1:WriteBeaconLog>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
]]

local http_header_a = "POST /Service1.svc HTTP/1.1 \r\n"
    .."Host: reserva.cloudapp.net\r\n"
    .."Content-Type: text/xml; charset=utf-8\r\n"
    .."Content-Length: ";
local http_header_b = " \r\n"
    ..'SOAPAction: http://tempuri.org/IService1/WriteBeaconLog\r\n'
    .."\r\n";    

local function getHttpHeader(data_len)
    return
      "POST /Service1.svc HTTP/1.1 \r\n"
    .."Host: reserva.cloudapp.net\r\n"
    .."Content-Type: text/xml; charset=utf-8\r\n"
    .."Content-Length: ".. data_len .. " \r\n"
    ..'SOAPAction: http://tempuri.org/IService1/WriteBeaconLog\r\n'
    .."\r\n";
end


local function getTime()
    local now = node.date("*t");
    return now.sec + (now.min*60) + (now.hour*60*60) + (now.day*60*60*24);
end

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

local function send_files_done() print("Sem callback do envio de arquivos") end;

local function submit_done(result_OK)
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

local function submit(msg_list) 
    -- Create the connection object
    local conn = net.createConnection(net.TCP, 0);
	local submit_timeout = tmr.create();

	local function errorHandler()
		submit_timeout:unregister();
        print("Error Handler State = ".. submit_state.. "in ".. getTime() - lastRequestTime);
		if submit_state == "CONREQUEST" or submit_state == "SENDING" then
			submit_state = "IDLE"
			if conn then conn:close(); end
			submit_done(false);
        elseif submit_state == "DISCONNECTED" then
            submit_state = "IDLE"
            submit_done(false);
		end;
	end;

    conn:on("connection", function(conn1, payload)
	    submit_state = "SENDING";

		local nodeId = wifi.sta.getmac():gsub(":","");
		if isLogUpload then
			nodeId = nodeId .. "_LOG";
		end

        local xml_1 = xml_1_a .. wificonfig.token .. xml_1_b .. nodeId .. xml_1_c;
        local dataLen = xml_1:len() + xml_2:len();
        for k,msg in ipairs (msg_list) do
            dataLen = dataLen + msg:len();
        end;
        
        http_list = {}
        table.insert(http_list,http_header_a .. dataLen .. http_header_b);
        table.insert(http_list,xml_1);
        for k,msg in ipairs (msg_list) do
            table.insert(http_list,msg);
        end;
        table.insert(http_list,xml_2);
        
        uart.write(0,' : Connected in '.. getTime() - lastRequestTime);
        local function sendList(sck)
            if #http_list >= http_list_idx then
                local line = http_list[http_list_idx];
                http_list_idx = http_list_idx + 1; 
                -- Protect against an eventual closing
                -- if closed, waits for the timeout
                if sck and sck:getpeer() then
                    sck:send(line);
                else
                    print("Connection closed during send()!");
                end
            else
                http_list_idx = 1;
                http_list={}
            end;
        end;
        conn1:on("sent", sendList);
        http_list_idx=1;
        sendList(conn1);

    end);

    -- Show the retrieved web page
    conn:on("receive", function(connection, payload2) 
		if submit_state == "SENDING" then
            submit_timeout:unregister();
			submit_state = "IDLE";
		    connection:close();
		    uart.write(0," : received in ".. getTime() - lastRequestTime);
		    --print(payload);
		    --print("Result: ",string.find(payload, "<WriteBeaconLogResult>true</WriteBeaconLogResult>") and true or false);
		    local resul_OK =  string.find(payload2, "<WriteBeaconLogResult>true</WriteBeaconLogResult>") and true or false;
            payload=nil;
		    submit_done(resul_OK);
		end;
    end);

    -- When disconnected, let it be known
    conn:on("disconnection", function(connection, payload3) 
        print( "\n===============================",'Disconnected state='..submit_state, "===============================") 
        if submit_state == "SENDING" then
            submit_state = "DISCONNECTED";
        elseif submit_state == "CONREQUEST" then
            -- connect retry
            connection:connect(80,'reserva.cloudapp.net');
        end;
    end);

    -- Submit
    uart.write(0,"Submit ".. #msg_list);
    conn:connect(80,'reserva.cloudapp.net');
	submit_state = "CONREQUEST";
	submit_timeout:alarm(10 * 1000, tmr.ALARM_SINGLE, errorHandler);
    lastRequestTime = getTime();

end;

function netmanager.sendfiles(sendfiles_cb)
	uart.write(0,"\n sendfiles - state=" .. submit_state);
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
					isLogUpload = true;
				else
					isLogUpload = false;
				end
                submit(msg_list);
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
