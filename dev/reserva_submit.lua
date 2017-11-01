wificonfig = require "reserva_wifi_config";

local uploadmanager = {};

local submit_state = "IDLE";

local lastRequestTime=0;
local http_list = {}

uploadmanager.isLogUpload = false;


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

--Funcao que faz o upload de um conteudo dado como parametro
function uploadmanager.submit(msg_list) 
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
		if uploadmanager.isLogUpload then
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

return uploadmanager;
