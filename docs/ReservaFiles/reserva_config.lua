local config = {};

--Periodo para salvar os sinais dos beacons em um arquivo interno, em segundos
config.bluetooth_period = 15;
--Periodo para fazer upload dos arquivos. A unidade é o bluetooth_period
config.upload_period = 4;
--De quanto em quanto tempo verifica se há atualização, em minutos
--Sugere-se deixar 1440 (24h) para a atualização ser feita sempre de madrugada, pois a contagem comeca na primeira meia noite do mês
config.update_period = 1440;
--Diretorio dos arquivos de atualizacao remota
config.update_addr = "mbboing.github.io/iot-no-varejo/ReservaFiles/";

return config;
