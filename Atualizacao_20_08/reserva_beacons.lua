local beacons = {};
local beacons_recebidos = {};
local gblSeq=0;
local msg_list={}
local beacons_timeout = tmr.create();
local beacons_timeout_time = 60*1000; -- 1 minute * factor (see below)

local function print_status(err, name)
    if err then
        print(name .. " error: " .. err);
    else
        print(name .. " ok!");
   end
end

local function distance(rssi, txpower)
    --This is based on the algorithm from http://stackoverflow.com/questions/20416218/understanding-ibeacon-distancing
    local distance = 0;
    local ratio_linear = 0;
    local ratio = (256 - rssi)/(256 - txpower);

    if ratio < 10 then
        distance = ratio ^ 10;
    else
        distance = (0.89976)*(ratio^7.7095) + 0.111;
    end

    return distance;
end

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
    node.restart();
end


local function parsing(advertisement)
    --wifi.sntp("UTC");
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
    --uart.write(0,"*");
    if string.len(advertisement) > 14 and (buf[14+offset] == 2 and buf[15+offset] == 21) then
        --print("ADV: " , encoder.toHex(message));
--                 ?? addr ??  uuid      mj mi tx rssi
--structFormat = "!1>I2 I4I2 c10 I4I4I4I4  H  H  b  b";
-- local _, addr1, addr2,_, uuid1, uuid2, uuid3, uuid4, maj, min,txpower,rssi = struct.unpack(structFormat,advertisement)
--print(string.format("%x%x %x%x%x%x %d %d %d %d",addr1,addr2,uuid1,uuid2,uuid3,uuid4,maj,min,txpower,rssi));

        adv.min = buf[34+offset] * 256 + buf[35+offset];
        adv.maj = buf[32+offset] * 256 + buf[33+offset];
        adv.rssi =  buf[37+offset];
        adv.txpower =  buf[36+offset];
        adv.addr = string.sub(advertisement,3,8);
        adv.uuid = string.sub(advertisement,16+offset,31+offset);

        adv.dist = distance(adv.rssi, adv.txpower);


        if beacons_recebidos[adv.addr] == nil then 
            beacons_recebidos[adv.addr]={}; 
            beacons_recebidos[adv.addr].seq = gblSeq+string.byte('a');
            gblSeq = gblSeq + 1;
        end
        --beaconId = encoder.toHex(adv.addr);
        beaconId = adv.min;
        --msg_to_azure = msg_to_azure .. node.date("%Y-%m-%d %X.000") .. '\t' .. beaconId .. "\t" .. (adv.rssi - 256) .. "\t" .. (adv.txpower - 256) .. "\n";
        local beacon_msg = node.date("%Y-%m-%d %X.000") .. '\t' .. beaconId .. "\t" .. (adv.rssi - 256) .. "\t" .. (adv.txpower - 256) .. "\n";
        table.insert(msg_list,beacon_msg);
        uart.write(0,string.char(beacons_recebidos[adv.addr].seq));
        
    end
end

function beacons.start(start_done)
    bthci.scan.setparams({mode=0,interval=100,window=100,filter_policy=0}, 
        function(err) print_status(err,"ParamsSet"); 
        bleEnable(1, function(err1) print_status(err1,"Enable"); end);
    end);
    bthci.scan.on("adv_report", parsing);
    node.task.post(start_done);
    local hour = node.date("*t").hour;
    local factor = ((hour >= 0 and hour <= 7) and 30) or 5;
    beacons_timeout:alarm(beacons_timeout_time * factor, tmr.ALARM_SINGLE, function() print("Beacons Timeout!"); node.restart(); end);
end

function beacons.saveBuffer(savebuffer_cb,seq)
--print("@a");
    if #msg_list > 0 then
        bleEnable(0, function(err)
--print("@b");
            local file_name = node.date("Data_%Y_%m_%d_%H_%M_%S.txt");
            --print("saveBuffer:", err, #msg_list, file_name);
--print("@c");
            local fstat, ferrmsg = file.open(file_name,"w")
            if fstat then
--print("@d");
                for k,v in ipairs(msg_list) do
                    file.write(v);
                end
                print(" Seq:" .. (seq or "_") .. " : " .. file_name);
                msg_list = {};
                file.close();
--print("@e");
            else
                print(" Não criou arquivo:" .. file_name .. " - ", ferrmsg);
                restoreFS();
            end
            bleEnable(1, savebuffer_cb);
        end);

	else
		-- Salva arquivo com o "heart beat"
		bleEnable(0, function(err)
            local file_name = node.date("Data_%Y_%m_%d_%H_%M_%S.txt");
            local fstat, ferrmsg = file.open(file_name,"w")
            if fstat then
                file.write(node.date("#NoBeacons %Y-%m-%d %H:%M:%S.000"));
                file.close();
            else
                print(" Não criou arquivo:" .. file_name .. " - ", ferrmsg);
                restoreFS();
            end
            bleEnable(1, savebuffer_cb);
        end);

     --else
     --   print(" msg_list vazia");
     --   node.task.post(savebuffer_cb);
     end
end

return beacons;
