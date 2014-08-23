# Roller Coaster Queuing Program.
# By Winter Guerra. August 20th, 2014. CC-BY-SA 3.0.

# This program will advertise a phone number that people can text with their name.
# Once received, the name and number is entered into a FIFO queue.
# Every few minutes, the roller coaster operator should text the number with "next" to get the queue to move along.
# The program will respond to the operator with an updated list truncated to 5 people.
# Then, the program will respond to the 3 people in the front of the FIFO queue. 

twilio = require('twilio')
fs = require 'fs-extra'

# Initialize Twilio API
{accountSid, authToken, serverPhoneNumber} = fs.readJsonSync('./twilio_account_info.json')

client = new twilio.RestClient(accountSid, authToken)

# ## Default Admin Numbers

admins = [
	'9174357128', # Winter
	'9073472182', # Jaguar
]



messageOptions = {
    to:'+19174357128',
    from: serverPhoneNumber,
    body:'This is a test of the TXT messaging capability of Twilio.'
}

client.messages.create messageOptions, (error, message) ->
    if error
        console.log(error.message)

