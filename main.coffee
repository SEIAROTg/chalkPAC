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

if not config.default?
	abort 'Default proxy not specified'


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
		regionNum = 0
		theRegion = undefined
		for region, proxy of config when region isnt 'default'
			++regionNum
			theRegion = region
			patten = new RegExp "^apnic\\|#{region}\\|ipv4\\|(\\d*)\\.(\\d*)\\.(\\d*)\\.(\\d*)\\|(\\d*)\\|\\d*\\|.*?$", 'img'
			while result = patten.exec responseText
				routeList.push
					ip: ((result[1] << 24) | (result[2] << 16) | (result[3] << 8) | (result[4])) >>> 0
					mask: Math.log(result[5]) / Math.LN2
					region: region

		routeList.sort (a, b) -> a.ip - b.ip

		ipList = []
		maskList = []
		regionList = []

		for route in routeList
			ipList.push route.ip
			maskList.push route.mask
			regionList.push route.region

		if regionNum == 0
			code = "function FindProxyForURL(){return \"#{config.default}\"}"
		else
			listCode = "var i=#{JSON.stringify(ipList)},m=#{JSON.stringify(maskList)}"
			if regionNum == 1
				listCode += ';'
				regionCode = "function g(){return \"#{config[theRegion]}\"}"
			else
				listCode += ",r=#{JSON.stringify(regionList)};"
				regionCode = 'function g(n){return r[n]}'
			bsearchCode = 'function b(t){var l=0,r=i.length,m;while(l+1<r){m=parseInt((l+r)/2);if(t>i[m])l=m;else r=m}return l}'
			mainCode = "function FindProxyForURL(url,host){var p=dnsResolve(host).match(/(\\d*)\\.(\\d*)\\.(\\d*)\\.(\\d*)/),q=(p[1]<<24|p[2]<<16|p[3]<<8|p[4])>>>0;if((n=b(q))&&(i[n]&q&0xffffffff<<m[n])>>>0==i[n])return g(n);else return \"#{config.default}\"}" 
			code = listCode + regionCode + bsearchCode + mainCode

		fs.writeFileSync 'proxy.pac', code

		finish()

.on 'error', (err) ->
	abort err.message
