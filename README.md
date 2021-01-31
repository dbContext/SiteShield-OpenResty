<p align="center">
  <img src="https://github.com/dbContext/SiteShield-OpenResty/blob/main/docs/siteshield.svg" width="128">
  <h1 align="center">SiteShield OpenResty</h1>
  <p align="center">Advanced Layer 7 HTTP(s) DDoS Mitigation module for OpenResty ("dynamic web platform based on NGINX and LuaJIT")<p>
  </p>
</p>

## Features

* **Layer 7 DDoS Mitigation** via JavaScript Challenge.
* Firewall
  * Allow IP Address (Bypass JavaScript Challenge)
  * Block IP Address
  * Allow URI (Bypass JavaScript Challenge)
  * Block URI
* SEO Optimised (Popular Search Engines Bypass JavaScript Challenge)
* Variable Challenge Authentication Time Window (5m, 15m, 30m, 1h, 3h, 6h, 12h, 24h)

## Coming Soon

* Google Recaptcha Challenge
* Invisible JavaScript Challenge
* On Detection Mitigation (currently Always On)
  
  
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

Change line 84 to disable TCP socket:
```
port 0
```

Uncomment line 101/102, and edit to below:
```
unixsocket /var/run/siteshield/redis.sock
unixsocketperm 777
```

Finally, start the redis server.

```
service redis start
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

		set $auth_time '24h';
		set $allow_ip '';
		set $block_ip '';
		set $allow_uri '';
		set $block_uri '';
		set $max_failed_challenge_attempts '5';
		set $max_time_window_challenges '120';

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
