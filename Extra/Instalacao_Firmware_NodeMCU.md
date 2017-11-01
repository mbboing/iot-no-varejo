# Instalação do firmware do NodeMCU com as configurações usadas no projeto

A instalação só pode ser feita usando linux, portanto, caso esteja utilizando outro sistema, o primeiro passo é instalar uma máquina virtual.

BUILD:
- Atualizar o apt-get:
	sudo apt-get update
- Instalar as dependencias:
	sudo apt-get install git
	sudo apt-get install libncurses-dev
	sudo apt-get install flex
	sudo apt-get install bison
	sudo apt-get install gperf
	sudo apt-get install python-pip
	pip install pyserial
- Clone no repositório do NodeMCU
	git clone --branch dev-esp32 --recurse-submodules https://github.com/nodemcu/nodemcu-firmware.git nodemcu-firmware-esp32
- Caso já tenha o repositório, atualize-o
	git pull origin dev-esp32
	git submodule update --init --recursive
- Entre no repositório:
	cd nodemcu-firmware-esp32/
- Opções de build, gerando o arquivo de configurações "menuconfig"
	make menuconfig
- Controlando com as setas, vá em:
Optimization Level, mude para Release
NodeMCU miscellaneous, mude para ALL
ESP32-specific, marque "Invoke Panic Handler"
Wi-fi, marque "Software Controls Wifi/Bluetooth coexistence"
Component config, habilite o bluetooth, wifi e entre em NodeMCU modules.
- Selecione Bit, Bluetooth interface, Encoder, File, GPIO, I2C, Net, Node, 1-Wire, Timer, WiFi.
- Salve e saia do programa.
- Gerar o build
	make

FLASH:
- Conecte o ESP ao usb
- make flash

BAIXAR O ESPLORER:
- Vá em https://esp8266.ru/esplorer/ e baixe o zip
- Descompacte a pasta
- Baixe o jre
	sudo apt-get install defaut-jre
- Para rodar o programa
	java -jar ESPlorer.jar
