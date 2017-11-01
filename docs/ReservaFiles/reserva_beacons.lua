local beacons = {};
local beacons_recebidos = {};
local gblSeq=0;
local msg_list={}
local beacons_timeout = tmr.create();
local beacons_timeout_time = 60*1000; -- 1 minute * factor (see below)

--Funcao que printa erro ou ok
local function print_status(err, name)
    if err then
        print(name .. " error: " .. err);
    else
        print(name .. " ok!");
   end
end

--Funcao que formata o disco mantendo os arquivos salvos
local function restoreFS()
    -- Read current files name and load its contents to memory (only "reserva_*")
    local l = file.list();
    local datafiles={};
    for file_name,_ in pairs(l) do
        if string.find(file_name,"reserva_") or string.find(file_name,"init") then
            datafiles[file_name]={}
            if file.open(file_name, "r") then
                local line = file.readline();
                while line do
                    table.insert(datafiles[file_name],line);
                    line = file.readline();
                end
                file.close();
                print("restoreFS:: file " .. file_name .. " loaded in memory.")
            else
                print("restoreFS:: Error openning file " .. file_name .. " for read - The file will not be loaded.");
            end
        end;
    end;
    -- Format the FileSystem
    print("restoreFS:: Formating the FileSystem.");
    log("Formating the FileSystem.");
    file.format()
    -- Write restored data into file system.
    for file_name, data in pairs(datafiles) do
        if file.open(file_name, "w") then
            for idx,line in ipairs(data) do
                file.write(line);
            end
            file.close();
            print("restoreFS:: file " .. file_name .. " restored to FileSystem.")
        else
            print("restoreFS:: Error openning file " .. file_name .. " for write - The file will not be restored.");
        end
    end
    -- Reset the system	
    log("Rebooting: No Memory.");
    reset();
end

--Funcao que faz o parsing do sinal recebido do beacon e insere a mensagem no buffer
local function parsing(advertisement)
    local hour = node.date("*t").hour;
    local factor = ((hour >= 0 and hour <= 7) and 30) or 5;
    beacons_timeout:interval(beacons_timeout_time * factor);
    local adv = {};
    local offset = 3;
    local buf = {};
    local beaconId;
    for i= 1, string.len(advertisement) do
        buf[i] = string.byte(string.sub(advertisement,i,i));
    end
    
    if string.len(advertisement) > 14 and (buf[14+offset] == 2 and buf[15+offset] == 21) then
        adv.min = buf[34+offset] * 256 + buf[35+offset];
        adv.maj = buf[32+offset] * 256 + buf[33+offset];
        adv.rssi =  buf[37+offset];
        adv.txpower =  buf[36+offset];
        adv.addr = string.sub(advertisement,3,8);
        adv.uuid = string.sub(advertisement,16+offset,31+offset);

        if beacons_recebidos[adv.addr] == nil then 
            beacons_recebidos[adv.addr]={}; 
            beacons_recebidos[adv.addr].seq = gblSeq+string.byte('a');
            gblSeq = gblSeq + 1;
        end
        
        beaconId = adv.min;
        local beacon_msg = node.date("%Y-%m-%d %X.000") .. '\t' .. beaconId .. "\t" .. (adv.rssi - 256) .. "\t" .. (adv.txpower - 256) .. "\n";
        table.insert(msg_list,beacon_msg); 
        uart.write(0,string.char(beacons_recebidos[adv.addr].seq));
    end
end

--Funcao que inicializa o bluetooth e a captura de beacons
function beacons.start(start_done)
    bthci.scan.setparams({mode=0,interval=100,window=90}, 
        function(err) print_status(err,"ParamsSet"); 
        bleEnable(1, function(err1) print_status(err1,"Enable"); end);
    end);
    bthci.scan.on("adv_report", parsing);
    node.task.post(start_done);
    local hour = node.date("*t").hour;
    local factor = ((hour >= 0 and hour <= 7) and 30) or 5;
    beacons_timeout:alarm(beacons_timeout_time * factor, tmr.ALARM_SINGLE, function() log("Rebooting: Beacons Timeout!"); reset(); end);
end

--Funcao que salva o conteudo do buffer de beacons em um arquivo no disco
function beacons.saveBuffer(savebuffer_cb,seq)
	--log("Test do reset");
	--reset();
    bleEnable(0, function(err)
    	if #msg_list > 0 then
            local file_name = node.date("Data_%Y_%m_%d_%H_%M_%S.txt");
            local fstat, ferrmsg = file.open(file_name,"w");
            if fstat then
                for k,v in ipairs(msg_list) do
                    file.write(v);
                end
                print(" Seq:" .. (seq or "_") .. " : " .. file_name);
                msg_list = {};
                file.close();
            else
                print(" Não criou arquivo:" .. file_name .. " - " .. ferrmsg);
                restoreFS();
            end
     	else
        -- Salva arquivo com o "heart beat"
            local file_name = node.date("Data_%Y_%m_%d_%H_%M_%S.txt");
            local fstat, ferrmsg = file.open(file_name,"w");
            if fstat then
                file.write(node.date("%Y-%m-%d %H:%M:%S.000\t0\t0\t0"));
                file.close();
            else
                print(" Não criou arquivo:" .. file_name .. " - " .. ferrmsg);
                restoreFS();
            end
     	end
    	-- Arqivo de logs:
		if #log_list > 0 then
			local log_file_name = node.date("Data_Log_%Y_%m_%d_%H.txt");
			fstat, ferrmsg = file.open(log_file_name,"a");
			if fstat then
				  for k,v in ipairs(log_list) do
				    file.write(v);
				  end
				log_list = {};
				file.close();
			else
                print(" Não criou arquivo:" .. log_file_name .. " - " .. ferrmsg);
                restoreFS();
			end
		end
    	bleEnable(1, savebuffer_cb);
    end);
end

return beacons;
