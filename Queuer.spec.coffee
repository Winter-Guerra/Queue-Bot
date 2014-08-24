# Unit tester
# /test/demo_form.asp?name1=value1&name2=value2

expect = require 'expect.js'
request = require 'supertest'
fork = require('child_process').fork
{wait, repeat, doAndRepeat, waitUntil} = require 'wait'


describe 'Roller Coaster REST interface', () ->

	request = request('http://localhost:80/incomingSMS/')

	# Start the webserver
	before (done) ->

		fork './server.coffee' # Webserver listening on port 80
		wait 1000, () ->
			done()


	it 'should pull incoming phone numbers from SMS GET request', (done) ->

		message = 
			From: '+19174357128'
			Body: 'This is a test message'

		request.get('?name1=value1&name2=value2')
)

	it 'should pull body info from SMS GET Request', (done) ->