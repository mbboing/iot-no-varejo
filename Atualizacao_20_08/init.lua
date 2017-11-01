local initTimer = tmr.create();
initTimer:alarm(5000, tmr.ALARM_SINGLE, function() dofile("reserva_main.lua") end);
