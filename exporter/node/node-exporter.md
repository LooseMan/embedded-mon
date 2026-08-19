alma9 minimum構成の場合。。。
VSCode Remote-SSH用にtarが必要
また、podman用にpodmanが必要

プロセス起動が起動し接続を待っていること
ss -tlnp

ローカルでHTTPサーバが動作すること
curl -I http://127.0.0.1:9100

Rootless Podmanは、特権を持たない一般ユーザー権限でコンテナを実行するため、ホスト側の iptables や firewalld を直接操作してポートを開放（穴あけ）することができません。（dockerだと自動で穴あけしてくれる）

sudo firewall-cmd --add-port=9100/tcp --permanent
sudo firewall-cmd --reload
