#!/bin/bash

#
# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

#
# Builds the bot, intents, and custom slot types
#

#
# Environment variables to be set in the CodeBuild project
#
# $BOT			Name of the Lex bot
# $INTENTS      	List of intent names for the bot
# $TEMP_INTENT  	Temporary intent used when rebuilding the bot
# $SLOTS        	List of slot type names for the bot
# $LAMBDA       	Prefix for the name of the Lambda fulfillment function for the bot
# $LAMBDA_ROLE_NAME    	Name for the Lambda execution role
#

BOT="selfserve"
INTENTS="selfserve_account_balance_intent selfserve_fallback_intent selfserve_faq_intent selfserve_feedback_intent selfserve_get_user_phone selfserve_goodbye_intent selfserve_help_intent selfserve_order_checks_intent selfserve_speak_to_agent_intent selfserve_transfer_funds_intent"
TEMP_INTENT="selfserve_temporary_intent"
SLOTS="selfserve_account_type selfserve_question selfserve_topic selfserve_subtopic"
LAMBDA="selfserve"

# Backup the Lambda functions for each intent
for i in $INTENTS $TEMP_INTENT
do
    module_name=`echo $i | tr '[:upper:]' '[:lower:]'`
    echo -n "Backing up Lambda handler function: ${i}... "

    URL=`aws lambda get-function --function-name ${i} --query 'Code.Location' 2>/dev/null | sed 's/"//g'`
    if curl "${URL}" >backups/lambda/${i}.zip 2>/dev/null
    then echo "done"
    else echo "not found"
    fi
done

for i in $SLOTS
do
	echo -n "Backing up slot type: ${i}... "
	if aws lex-models get-slot-type --name $i --slot-type-version '$LATEST' >backups/slots/${i}.json 2>/dev/null
        then echo "done"
        else echo "not found"
        fi
done

for i in $INTENTS $TEMP_INTENT
do
	echo -n "Backing up intent: ${i}... "
	if aws lex-models get-intent --name $i --intent-version '$LATEST' >backups/intents/${i}.json 2>/dev/null
        then echo "done"
        else echo "not found"
        fi
done

echo -n "Backing up bot: ${BOT}... "
if aws lex-models get-bot --name ${BOT} --version-or-alias '$LATEST' >backups/bots/${BOT}.json 2>/dev/null
then echo "done"
else echo "not found"
fi

# BACKUP_FILE="backups-`date '+%Y-%m-%d-%H:%M:%S'`.tar" 
BACKUP_FILE="backups-`date '+%Y-%m-%d'`.tar" 
tar cvf ${BACKUP_FILE} ./backups ./*.md ./*.sh ./*.yml ./*.py ./*.txt ./LICENSE >/dev/null 2>&1
echo "Backup saved as ${BACKUP_FILE}"
