# Projeto RNP GT-TeI: Testbed para Espaços Inteligentes 
## 'Céu na Terra' Testbed

### Procedimento de instalação - parte Web e Banco de Dados

   cd ~

#instalar Lua
  
    sudo apt-get install lua5.1
    sudo apt-get install lua-md5
    

# instalar o Apache(2.4.12)
  # adicionar o repositório PPA para versão mais recente do Apache. 
  
    
    sudo apt-add-repository ppa:ondrej/apache2
    sudo apt-get update
    
  # instalar o  Apache
    
      
      sudo apt-get install apache2
      

# habilitar Lua no Apache (enable mod_lua)
    
      
      sudo a2enmod lua
      

# reiniciar o serviço do Apache

  
  sudo service apache2 restart
  
# instalar luarocks
  
  
  sudo apt-get install liblua5.1-0-dev
  wget http://luarocks.org/releases/luarocks-2.2.2.tar.gz
  tar zxpf luarocks-2.2.2.tar.gz
  cd luarocks-2.2.2
  ./configure; sudo make bootstrap
  cd ~
  
# instalar Git
 
  
  sudo apt-get install git
  
# instalar Sailor e luasec
 
  
  sudo luarocks install luasec OPENSSL_LIBDIR=/usr/lib/x86_64-linux-gnu/
  sudo luarocks install cgilua 5.1.4-2
  sudo luarocks install sailor 0.2.1-1
  
# instalar luaposix
 
  
  sudo luarocks install luaposix
  

# instalar postgresql(9.3)--

    
    sudo apt-get install postgresql libpq-dev
    
# instalar suporte Postgres para Lua (luasql-postgres)
 
  
  sudo luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql/
    
# baixar aplicação Testbed

  
   cd ~
   git clone https://github.com/afbranco/Testbed
   <entre com o seu usuário e senha do Github>
 
