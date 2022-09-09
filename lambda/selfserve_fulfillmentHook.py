#
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
import boto3
import random
import decimal
import logging
import json
import re
import os

lexClient = boto3.client('lexv2-runtime')
lexModel = boto3.client('lexv2-models')

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

# --- Helpers that build all of the responses ---
def elicit_intent(intent, activeContexts, sessionAttributes, message, requestAttributes):
    return { 
        'messages': [message],
        'requestAttributes': requestAttributes,
        'sessionState': {
            'activeContexts': activeContexts,
            'intent': intent,
            'sessionAttributes': sessionAttributes,
            'dialogAction': {
                'type': 'ElicitIntent'
            }
        }
    }
    
def elicit_slot(intent, activeContexts, sessionAttributes, slot, message, requestAttributes):
    return { 
        'messages': [message],
        'requestAttributes': requestAttributes,
        'sessionState': {
            'activeContexts': activeContexts,
            'intent': intent,
            'sessionAttributes': sessionAttributes,
            'dialogAction': {
                'slotToElicit': slot,
                'type': 'ElicitSlot'
            }
        }
    }

def close(intent, activeContexts, sessionAttributes, message, requestAttributes):
    return { 
        'messages': [message],
        'requestAttributes': requestAttributes,
        'sessionState': {
            'activeContexts': activeContexts,
            'intent': intent,
            'sessionAttributes': sessionAttributes,
            'dialogAction': {
                'type': 'Close'
            }
        }
    }

def delegate(intent, activeContexts, sessionAttributes, messages, requestAttributes):
    return { 
        'messages': messages,
        'requestAttributes': requestAttributes,
        'sessionState': {
            'activeContexts': activeContexts,
            'intent': intent,
            'sessionAttributes': sessionAttributes,
            'dialogAction': {
                'type': 'Delegate'
            }
        }
    }
    
def confirm_intent(intent, activeContexts, sessionAttributes, message, requestAttributes):
    return { 
        'messages': [message],
        'requestAttributes': requestAttributes,
        'sessionState': {
            'activeContexts': activeContexts,
            'intent': intent,
            'sessionAttributes': sessionAttributes,
            'dialogAction': {
                'type': 'ConfirmIntent'
            }
        }
    }

def random_num():
    return(decimal.Decimal(random.randrange(1000, 50000))/100)

def get_slots(intent):
    return intent['slots']

def get_slot(intent, slotName):
    slots = get_slots(intent)
    if slots is not None and slots.get(slotName, None) and slots[slotName].get('value', None):
        return slots[slotName]['value'].get('interpretedValue', None)
    else:
        return None

def get_session_attributes(intent_request):
    sessionState = intent_request['sessionState']
    if 'sessionAttributes' in sessionState:
        return sessionState['sessionAttributes']

    return {}

def validate_ten_digit_number(value):
    logger.info('<validate_ten_digit_number>> value = {}'.format(value))
    ten_digits = re.match("[0-9]{10,20}", value)
    if not ten_digits:
        return False
    
    logger.info('<validate_ten_digit_number>> ten_digits = {}'.format(str(ten_digits)))
    logger.info('<validate_ten_digit_number>> value = {}, span = {}'.format(value, str(ten_digits.span())))
    
    if ten_digits.span()[1] != 10:
        return False

    return True

def get_bot_id(name, value, operator):
    botFound = False
    nextToken = None
    try:
        while botFound==False:
            if nextToken == None:
                resp = lexModel.list_bots(
                    filters=[
                        {
                            'name': name,
                            'values': [
                                value,
                            ],
                            'operator': operator
                        },
                    ]
                )
            else:
                resp = lexModel.list_bots(
                    filters=[
                        {
                            'name': name,
                            'values': [
                                value,
                            ],
                            'operator': operator
                        },
                    ],
                    nextToken=nextToken
                )            
            if (len(resp['botSummaries']) == 1):
                botId=resp['botSummaries'][0]['botId']
                print('Bot found. ID:', botId)
                botFound=True
                nextToken=None
                return botId
            elif (resp['nextToken']):
                nextToken = resp['nextToken']
            else:
                botFound=False
                return None

    except Exception as e:
            logger.error('Lex list bots call failed')
            logger.error(e)
        
        
def get_bot_aliasid(botId, aliasName):
    aliasFound = False
    nextToken = None
    try:
        while aliasFound==False:
            if nextToken == None:
                resp = lexModel.list_bot_aliases(
                    botId=botId
                )
            else:
                resp = lexModel.list_bot_aliases(
                    botId=botId,
                    nextToken=nextToken
                )  
            for a in resp['botAliasSummaries']:
                if (a['botAliasName'] == aliasName):
                    aliasId=a['botAliasId']
                    print('Alias found. ID:', aliasId)
                    aliasFound=True
                    return aliasId
            if (resp['nextToken']):
                nextToken = resp['nextToken']
            else:
                nextToken=None
                aliasFound=False
                return None
        
    except Exception as e:
        logger.error('Lex list bot aliases call failed')
        logger.error(e)  

#Validation handler
def validate_handler(intent, active_contexts, session_attributes, messages, requestAttributes):
    intent_name = intent.get('name', None)
    slots = intent.get('slots', None)
    logger.info('Validation: %s Slots: %s', intent_name, json.dumps(slots))
    logger.info('Validation: %s session attributes: %s', intent_name, session_attributes)
 
    #Process based on intent name. Change intent names to match your bot conifg.
    if (intent_name == 'OrderChecks'):
        #Verify the slot collected (a slot called number in this intent)
        if (not slots['phoneNumber']):
            #elicit slot
            if (not session_attributes.get('slotTry', None)):
                session_attributes['slotTry'] = '1'
            else:
                session_attributes['slotTry'] = int(session_attributes['slotTry']) + 1
            logger.info('Validation: %s Slot: phoneNumber attempt %d', intent_name, int(session_attributes['slotTry']))
            if (int(session_attributes['slotTry']) == 1):
                message = {
                    'contentType': 'PlainText',
                    'content': 'Please say or enter your 10-digit phone number.'
                }
            elif (int(session_attributes['slotTry']) == 2):

                message = {
                    'contentType': 'PlainText',
                    'content': 'I didn\'t get that, please say or enter your 10-digit phone number'
                }
            elif (int(session_attributes['slotTry']) == 3):
                message = {
                    'contentType': 'PlainText',
                    'content': 'Your phone number should include the area code, and be ten digits in length'
                }
            else:
                message = {
                    'contentType': 'PlainText',
                    'content': 'Sorry, was not able to understand your phone number.' + str(session_attributes['slotTry']) + ' slot tries.'
                }
                del session_attributes['slotTry']
                intent['state'] = 'Failed'
                return close(intent, active_contexts, session_attributes, message, requestAttributes)

                
            slotResult = elicit_slot(intent, active_contexts, session_attributes, 'phoneNumber', message, requestAttributes)
            logger.debug('Eliciting OrderChecks Slot Response %d: %s', int(session_attributes['slotTry']), json.dumps(slotResult))
            return slotResult
        else:
            if (validate_ten_digit_number(slots['phoneNumber']['value']['interpretedValue'])):
                #We have a valid value. Do more processing here as necessary.
                logger.debug('Delegating %s Slot Response', intent_name)
                if session_attributes.get('slotTry', None):
                    del session_attributes['slotTry']
                return delegate(intent, active_contexts, session_attributes, messages, requestAttributes)
            else:
                session_attributes['slotTry'] = int(session_attributes['slotTry']) + 1
                logger.info('Validation: %s Slot: phoneNumber attempt %d', intent_name, int(session_attributes['slotTry']))
                if (int(session_attributes['slotTry']) == 2):

                    message = {
                        'contentType': 'PlainText',
                        'content': 'I didn\'t get that, please say or enter your 10-digit phone number'
                    }
                elif (int(session_attributes['slotTry']) == 3):
                    message = {
                        'contentType': 'PlainText',
                        'content': 'Your phone number should include the area code, and be ten digits in length'
                    }
                else:
                    message = {
                        'contentType': 'PlainText',
                        'content': 'Sorry, was not able to understand your phone number.' + str(session_attributes['slotTry']) + ' slot tries.'
                    }
                    del session_attributes['slotTry']
                    intent['state'] = 'Failed'
                    return close(intent, active_contexts, session_attributes, message, requestAttributes)
                slotResult = elicit_slot(intent, active_contexts, session_attributes, 'phoneNumber', message, requestAttributes)
                logger.debug('Eliciting OrderChecks Slot Response %d: %s', int(session_attributes['slotTry']), json.dumps(slotResult))
                return slotResult

    elif (intent_name == 'Intent_2'):
        #Verify the slot collected (a slot called ball in this intent)
        if (not slots['ball']):
            #elicit slot
            message = {
                'contentType': 'PlainText',
                'content': 'What ball are you looking for?'
            }
            return elicit_slot(intent, active_contexts, session_attributes, 'ball', message, requestAttributes)
        else:
            #We have a value. Do more processing here as necessary. Return dialog control to the bot.
            return delegate(intent, active_contexts, session_attributes, messages, requestAttributes)

    else:
        message = {
            'contentType': 'PlainText',
            'content': 'Not a valid intent. Please verify bot configuration.'
        }
        intent['state'] = 'Failed'
        return close(intent, active_contexts, session_attributes, message, requestAttributes)

#Fulfillment handler
def fulfill_handler(intent, active_contexts, session_attributes, requestAttributes, inputTranscript, sessionId):
    qnabot_name = os.environ.get('QNABOT', None)
    qnabot_aliasname = os.environ.get('QNABOTALIAS', None)
    intent_name = intent.get('name', None)
    logger.info('Fulfillment: %s, %s', intent_name, json.dumps(intent))
    
    #example to setup a custom attribute.
    session_attributes['MyCustomAttr'] = 'BankerBot'

    #Intent based processing
    if (intent_name == 'FallbackIntent'):
        #Basic 3 retry logic when in the fallback intent. Adjust/remove as necessary.
        intent['state'] = 'InProgress'
        if (not session_attributes.get('botTry', None)):
            session_attributes['botTry'] = '1'
        else:
            session_attributes['botTry'] = int(session_attributes['botTry']) + 1

        if (int(session_attributes['botTry']) < 3):
            if (int(session_attributes['botTry']) == 1):
                message = {
                    'contentType': 'PlainText',
                    'content': 'Sorry, but I don\'t understand. Can you please repeat your response?'
                }
            elif (int(session_attributes['botTry']) == 2):
                message = {
                    'contentType': 'PlainText',
                    'content': 'I still don\'t understand. Can you please repeat your response once more?'
                }
            return elicit_intent(intent, active_contexts, session_attributes, message, requestAttributes)    
        else:
            intent['state'] = 'Failed'
            message = {
                'contentType': 'PlainText',
                'content': 'I\'m sorry, but I cannot help at this time.' + str(session_attributes['botTry']) + ' intent tries.'
            }
            del session_attributes['botTry']
            return close(intent, active_contexts, session_attributes, message, requestAttributes)
    elif (intent_name == 'CheckBalance') or (intent_name == "FollowupCheckBalance"):
        account = get_slot(intent, 'accountType')
        #The account balance in this case is a random number
        #Here is where you could query a system to get this information
        balance = str(random_num())
        text = "Thank you. The balance on your "+account+" account is $"+balance+" dollars."
        message =  {
                'contentType': 'PlainText',
                'content': text
            }
        intent['state'] = 'Fulfilled'
        return close(intent, active_contexts, session_attributes, message, requestAttributes)
    elif (intent_name == 'OrderChecks'):
        text = "Thank you. Checks will be shipped to the address on record."
        message =  {
                'contentType': 'PlainText',
                'content': text
            }
        intent['state'] = 'Fulfilled'
        return close(intent, active_contexts, session_attributes, message, requestAttributes)
    elif (intent_name == 'ApplyForALoan'):
        text = "Thank you. You'll get notifications in a week."
        message =  {
                'contentType': 'PlainText',
                'content': text
            }
        intent['state'] = 'Fulfilled'
        return close(intent, active_contexts, session_attributes, message, requestAttributes)
    elif (intent_name == "FAQ"):
        FAQ_DATA = {
            "loans": "You want information about loans.",
            "fees": "You want information about fees.",
            "deposits": "You want information about deposits.",
            "login": "I understand you are having trouble logging in. Let's get you to a live agent to help. Please click on the black menu icon above and select \"Start Live Chat\".",
        }

        user_question = ""

        topic = get_slot(intent, 'topic')
        if topic is not None:
            user_question += "question about " + topic + " "
        subtopic = get_slot(intent, 'subtopic')
        if subtopic is not None:
            user_question += subtopic + " "

        if len(user_question) == 0:
            user_question = inputTranscript

        if qnabot_name == "None":
            qnabot_name = None

        if qnabot_name != None:
            botId=get_bot_id('BotName', qnabot_name, 'EQ')
            if botId != None:
                aliasId=get_bot_aliasid(botId, qnabot_aliasname)
                if aliasId != None:
                    logger.debug('<<selfserve>> calling QnABot with input = {}'.format(user_question))

                    qna_bot_response = lexClient.recognize_text(
                        botId=botId,
                        botAliasId=aliasId,
                        localeId='en_US',
                        sessionId=sessionId,
                        text=user_question
                        )
                    logger.debug('<<selfserve>> faq_intent_handler: {} QnABot response = {}'.format(qnabot_name, json.dumps(qna_bot_response)))

                    message =  {
                            'contentType': 'PlainText',
                            'content': qna_bot_response.get('messages', {})[0].get('content', 'I did not receive a response from the Q&A bot')
                        }

                    logger.debug('<<selfserve>> message = {}'.format(message))
                    intent['state'] = qna_bot_response['sessionState'].get("intent", {}).get("state", {})
                    response = close(intent, active_contexts, session_attributes, message, requestAttributes)
                    logger.debug('<<selfserve>> faq_intent_handler: response = ' + json.dumps(response))
                    return response
                else:
                    response_string = FAQ_DATA.get(topic, None)
                    if response_string is None:
                        response_string = "Sorry, I didn't understand. Can you rephrase your question?"
                    message =  {
                            'contentType': 'PlainText',
                            'content': response_string
                        }
                    intent['state'] = 'Fulfilled'
                    return close(intent, active_contexts, session_attributes, message, requestAttributes)
            else:
                response_string = FAQ_DATA.get(topic, None)
                if response_string is None:
                    response_string = "Sorry, I didn't understand. Can you rephrase your question?"
                message =  {
                        'contentType': 'PlainText',
                        'content': response_string
                    }
                intent['state'] = 'Fulfilled'
                return close(intent, active_contexts, session_attributes, message, requestAttributes)
        else:
            response_string = FAQ_DATA.get(topic, None)
            if response_string is None:
                response_string = "Sorry, I didn't understand. Can you rephrase your question?"
            message =  {
                    'contentType': 'PlainText',
                    'content': response_string
                }
            intent['state'] = 'Fulfilled'
            return close(intent, active_contexts, session_attributes, message, requestAttributes)
    else:
        #All other intents.
        #Confirm intent example
        if (intent['confirmationState'] == 'None'):
            intent['state'] = 'Fulfilled'
            message = {
                'contentType': 'PlainText',
                'content': 'Are you sure?'
            }
            return confirm_intent(intent, active_contexts, session_attributes, message, requestAttributes)
            
        elif (intent['confirmationState'] == 'Denied'):
            #User said no to confirmation. Adjust this to meet your need.
            intent['state'] = 'Failed'
            message = {
                'contentType': 'PlainText',
                'content': 'This is the fulfillment lambda close for ' + intent_name + ' confirmation failed.'
            }
            return close(intent, active_contexts, session_attributes, message, requestAttributes)
            
        else:
            #User confirmed intent
            intent['state'] = 'Fulfilled'
            #Adjust message to meet your need.
            message = {
                'contentType': 'PlainText',
                'content': 'This is the fulfillment lambda close for ' + intent_name + ' user confirmed.'
            }
            return close(intent, active_contexts, session_attributes, message, requestAttributes)    

def lambda_handler(event, context):
    logger.info('Lex Event: %s', json.dumps(event))
    
    #SessionState    
    session_attributes = event['sessionState'].get("sessionAttributes", {})
    intent = event['sessionState'].get("intent", {})
    active_contexts = event['sessionState'].get("activeContexts", [])
    
    #Messages
    messages = event.get("messages", [])

    #Input Transcript    
    inputTranscript = event.get("inputTranscript", "")

    #Session ID
    sessionId = event.get("sessionId", "")

    #Request Attributes
    requestAttributes = event.get("requestAttributes", {})

    #Process based on source
    if ( event['invocationSource'] == 'DialogCodeHook'):
        return validate_handler(intent, active_contexts, session_attributes, messages, requestAttributes)    

    elif (event['invocationSource'] == 'FulfillmentCodeHook'):
        return fulfill_handler(intent, active_contexts, session_attributes, requestAttributes, inputTranscript, sessionId) 

    else:
        logger.info('Event Error: %s', json.dumps(event))
