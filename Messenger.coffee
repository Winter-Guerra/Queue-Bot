# Messenger Class

twilio = require('twilio')
fs = require 'fs-extra'

class Messenger 

	constructor: () ->
		# Read the config file,
		{accountSid, authToken, serverPhoneNumbers} = fs.readJsonSync('./twilio_account_info.json')
		# Create the client
		@client = new twilio.RestClient(accountSid, authToken)

	sendMessageToUser: (user, message) =>

		{phoneNumber, userName, returnPhoneNumber} = user

		if phoneNumber

			# Find the user's place in the queue
			messageOptions = 
				to: phoneNumber
				from: returnPhoneNumber
				body: message

			@client.sendMessage(messageOptions).done(null,console.error)

	sendMessageToAdmin: (admin, message) =>

		messageOptions = 
			to: admin
			from: serverPhoneNumbers[0]
			body: message

		client.sendMessage(messageOptions).done(null,console.error)

	makeReply: (message) =>
		resp = new twilio.TwimlResponse()
		if message?
			resp.message message
		return resp.toString()

module.exports = Messenger