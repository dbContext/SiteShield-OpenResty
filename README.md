<p align="center">
  <img src="https://github.com/dbContext/SiteShield-OpenResty/blob/main/docs/siteshield.svg" width="128">
  <h1 align="center">SiteShield OpenResty</h1>
  <p align="center">Advanced Layer 7 HTTP(s) DDoS Mitigation module for OpenResty ("dynamic web platform based on NGINX and LuaJIT")<p>
</p>
<p align="center">
  <img src="https://github.com/dbContext/SiteShield-OpenResty/workflows/CI/badge.svg" width="90">
</p>

## Features

* **Layer 7 DDoS Mitigation** via JavaScript Challenge.
* Firewall
  * Allow IP Address (Bypass JavaScript Challenge)
  * Block IP Address
  * Allow URI (Bypass JavaScript Challenge)
  * Block URI
* SEO Optimised (Popular Search Engines Bypass JavaScript Challenge)
* Variable Challenge Authentication Time Window
* Variable Rate limit on Served Challenges

## Coming Soon

* Google Recaptcha Challenge
* Invisible JavaScript Challenge
* On Detection Mitigation (currently Always On)
* Automatic Installer Script (Requires Fresh/Vanilla Install)

  
## Getting Started

Below we will go through installing SiteShield-OpenResty on a CentOS 7.9.2009 (Core) linux server, from zero to a fully fledged HTTP reverse proxy, with Layer 7 DDoS Mitigation.


## Prerequisites

You'll need to install a few dependencies that SiteShield-OpenResty utilises.


### OpenResty

```
wget https://openresty.org/package/centos/openresty.repo
sudo mv openresty.repo /etc/yum.repos.d/
yum check-update
yum install openresty -y
```


### Redis

First, install redis server:

```
yum install epel-release -y
yum install redis -y
```

And now you'll want to alter the redis servers configuration slightly, like below:

File: `/etc/redis.conf`

Uncomment line 101/102, and edit to below:
```
unixsocket /var/run/siteshield/redis.sock
unixsocketperm 777
```


### Sockproc

```
wget https://github.com/juce/sockproc/blob/master/sockproc.c
gcc sockproc.c -o sockproc
./sockproc /var/run/siteshield/shell.sock
```


### Shell

```
mkdir /usr/local/openresty/lualib/resty/lua-resty-shell
wget https://github.com/dbContext/lua-resty-shell/blob/master/lib/resty/shell.lua
mv shell.lua /usr/local/openresty/lualib/resty/lua-resty-shell
```


## Configuring Network Firewall

By dropping the IP address at the network interface, we're removing the overhead of OpenResty (CPU) processing the bad requests - greatly improving mitigation throughput.

```
ipset create siteshield-droplist hash:ip hashsize 4096

iptables -I INPUT -m set --match-set siteshield-droplist src -j DROP
iptables -I FORWARD -m set --match-set siteshield-droplist src -j DROP
```


## Configuring User Groups / Directory Permissions for UNIX Sockets

```
sudo groupadd siteshield
sudo usermod -a -G siteshield redis
sudo usermod -a -G siteshield nginx

sudo chgrp -R siteshield /var/run/siteshield/
sudo chmod -R 777 /var/run/siteshield/
```


## Installing SiteShield

First, download `SiteShield.lua` to the relevant OpenResty/Nginx Directory.

```
wget https://github.com/dbContext/SiteShield-OpenResty/blob/main/SiteShield.lua
mv SiteShield.lua /usr/local/openresty/nginx/conf
```

Lastly, you'll now want to alter your nginx.conf, to utilise `SiteShield.lua`.

```
  ...
	server {
		
    ...

		set $auth_time '86400'; // Time User is Authenticated after Challenge in seconds.
		set $allow_ip ''; // format: 1.1.1.1;2.2.2.2;3.3.3.3
		set $block_ip ''; // format: 4.4.4.4;5.5.5.5;6.6.6.6
		set $allow_uri ''; // format: /allow-this-uri;/also/allow/this/uri
		set $block_uri ''; // format: /block-this-uri;/also/block/this/uri
		set $max_failed_challenge_attempts '5'; // Max Failed Challenge Attempts before IP block.
		set $max_time_window_challenges '120'; // Max Challenges Served in Time Window (e.g. 5 Challenges with in 120 seconds.)

		location / {
			content_by_lua_file /usr/local/openresty/nginx/conf/SiteShield.lua;
		}

		error_page 555 = @backend;
		
		location @backend {
			proxy_set_header Host $host;
			proxy_set_header SiteShield-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_http_version 1.1;
			proxy_set_header Connection '';
			proxy_redirect off;
			proxy_buffering off;
			proxy_pass http://google.com;
		}
	}
  ...
```


## Ready to go!

If everything above went as expected, after restarting the relevant services (commands below), you'll have a HTTP Reverse Proxy with Layer 7 DDoS Mitigation.

```
service redis restart
service openresty restart
```

## Contributing

Please read [CONTRIBUTING](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.


## Authors

* **[dbContext](https://github.com/dbContext)** - *Initial work*

See also the list of [contributors](https://github.com/dbContext/SiteShield-OpenResty/contributors) who participated in this project.


## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details


## Acknowledgments

* **[openresty](https://github.com/openresty/openresty)**
* **[redis](https://github.com/redis/redis)**
* **[lua-resty-shell](https://github.com/juce/lua-resty-shell)**
* **[sockproc](https://github.com/juce/sockproc)**
