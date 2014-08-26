# Roller Coaster Queuing Program.
# By Winter Guerra. August 20th, 2014. CC-BY-SA 3.0.

# This program will advertise a phone number that people can text with their name.
# Once received, the name and number is entered into a FIFO queue.
# Every few minutes, the roller coaster operator should text the number with "next" to get the queue to move along.
# The program will respond to the operator with an updated list truncated to 5 people.
# Then, the program will respond to the 3 people in the front of the FIFO queue. 

twilio = require('twilio')
fs = require 'fs-extra'
express = require 'express'
bodyParser = require('body-parser')
CacheControl = require("express-cache-control")
cache = new CacheControl().middleware
pg = require("pg")

QueueClass = require 'QueueClass'
queue = new QueueClass
_ = require('lodash')

port = process.env.PORT || 3000


{accountSid, authToken, serverPhoneNumbers} = fs.readJsonSync('./twilio_account_info.json')

# Initialize Server
server =
	timeOfEachRide: 8 # minutes
	numberOfPeopletoUpdate: 5
	totalPeopleQueued: 0
	admins: [
	'+19174357128', # Winter
	'+19073472182', # Jaguar
	'+16785922741']  # Ben Katz 
	phoneNumbers: phoneNumbers

# Initialize queue
pg.connect process.env.DATABASE_URL, (err, client) ->
	# Make sure that the queue table exists
	createdTable = client.query "CREATE TABLE IF NOT EXISTS queue (id integer, data json)"

	# Grab the old queue
	query = client.query("SELECT data FROM queue")
	query.on "row", (row) ->
		console.log JSON.stringify(row)
		console.log JSON.parse(row)


# Save the queue in the database
process.on 'SIGINT', () ->
	for index in [1...@queue.length]
		user = @queue.queue[index]

		pg.connect process.env.DATABASE_URL, (err, client) ->
			# Output the old queue
			query = client.query("SELECT data FROM queue")

  
	process.exit()




# Start up a webserver
app = express()

app.use(cache("seconds", 0))

# parse body of incoming requests
app.use(bodyParser.urlencoded({ extended: false }))
app.use(bodyParser.json())
app.use(bodyParser.json({ type: 'application/vnd.api+json' }))

app.get '/', (req, res) ->
	res.send('Welcome to the Queuebot homepage!')

# Listen for incoming SMS messages
app.use '/incomingSMS/', (req, res, next) ->

	# Initialize basic details of SMS message
	req.phoneNumber = request.param('From')
	req.body = request.param('Body')

	console.log "NEW SMS: ", req.phoneNumber, req.body

	# Check if the incoming message originated from an admin phone
	req.isAdmin = (req.phoneNumber in server.admins)

	# Handle Regular user access

	console.log "Queue:", queue


	return

app.use '/incomingSMS/', adminMiddleware

app.use '/incomingSMS/', userMiddleware

		

app.listen(port)



