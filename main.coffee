fs = require 'fs'
http = require 'http'

urlList = 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'

# Task status functions

newStatus = (str) ->
	process.stdout.write "* #{str}\n"

updateStatus = (str) ->
	process.stdout.write "\r* #{str}"

abort = (reason) ->
	newStatus reason
	newStatus 'Task aborted'
	process.exit()

finish = () ->
	newStatus 'Task finished'
	process.exit()


newStatus 'Task started'


# Reading config from config.json

try
	configText = fs.readFileSync 'config.json', 'utf-8'
catch
	abort 'Error while reading config from config.json'


# Parsing config

try
	config = JSON.parse configText
catch
	abort 'Config is not valid JSON'

if not config.route.default?
	abort 'Default route not specified'


# Downloading IP List

newStatus 'Downloading'

http.get urlList, (res) ->

	newStatus "HTTP response status code: #{res.statusCode}"

	sizeTotal = parseInt res.headers['content-length']
	sizeDownloaded = 0

	responseText = ''

	res

	.on 'data', (chunk) ->

		responseText += chunk
		sizeDownloaded += chunk.length
		updateStatus "Receiving #{parseInt(sizeDownloaded / sizeTotal * 100)}% (#{sizeDownloaded} / #{sizeTotal})"

	.on 'end', () ->

		updateStatus '\n'
		newStatus 'Arranging data'

		routeList = []
		theRegion = undefined

		for region, proxy of config.route when region isnt 'default'

			theRegion = region

			if region == 'private'

				# RFC 1918 Section 3
				# Private IP Address
				# http://tools.ietf.org/html/rfc1918#section-3

				routeList.push [
					# 10/8
					{ ip: 0x0A000000, mask: 8, proxy: proxy }
					# 172.16/12
					{ ip: 0xAC100000, mask: 12, proxy: proxy }
					# 192.168/16
					{ ip: 0xC0A80000, mask: 16, proxy: proxy }
				]...

			else

				patten = new RegExp "^apnic\\|#{region}\\|ipv4\\|(\\d*)\\.(\\d*)\\.(\\d*)\\.(\\d*)\\|(\\d*)\\|\\d*\\|.*?$", 'img'
				while result = patten.exec responseText
					routeList.push
						ip: ((result[1] << 24) | (result[2] << 16) | (result[3] << 8) | (result[4])) >>> 0
						mask: Math.log(result[5]) / Math.LN2
						proxy: proxy

		routeList.sort (a, b) -> a.ip - b.ip

		ipList = []
		maskList = []
		proxyList = []

		for route in routeList
			ipList.push route.ip
			maskList.push route.mask
			proxyList.push route.proxy

		theProxy = undefined
		nonDefault = undefined
		theDefault = undefined
		proxyNum = 0
		for name, proxy of config.proxy
			++proxyNum
			theProxy = proxy
			if name == config.route.default
				theDefault = proxy
			else
				nonDefault = proxy

		if proxyNum == 1
			code = "function FindProxyForURL(){return \"#{theProxy}\"}"
		else
			listCode = "var i=#{JSON.stringify(ipList)},m=#{JSON.stringify(maskList)}"
			if proxyNum == 2
				listCode += ';'
				regionCode = "function g(){return \"#{nonDefault}\"}"
			else
				listCode += ",r=#{JSON.stringify(proxyList)},c=#{JSON.stringify(config.proxy)};"
				regionCode = 'function g(n){return c[r[n]]}'
			bsearchCode = 'function b(t){var l=0,r=i.length,m;while(l+1<r){m=parseInt((l+r)/2);if(t>i[m])l=m;else r=m}return l}'
			mainCode = "function FindProxyForURL(url,host){var p=dnsResolve(host).match(/(\\d*)\\.(\\d*)\\.(\\d*)\\.(\\d*)/),q=(p[1]<<24|p[2]<<16|p[3]<<8|p[4])>>>0;if((n=b(q))&&(i[n]&q&0xffffffff<<m[n])>>>0==i[n])return g(n);else return \"#{theDefault}\"}" 
			code = listCode + regionCode + bsearchCode + mainCode

		fs.writeFileSync 'proxy.pac', code

		finish()

.on 'error', (err) ->
	abort err.message
