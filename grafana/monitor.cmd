docker build -t monitor .
docker run -d --name docker-influxdb-grafana -p 3003:3003 -p 3004:8083 -p 8089:8089/udp -p 8086:8086 -p 22022:22 -v influxdb:/var/lib/influxdb -v grafana:/var/lib/grafana --restart unless-stopped --health-start-period=60s --health-retries=10 --health-interval=5s --health-timeout=2s --health-cmd="curl -sf http://127.0.0.1:3003 >/dev/nul || dexit 1" monitor:latest

