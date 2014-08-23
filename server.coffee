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
	'19174357128', # Winter
	'19073472182', # Jaguar
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
	for index in [0...phoneNumber.length]
		number = queue[index].phoneNumber
		
		if number is phoneNumber
			return index
	return null





# Start up a webserver
app = express()

# parse application/x-www-form-urlencoded
app.use(bodyParser.urlencoded({ extended: false }))

# parse application/json
app.use(bodyParser.json())

# parse application/vnd.api+json as json
app.use(bodyParser.json({ type: 'application/vnd.api+json' }))

app.get '/', (req, res) ->
	res.send('Welcome to the Queuebot homepage!')

# Listen for incoming SMS messages
app.post '/incomingSMS/', (request, response) ->
	response.header('Content-Type', 'text/xml')

	console.log "Req", request.param('From'), request.param('Body')

	# Initialize basic details of SMS message
	userPhoneNumber = request.param('From')
	body = request.param('Body')

	# Check that the SMS is able to get the user's phone number
	console.log "Got message from user: ", userPhoneNumber
	console.log "Got body: ", body

	# Check if the incoming message originated from an admin phone
	isAdmin = (userPhoneNumber in admins)
	
	if not isAdmin
		
		# If not, check if we should add this number to the admin list by checking for 'make admin'
		if (/make admin/i).test(body)
			admins.push userPhoneNumber
			response.send "<Response><Sms>Admin phone number #{userPhoneNumber} added successfully to list of admins!</Sms></Response>"
			return
		
		# If this is just going to be a regular user, then log their name and phone number into the queue

		# Check that they are not already in the queue
		if userPlaceInQueue(userPhoneNumber)
			response.send "<Response><Sms>You are already in the queue at place #{userPlaceInQueue(userPhoneNumber)}.</Sms></Response>"
			return

		# Check that they supplied a name
		userName = null
		if (/[a-zA-Z]*/).test(body)
			userName = body
		else
			# Since they did not supply a name, use their phone number
			userName = userPhoneNumber

		queuedUser =
			name: userName
			phoneNumber: userPhoneNumber

		# Push the user onto the queue
		queue.push queuedUser

		response.send "<Response><Sms>User #{userName} added to the queue. Current position: #{queue.length}. Enjoy the party! We will text you when it is your turn to ride.</Sms></Response>"
		return

	# If we have an SMS from an admin phone
	if isAdmin

		# Check which command the admin commanded us to do
		# Valid commands are:
		# r = remove from list
		# i = insert to end of list
		# n = next

		# Grab the first argument of the sms
		command = (/(^[a-zA-Z]*)/).exec(body)[1]

		switch command
			# Shifting the Queue along
			when (/n/i).test(command)
				if queue.length > 0
					queue.shift()
				response.send "<Response><Sms>#{getQueueData()}</Response></Sms>"
				return

			# Removing a person
			when (/r/i).test(command)
				queueIndex = (/(^[a-zA-Z]*)/).exec(body)[2]
				if not queueIndex
					reponse.send "<Response><Sms>ERROR: Supply an queue index to delete. I.E. 'r b'.</Response></Sms>"
				# Map the letter to a zero indexed number
				queueIndex = (queueIndex.charCodeAt(0) - 97)
				queue.splice(queueIndex,1)

				response.send "<Response><Sms>#{getQueueData()}</Response></Sms>"
				return

			# Adding a person
			when (/i/i).test(command)
				userName = (/(^[a-zA-Z]*)/).exec(body)[2]
				queuedUser =
					name: userName
					phoneNumber: userPhoneNumber
				queue.push queuedUser
				response.send "<Response><Sms>#{getQueueData()}</Response></Sms>"
				return

app.listen(port)


	# If the message came from a user's cellphone, 






