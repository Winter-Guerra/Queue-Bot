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
_ = require('lodash')

port = process.env.PORT || 3000

# Initialize Twilio API
{accountSid, authToken, serverPhoneNumbers} = fs.readJsonSync('./twilio_account_info.json')

client = new twilio.RestClient(accountSid, authToken)

# ## Default Admin Numbers

admins = [
	'+19174357128', # Winter
	'+19073472182', # Jaguar
]

# ## Initialize the Queue
queue = []
if fs.existsSync('./queue_save.json')
	{queue} = fs.readJsonSync('./queue_save.json')
	cleanQueue(queue)
oldTopQueue = []
timeOfEachRide = 8 # minutes
numberOfPeopletoUpdate = 5
totalPeopleQueued = 0

cleanQueue = (queue) ->
	i = 0
	for user in queue
		# Check that they all have return numbers
		if not user.returnPhoneNumber
			# Add a return phone number
			user.returnPhoneNumber = serverPhoneNumbers[ i % serverPhoneNumbers.length ]


# List the top 5 users in the queue
getQueueData = () ->
	nextUsers = queue[0...5]
	returnString = ""
	letterIndex = null
	for user in nextUsers
		letterIndex = String.fromCharCode(97 + nextUsers.indexOf(user))
		returnString = "#{returnString}\n
#{letterIndex}). #{user.userName}"

	return returnString

# Check the user's place in the queue
userPlaceInQueue = (phoneNumber) ->
	# Loop through queue and look for the phoneNumber
	for index in [0...queue.length]
		queuedNumber = queue[index].phoneNumber
		
		if phoneNumber is queuedNumber
			return index+1
	return null


# Update the 5 people who are next in line.
updateOperatorsAndUsers = () ->
	# Only update people if the queue has shifted.
	topQueue = queue[0...numberOfPeopletoUpdate]

	if _.difference(topQueue, oldTopQueue).length isnt 0

		oldTopQueue = topQueue

		# Update the users in the top of the queue
		for person in queue[0...numberOfPeopletoUpdate]
			{phoneNumber, userName, returnPhoneNumber} = person

			# Check that they actually have a phone that we can call them on.
			if phoneNumber

				# Find the user's place in the queue
				placeInQueue = userPlaceInQueue(phoneNumber)
				# Find ETA
				ETA = placeInQueue * timeOfEachRide

				messageOptions = 
					to: phoneNumber
					from: returnPhoneNumber
					body: "
#{userName}, you are now \##{placeInQueue} in line.\r\n
ETA: #{ETA} minutes.\n
Please find a EC roller coaster operator to get set up for your ride!\n
We are on the 2nd floor of the EC fort, near the entrance stairs.\n
WARNING: If not present, you will be removed from the queue."

				client.sendMessage(messageOptions).done()

		# Update the operators
		for operatorNumber in admins
			
			messageOptions = 
				to: operatorNumber
				from: returnPhoneNumber
				body: "
Queue updated!\r\n
#{getQueueData()}\r\n
Type h for command help."

			client.sendMessage(messageOptions).done()

sendRemovalMsgToUser = (user) ->
	if user
		if user.phoneNumber
			{phoneNumber, userName, returnPhoneNumber} = user

			messageOptions = 
				to: user.phoneNumber
				from: returnPhoneNumber
				body: "
#{userName}, you've been removed from the EC roller coaster queue!\r\n
Please find the operators if you think that this has been a mistake.\r\n
Otherwise, text your kerberos to this number to ride again!
"
			client.sendMessage(messageOptions).done()


# Check which command the admin commanded us to do
# Valid commands are:
	# r = remove from list
	# i = insert to end of list
	# n = next
	# l = list queue
	# h = help
	# remove admin = remove current phone number from admin list

serveAdminSMS = (userPhoneNumber, body, request, response) ->

	console.log "Admin command"

	# Check for "Remove Admin"
	if (/remove admin/i).test(body)
		console.log "->Remove admin"
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
			console.log "->next"
			if queue.length > 0
				user = queue.shift()

			resp = new twilio.TwimlResponse()
			response.send resp.toString()

			# Send updates to the operators and the users in the queue
			updateOperatorsAndUsers()

			# Send text to the person who has been removed from the queue
			sendRemovalMsgToUser(user)
			return

		# Removing a person
		when 'r', 'R'
			console.log "->Remove person"
			name = body.match(/([a-zA-Z]+)/g)[1] # Grab the second argument given
			resp = new twilio.TwimlResponse()
			if not name or name.length isnt 1
				resp.message "ERROR: Supply an queue index to delete. I.E. 'r b'"
				response.send resp.toString()
				return
			# Map the letter to a zero indexed number
			queueIndex = (name.charCodeAt(0) - 97)
			user = queue.splice(queueIndex,1)[0]
			
			# Send empty response
			response.send resp.toString()

			# Send updates to the operators and the users in the queue
			updateOperatorsAndUsers()

			# Send text to the person who has been removed from the queue
			sendRemovalMsgToUser(user)
			return

		# Adding a person's kerberos
		when 'i', 'I'
			totalPeopleQueued++
			userName = body.match(/([a-zA-Z]+)/g)[1]
			console.log "->insert person #{userName}"
			queuedUser =
				userName: userName.concat('* No cell')
				phoneNumber: null # user does not have a phone number
				returnPhoneNumber: serverPhoneNumbers[totalPeopleQueued%serverPhoneNumbers.length]
			queue.push queuedUser

			# Send response
			ETA = queue.length * timeOfEachRide
			resp = new twilio.TwimlResponse()
			resp.message "
#{userName} is now in line.\n
Current position: #{queue.length}.\n
ETA: #{ETA} minutes.\n
BRING A CELLPHONE NEXT TIME!\n
We will NOT text you when it is your turn.\n
You will also NOT be able to check your ETA until you are in the top of the queue.\n
WARNING: If not present, you will be removed from the queue.\n
Meet at the 2nd floor of the EC fort near the entrance stairs when it is your turn.
"
			response.send resp.toString()

			# Send updates to the operators and the users in the queue
			updateOperatorsAndUsers()

			return

		when 'l', 'L'
			console.log "->List queue"
			resp = new twilio.TwimlResponse()
			unless (queue.length > 0)
				console.log "Queue is empty"
				resp.message "Queue is empty"
				response.send resp.toString()
				return
			# list people in queue
			resp = new twilio.TwimlResponse()
			resp.message "Queue:
#{getQueueData()}\n
Type h for command help."
			response.send resp.toString()
			return

		when 'h', 'H'
			console.log "->show help"
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

		else
			console.log "->Unrecognzed command"
			resp = new twilio.TwimlResponse()
			resp.message "Unrecognized admin command. Use 'h' to fetch the list of possible commands."
			response.send resp.toString()

serveRegularSMS = (userPhoneNumber, body, request, response) ->

	console.log "Regular user command:"

	# If not, check if we should add this number to the admin list by checking for 'make admin'
	if (/add admin/i).test(body)
		console.log "->add admin"
		if userPhoneNumber not in admins
			admins.push userPhoneNumber
		resp = new twilio.TwimlResponse()
		resp.message "Admin phone number #{userPhoneNumber} added successfully to list of admins!"
		response.send resp.toString()
		return

	# ADD USER TO QUEUE

	totalPeopleQueued++

	# Check that they are not already in the queue
	place = userPlaceInQueue(userPhoneNumber)
	if place isnt null
		ETA = place * timeOfEachRide
		resp = new twilio.TwimlResponse()
		resp.message "
You are already in line at place #{place}.\r\n
ETA: #{ETA} minutes\r\n
Please wait your turn before re-adding yourself to the queue.\r\n
Standard message rates apply. Don't be dumbfuckers!
"
		response.send resp.toString()
		return

	console.log "Existing place in queue:", place

	# Check that they supplied a name
	userName = null
	if (/[a-zA-Z]+/).test(body)
		userName = body
	else
		# Since they did not supply a name, use their phone number
		userName = userPhoneNumber

	# Queue the user
	queuedUser =
		userName: userName
		phoneNumber: userPhoneNumber
		returnPhoneNumber: serverPhoneNumbers[totalPeopleQueued%serverPhoneNumbers.length]
	# Push the user onto the queue
	queue.push queuedUser

	console.log "->Add person to queue."

	ETA = queue.length * timeOfEachRide
	resp = new twilio.TwimlResponse()

	# Only confirm addition if the person is not at front of line. Otherwise, they will already get an update after they add themselves to the queue.
	if queue.length > numberOfPeopletoUpdate

		resp.message "
#{userName} is now in line.\n
Current position: #{queue.length}.\n
ETA: #{ETA} minutes.\n
ENJOY THE PARTY! We will text you when you can ride the EC roller coaster.\n
WARNING: If not present, you will be removed from the queue.\n
Check your ETA by texting us your kerberos again.\n
Standard message rates apply. Don't be dumbfuckers!
"
	response.send resp.toString()

	# Send updates to the operators and the users in the queue
	updateOperatorsAndUsers()
	return


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
	# --------------------------
	# Handle Admin access

	# If we have an SMS from an admin phone
	if isAdmin
		serveAdminSMS(userPhoneNumber, body, request, response)

	console.log "Queue:", queue


	return

		

app.listen(port)



