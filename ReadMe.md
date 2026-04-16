

# Сборка

Во время сборки контейнера необходимо наличие VPN, более того по-умолчанию docker НЕ использует подключенный VPN (т.к. служба запускается до запуска VPN).

нужно либо сделать вот так
```
sudo systemctl stop docker
вот тут запустить vpn
sudo systemctl start docker
```
и собрать по-нормальному

либо сбилдить с прокси куда скормить сокет Tor
```
docker build --build-arg HTTP_PROXY=socks5h://pi.home1:9050 -t alex/tor .
```