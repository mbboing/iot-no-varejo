
local bletimer = tmr.create();
local blecounter = 0;
--bleEnable = function(flag,cb) uart.write(0,(flag==0 and "\n-\n") or "\n+\n"); bthci.scan.enable(flag,cb); end;
bleEnable = function(flag,cb)bthci.scan.enable(flag,cb); end;
--bleEnable = function(flag,cb)
--	if flag == 0 then
--		blecounter = 0;
--		bletimer:alarm(10, tmr.ALARM_AUTO, function() blecounter = blecounter + 1;  end);
--		bthci.scan.enable(flag,cb);
--	else
--		bletimer:stop();
--		print("Tempo com ble desligado(ms): " .. blecounter*10)
--		bthci.scan.enable(flag,cb);
--	end;
--end;

--beacons = require "reserva_beacons";
--rede = require "reserva_rede";
beacons = require "reserva_beacons";
netmanager = require "reserva_rede";
config = require "reserva_config";

local mainTimer = tmr.create();
local bluetooth_period = config.bluetooth_period;
local upload_period = config.upload_period;
local bluetooh_period_counter = -1;
local firstInit = false;
local initHeap = node.heap();
local lastHeap = initHeap;

function buffer_saved()
    mainTimer:alarm(config.bluetooth_period * 1000, tmr.ALARM_SINGLE, alarm_fired);
end

function files_sent()
    beacons.saveBuffer(buffer_saved,bluetooh_period_counter);
    mainTimer:alarm(config.bluetooth_period * 1000, tmr.ALARM_SINGLE, alarm_fired);
end

function alarm_fired()
    local remaining, used, total=file.fsinfo()
    local currHeap = node.heap();
    uart.write(0,"\n**** Heap=".. currHeap .. " " .. string.format("%.2f",(currHeap/initHeap)*100) .. "% [" .. lastHeap - currHeap .. "] Remaining disk=".. remaining)
    lastHeap = currHeap;
    if  node.heap() < 20000 then 
        print("Reset forçado - Min Heap size")
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

function beacons_ready()
    mainTimer:alarm(config.bluetooth_period * 1000, tmr.ALARM_SINGLE, alarm_fired);
end;

function net_ready()
    if firstInit == false then
        firstInit = true;
        beacons.start(beacons_ready);
    end
end;

netmanager.start(net_ready);
