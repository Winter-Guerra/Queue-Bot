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

port = process.env.PORT || 3000

# Initialize Twilio API
{accountSid, authToken, serverPhoneNumber} = fs.readJsonSync('./twilio_account_info.json')

client = new twilio.RestClient(accountSid, authToken)

# ## Default Admin Numbers

admins = [
	'+19174357128', # Winter
	'+19073472182', # Jaguar
]

# ## Initialize the Queue

queue = []

getQueueData = () ->
	# List the top 5 users in the queue
	nextUsers = queue[0...5]
	returnString = "Next users in line"
	letterIndex = null
	for user in nextUsers
		letterIndex = String.fromCharCode(97 + nextUsers.indexOf(user))
		returnString = "#{returnString}\n
#{letterIndex}). #{user.userName}"

	# Now append docs
	returnString = "#{returnString}\n
------\n
Valid commands are:\n
n = next\n
r X = remove index X from list\n
i X = insert kerberos to end of list\n
"
	return returnString

userPlaceInQueue = (phoneNumber) ->
	# Loop through queue and look for the phoneNumber
	for index in [0...queue.length]
		queuedNumber = queue[index].phoneNumber
		
		if phoneNumber in queuedNumber
			return index
	return null

updatePeopleInQueue = () ->
	for person in queue.slice(0,3)
		{phoneNumber, name} = person

		# Find the user's place in the queue
		placeInQueue = userPlaceInQueue(phoneNumber)

		messageOptions = 
			to: phoneNumber
			from: serverPhoneNumber
			body: "#{name}, you are now \##{placeInQueue} in line. Please find the EC roller coaster operators to get set up for your ride!"

		promise = client.sendMessage(messageOptions)
		
		.then( 
			(call) ->
				console.log('Call success! Call SID: '+call.sid)
			,(call) ->
				console.error('Call failed!  Reason: '+error.message)
		)


# Check which command the admin commanded us to do
# Valid commands are:
	# r = remove from list
	# i = insert to end of list
	# n = next
	# l = list queue
	# h = help
	# remove admin = remove current phone number from admin list

serveAdminSMS = (userPhoneNumber, body, request, response) ->

	# Check for "Remove Admin"
	if (/remove admin/i).test(body)
		# Remove admin from the list
		index = admins.indexOf userPhoneNumber
		admins.splice(index,1)
		resp = new twilio.TwimlResponse()
		resp.message "Admin #{userPhoneNumber} removed from admin list."
		response.send resp.toString()
		return

	# Check for one-char commands
	command = body[0]

	switch command
		# Shifting the Queue along
		when 'n', 'N'
			if queue.length > 0
				queue.shift()
			# Send updates to the next 3 people in the queue
			updatePeopleInQueue()
			# Update the other admins about the queue

			resp = new twilio.TwimlResponse()
			resp.message "Queue:\n
{getQueueData()}\n
Type h for command help."
			response.send resp.toString()
			return

		# Removing a person
		when 'r', 'R'
			secondArg = (/([a-zA-Z]+)/g).exec(body)[1] # Grab the second argument given
			resp = new twilio.TwimlResponse()
			if not secondArg or secondArg.length isnt 1
				resp.message "ERROR: Supply an queue index to delete. I.E. 'r b'"
				response.send resp.toString()
				return
			# Map the letter to a zero indexed number
			queueIndex = (secondArg.charCodeAt(0) - 97)
			queue.splice(queueIndex,1)

			resp.message "Queue:\n
{getQueueData()}\n
Type h for command help."
			response.send resp.toString()
			return

		# Adding a person's kerberos
		when 'i', 'I'
			userName = (/([a-zA-Z]+)/g).exec(body)[1]
			queuedUser =
				name: userName
				phoneNumber: userPhoneNumber
			queue.push queuedUser
			resp = new twilio.TwimlResponse()
			resp.message "Queue:\n
{getQueueData()}\n
Type h for command help."
			response.send resp
			return

		when 'l', "L"
			# list people in queue
			resp = new twilio.TwimlResponse()
			resp.message "Queue:\n
{getQueueData()}\n
Type h for command help."
			response.send resp
			return

		when 'h', 'H'
			# List commands
			resp = new twilio.TwimlResponse()
			resp.message "
Commands:\n
n = next\n
l = list queue\n
r n = remove nth person from list where n = a,b,c,d\n
i name = insert name to end of list\n
h = help\n
remove admin = remove current phone from admin list\n
add admin = add current phone to admin list"
			response.send resp.toString()
			return

serveRegularSMS = (userPhoneNumber, body, request, response) ->

	# If not, check if we should add this number to the admin list by checking for 'make admin'
	if (/make admin/i).test(body)
		admins.push userPhoneNumber
		resp = new twilio.TwimlResponse()
		resp.message "Admin phone number #{userPhoneNumber} added successfully to list of admins!"
		response.send resp.toString()
		return

	# Check that they are not already in the queue
	if userPlaceInQueue(userPhoneNumber)
		resp = new twilio.TwimlResponse()
		resp.message "You are already in the queue at place #{userPlaceInQueue(userPhoneNumber)}."
		response.send resp.toString()
		return

	# Check that they supplied a name
	userName = null
	if (/[a-zA-Z]*/).test(body)
		userName = body
	else
		# Since they did not supply a name, use their phone number
		userName = userPhoneNumber

	# Queue the user
	queuedUser =
		name: userName
		phoneNumber: userPhoneNumber
	# Push the user onto the queue
	queue.push queuedUser

	resp = new twilio.TwimlResponse()
	resp.message "#{userName} is now in line. Current position: #{queue.length}.\n
Enjoy the party! We will text you when you can ride the EC roller coaster."
	response.send resp.toString()
	return


# Start up a webserver
app = express()

# parse body of incoming requests
app.use(bodyParser.urlencoded({ extended: false }))
app.use(bodyParser.json())
app.use(bodyParser.json({ type: 'application/vnd.api+json' }))

app.get '/', (req, res) ->
	res.send('Welcome to the Queuebot homepage!')

# Listen for incoming SMS messages
app.post '/incomingSMS/', (request, response) ->

	# Initialize basic details of SMS message
	userPhoneNumber = request.param('From')
	body = request.param('Body')

	console.log "NEW SMS: ", userPhoneNumber, body


	# Check if the incoming message originated from an admin phone
	isAdmin = (userPhoneNumber in admins)

	# --------------------------
	# Handle Regular user access

	if not isAdmin
		serveRegularSMS(userPhoneNumber, body, request, response)
		return
	# --------------------------
	# Handle Admin access

	# If we have an SMS from an admin phone
	if isAdmin
		serveAdminSMS(userPhoneNumber, body, request, response)
		return

		

app.listen(port)



