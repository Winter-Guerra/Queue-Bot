# User Middleware

Messenger = require './Messenger'

class UserMiddleware
	
	# Is given a server and a queue Object
	constructor: (@server, @queue) ->

		@messenger = new Messenger

	# Will check if this middleware can handle the request
	handle: (req, res, next) ->

		{phoneNumber, body, isAdmin} = req
		
		user = 
			phoneNumber: phoneNumber

		console.log "Regular user command!"

# ADD USER TO ADMINS

		# Check if we should add this user to list of admins
		if (/add admin/i).test(body)
			if userPhoneNumber not in @server.admins
			@server.admins.push userPhoneNumber
		
			@messenger.makeReply "#{userPhoneNumber} Added to list of admins."
			return

# CHECK THAT USER IS IN QUEUE

		place = @queue.userPlaceInQueue(user)
		if place isnt null
			console.log "User has existing place in queue: ", place
			ETA = place * @server.timeOfEachRide
			response.send @messenger.makeReply "
You are already in line @ #{place}.\r\n
ETA: #{ETA} mins\r\n
Please wait before re-adding yourself.\r\n
Std msg rates apply. Don't be dumbfuckers!
"
			return

# ADD NEW USER TO QUEUE
		else
			_this = this
			console.log "->Add person to queue."
			user = @queue.resolveUser(user)
			@queue.addUser(user)

			ETA = @queue.length * @server.timeOfEachRide

			# Only confirm addition if the person is NOT at front of line. Otherwise, they will already get an update after they add themselves to the queue.
			if queue.length > numberOfPeopletoUpdate

				res.send @messenger.makeReply "
#{user.userName} is now in line.\n
Current position: #{_this.queue.length}.\n
ETA: #{ETA} minutes.\n
We'll txt you when you can ride the EC roller coaster.\n
WARNING: If not present, you will be removed from the queue.\n
Check your ETA by texting us your kerberos again.\n
Std msg rates apply.
"
			# Send updates to the operators and the users in the queue
			@queue.updateOperatorsAndUsers()
			return


	

module.exports = UserMiddleware