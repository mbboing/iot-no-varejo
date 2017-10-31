local config = {};

--Periodo para salvar os sinais dos beacons em um arquivo interno, em segundos
config.bluetooth_period = 15;
--Periodo para fazer upload dos arquivos. A unidade é o bluetooth_period
config.upload_period = 4;
--De quanto em quanto tempo verifica se há atualização, em minutos
config.update_period = 2;

return config;
