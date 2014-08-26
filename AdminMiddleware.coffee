# Admin Controller for Queue

Messenger = require './Messenger'

class AdminMiddleware
	# Is given a server and a queue Object
	constructor: (@server, @queue) ->

		@messenger = new Messenger

	# Tell the user that they have been removed from the queue
	sendRemovalMsgToUser = (user) ->
		if user
			{phoneNumber, userName, returnPhoneNumber} = user

			message = "
#{userName}, you've been removed from the queue!\r\n
Tell ops if you think this has been a mistake.\r\n
Else, txt your kerberos to this # to ride again!
"
			@messenger.sendMessageToUser(user, message)

	handle = (req, res, next) =>

		{phoneNumber, body, isAdmin} = req

		user = 
			phoneNumber: phoneNumber

		if not req.isAdmin
			next()
			return
			
		else
			console.log "Admin command"

# Check which command the admin commanded us to do
# Valid commands are:
	# r = remove from list
	# i = insert to end of list
	# n = next
	# l = list queue
	# h = help
	# remove admin = remove current phone number from admin list

			# Check for "Remove Admin"
			if (/remove admin/i).test(req.body)
				console.log "->Remove admin"
				# Remove admin from the list
				index = @server.admins.indexOf user.phoneNumber
				@server.admins.splice(index,1)
				res.send @messenger.makeReply "Admin #{user.phoneNumber} removed from admin list."

			# Check for one-char commands
			command = body[0]

			switch command
				# Shifting the Queue along
				when 'n', 'N'
					console.log "->next"
					if @queue.length > 0
						user = @queue.queue.shift()

					res.send @messenger.makeReply()

					# Send updates to the operators and the users in the queue
					@queue.updateOperatorsAndUsers()

					# Send text to the person who has been removed from the queue
					@sendRemovalMsgToUser(user)
					return

				# Removing a person
				when 'r', 'R'
					console.log "->Remove person"
					
					name = body.match(/([a-zA-Z]+)/g)[1] # Grab the second argument given

					if not name or name.length isnt 1
						res.send @messenger.makeReply "ERROR: Supply an queue index to delete. I.E. 'r b'"
						return

					# Map the letter to a zero indexed number
					queueIndex = (name.charCodeAt(0) - 97)
					user = @queue.queue.splice(queueIndex,1)[0]
					
					# Send empty response
					response.send @messenger.makeReply()

					# Send updates to the operators and the users in the queue
					@queue.updateOperatorsAndUsers()

					# Send text to the person who has been removed from the queue
					@sendRemovalMsgToUser(user)
					return

				# Adding a person's kerberos
				when 'i', 'I'

					userName = body.match(/([a-zA-Z]+)/g)[1]

					console.log "->insert person #{userName}"

					queuedUser =
						userName: userName.concat('* No cell')
						phoneNumber: null # user does not have a phone number

					queuedUser = @queue.resolveUser(queuedUser)


					queue.addUser queuedUser

					# Send response
					ETA = @queue.length * @server.timeOfEachRide

					
					res.send @messenger.makeReply "
#{userName} is now in line.\n
Current position: #{queue.length}.\n
ETA: #{ETA} minutes.\n
BRING A CELLPHONE NEXT TIME!\n
We will NOT text you when it is your turn.\n
You will also NOT be able to check your ETA until you are in the top of the queue.\n
WARNING: If not present, you will be removed from the queue.\n
Meet at the 2nd floor of the EC fort near the entrance stairs when it is your turn.
"

					# Send updates to the operators and the users in the queue
					@queue.updateOperatorsAndUsers()

					return

				when 'l', 'L'
					console.log "->List queue"
					
					unless (queue.length > 0)
						console.log "Queue is empty"
						res.send @messenger.makeReply "Queue is empty"
						return

					# list people in queue
					res.send @messenger.makeReply "Queue:
#{getQueueData()}\n
Type h for command help."
					
					return

				when 'h', 'H'
					console.log "->show help"
					# List commands
					res.send @messenger.makeReply "
		Commands:\n
		n = next\n
		l = list queue\n
		r n = remove nth person from list where n = a,b,c,d\n
		i name = insert name to end of list\n 
		h = help\n
		remove admin = remove current phone from admin list\n
		add admin = add current phone to admin list"
					return

				else
					console.log "->Unrecognzed command"
					
					res.send @messenger.makeReply "Unrecognized admin command. Use 'h' to fetch the list of possible commands."


module.exports = AdminMiddleware