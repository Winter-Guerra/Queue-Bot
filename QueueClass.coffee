
Messenger = require './Messenger'

# This base class knows how to manipulate the queue
class Queue
	# Is given a server and a queue
	constructor: (@server, @queue) ->

		@messenger = new Messenger

		# For keeping track of when to update status
		@oldTopQueue = []

		# Resume the queue

###
# QUEUE UTILITY FUNCTIONS
###

	resolveUser: (user) =>
		# Check that they supplied a name
		userName = null
		if user.userName
			if not (/[a-zA-Z]+/).test(user.userName)
			# Since they did not supply a name, use their phone number
			user.userName = user.phoneNumber
		else
			# Since they did not supply a name, use their phone number
			user.userName = user.phoneNumber

		# Assign them a number to use when calling the server
		if not user.returnPhoneNumber
			user.returnPhoneNumber = @server.phoneNumbers[@server.totalPeopleQueued % @server.phoneNumbers.length]

		return user

	# Add a user
	addUser: (user) =>
		@server.totalPeopleQueued++

		# Push the user onto the queue
		@queue.push user


	# Check the user's place in the queue
	userPlaceInQueue: (user) =>
		{phoneNumber, userName, returnPhoneNumber} = user

		# Loop through queue and look for the phoneNumber
		for index in [0...@queue.length]
			queuedNumber = @queue[index].phoneNumber
			
			if phoneNumber is queuedNumber
				return index+1
		return null

	# Will make sure that all users have a return phoneNumber
	cleanQueue: () =>
	i = 0
	for user in @queue
		# Check that they all have return numbers
		if not user.returnPhoneNumber
			# Add a return phone number
			user.returnPhoneNumber = @serverPhoneNumbers[ i % @serverPhoneNumbers.length ]
		i++

	length: () ->
		return @queue.length

###
# BROADCASTING METHODS
###

	sendMessageToAllUsers: (message) =>
		# Announce that server has rebooted
		for user in @queue
			
			place = @userPlaceInQueue(user)
			message = "
EC Roller Coaster queue server was restarted by WinterG.\n
The queue is now online. Your old place in line (\##{place}) has been restored."

			@messenger.sendMessageToUser(user, message)

	sendMessageToAllAdmins: (message) =>

		# Send messages to ops
		for op in @admins

			message = "
EC Roller Coaster queuing server restarted by WinterG.\n
The server is now online. All old places have been restored."
			
			@messenger.sendMessage(messageOptions).done(null,console.error)


###
# STATUS UPDATE FUNCTIONS
###

	# List the top 5 users in the queue
	getQueueData: () ->
		nextUsers = queue[0...5]
		returnString = ""
		letterIndex = null
		for user in nextUsers
			letterIndex = String.fromCharCode(97 + nextUsers.indexOf(user))
			returnString = "#{returnString}\n
#{letterIndex}). #{user.userName}"

		return returnString

	# Update the 5 people who are next in line.
	updateOperatorsAndUsers: () =>
		# Only update people if the queue has shifted.
		topQueue = queue[0...numberOfPeopletoUpdate]

		if _.difference(topQueue, @oldTopQueue).length isnt 0

			@oldTopQueue = topQueue

			# Update the users in the top of the queue
			for user in queue[0...numberOfPeopletoUpdate]
				
				# Make the message to send to the user

				# Find the user's place in the queue
				placeInQueue = userPlaceInQueue(user)
				# Find ETA
				ETA = placeInQueue * timeOfEachRide

				message = "
#{userName}, you are now \##{placeInQueue} in line.\r\n
ETA: #{ETA} minutes.\n
Please find an EC roller coaster op to get set up for your ride!\n
We are on the 2nd floor of the EC fort.\n
WARNING: If not present, you will be removed from the queue."

				@messenger.sendMessageToUser(user, message)

			# Update the operators
			for operator in admins
				message = "
Queue updated!\r\n
#{getQueueData()}\r\n
Type h for command help."
				@messenger.sendMessageToAdmin(operator, message)


module.exports = Queue

