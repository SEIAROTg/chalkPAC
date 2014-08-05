# chalkPAC

[![NPM IMAGE]][NPM]

chalkPAC is a PAC(Proxy Auto Config) file generator

## Usage

1. Install [Node.js](http://nodejs.org/)

2. Install chalkPAC and get into its directory with

    	npm install chalk-pac
    	cd node_modules/chalkPAC
    
    or
    
    	git clone https://github.com/SEIAROTg/chalkPAC.git
    	cd chalkPAC

3. Edit `config.json`

4. Run chalkPAC with

        node main

5. `proxy.pac` is now generated

## Configuration

chalkPAC configuration is stored in `config.json` like the following:

    {
    	"proxy": {
    		"direct": "DIRECT",
    		"socks5": "SOCKS5 127.0.0.1:1080"
    	},
    	"route": {
    		"private": "direct",
    		"CN": "direct",
    		"default": "socks5"
    	}
    }

This example configuration 

### proxy

`proxy` defines a list of PAC proxy with key & value

the key is proxy name

the value is PAC proxy string

### route

`route` defines a list of proxy rule with key & value

the key can be `"private"`, `"default"` or region code

the value is a proxy name defined in `proxy`

#### "private"

`"private"` stands for Private IP Address ([RFC 1918](http://tools.ietf.org/html/rfc1918#section-3))

#### "default"

If no route is matched, this will be used

It's necessary

#### region code

A region code stands for its IP Address

## Note

* Only Asia Pacific regions are supported currently

[NPM]:			https://www.npmjs.org/package/chalk-pac
[NPM IMAGE]:	http://img.shields.io/npm/v/chalk-pac.svg