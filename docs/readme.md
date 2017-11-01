# iot-no-varejo

Arquivos para gerar a página do github mbboing.github.io/iot-no-varejo/

A pasta ReservaFiles contém os arquivos que serão baixados pelos microcontroladores para realizar a atualização remota.


Para alterar os arquivos da atualização remota:

Execute o script lua criarVersao.lua em sua máquina para gerar o arquivo versao.lua no mesmo diretório, que é arquivo principal para a atualização remota.
Copie todos os arquivos para a página que será consultada pelos microcontroladores. No momento é a pasta ReservaFiles.


Para alterar a página da atualização remota:

Caso seja necessário que os microcontroladores consultem outra página ao invés deste github, deve-se alterar o endereco no arquivo reserva_config.lua
É necessário que essa página seja HTTP, e não HTTPS, para que os microcontroladores possam baixar os arquivos.
Desta forma, não é possível criar uma nova página de github para o projeto, pois o github exige que as novas páginas sejam HTTPS.
