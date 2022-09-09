#!/bin/bash

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

#
# Imports the bot, including intents, and custom slot types and slots
#

#
# Environment variables to be set in the CodeBuild project
#
# $BOT			Name of the Lex bot
# $INTENTS      	List of intent names for the bot
# $TEMP_INTENT  	Temporary intent used when rebuilding the bot
# $SLOTS        	List of slot type names for the bot
# $LAMBDA_ROLE_NAME    	Name for the Lambda execution role
#

## DELETE THESE
## BOT="selfserve"
## BOT_ALIAS="test"
## INTENTS="selfserve_account_balance_intent selfserve_goodbye_intent selfserve_help_intent selfserve_speak_to_agent_intent selfserve_transfer_funds_intent"
## TEMP_INTENT="selfserve_temporary_intent"
## SLOTS="selfserve_account_type"
## LAMBDA_ROLE_NAME="selfserve_role"
## 
## # get the Lambda execution role ARN
## LAMBDA_ROLE_ARN=`aws iam get-role --role-name ${LAMBDA_ROLE_NAME} | grep 'Arn' | sed 's/.*"Arn": "\(.*\)".*/\1/'`
## echo "Lambda execution role = $LAMBDA_ROLE_ARN"
##
## ## replace with local Lex conversation logs log-group ARN ##
## # BOT_LOG_GROUP_ARN=arn:aws:logs:us-east-1:687551564203:log-group:chatops_lex_logs:*
##
## ## replace with local Lex conversation logs log-group IAM role ##
## # BOT_LOG_GROUP_ROLE_ARN=arn:aws:iam::687551564203:role/chatops-conversation-logs-r-LexConversationLogsRole-SA11A5VL6BK1

# temporary override
#BOT_LOG_GROUP_ARN=""
#BOT_LOG_GROUP_ROLE_ARN=""

# set -x

VERSION_CREATED="no"

if aws lex-models get-intent --name $TEMP_INTENT --intent-version '$LATEST' >/dev/null 2>&1
then LIST_OF_INTENTS="$INTENTS"
else LIST_OF_INTENTS="$INTENTS $TEMP_INTENT"
fi

echo " Intents: ${LIST_OF_INTENTS}"
echo " Slots: ${SLOTS}"
echo " BOT: ${BOT}"

echo "Creating Upload URL..."
result=$(aws lexv2-models create-upload-url --output text)

results=(${result//'\n'/ })
importID=${results[0]}
uploadUrl=${results[1]}

echo " Import ID: ${importID}"
echo " Upload URL: ${uploadUrl}"

echo "Zipping up banker bot for upload..."
zip -r bankerbot.zip bankerbot >/dev/null

echo "Uploading bot..."
curl -X PUT --data-binary @bankerbot.zip ${uploadUrl}

sed -i "s|BOT_BUILDER_ROLE|$BOT_BUILDER_ROLE|" startImport-resourceSpecification.json
echo "Starting bot import..."
aws lexv2-models start-import --import-id ${importID} --merge-strategy FailOnConflict --resource-specification file://startImport-resourceSpecification.json >/dev/null
echo "start-import command issued..."
if aws lexv2-models wait bot-import-completed --import-id ${importID} >/dev/null
    then
        echo "bot-import completed..."
        # The below command is the one being executed and should be adapted appropriately.
        # Note that the max items may need adjusting depending on how many results are returned.
        list_bots_command="aws lexv2-models list-bots --filters name=\"BotName\",values=${BOT},operator=\"EQ\""
        unset NEXT_TOKEN

        function parse_output() {
            if [ ! -z "$cli_output" ]; then
                if [ $(echo $cli_output | jq '.botSummaries | length') -ne 0 ]; then
                    echo "Found bot, getting id"
                    # The output parsing below also needs to be adapted as needed.
                    BotID=$(echo $cli_output | jq .botSummaries[0].botId | tr -d '"')
                    echo -n `BotID=${BotID}`
                fi
                NEXT_TOKEN=$(echo $cli_output | jq -r ".nextToken")
            fi
        }

        # The below while loop runs until either the command errors due to throttling or
        # comes back with a pagination token.
        while [ "$NEXT_TOKEN" != "null" ] && [ "$VERSION_CREATED" != "yes" ]; do
            if [ "$NEXT_TOKEN" == "null" ] || [ -z "$NEXT_TOKEN" ] ; then
                echo "now running: $list_bots_command "
                cli_output=$($list_bots_command)
                parse_output
            else
                echo "now paginating: $list_bots_command --next-token $NEXT_TOKEN"
                cli_output=$($list_bots_command --next-token $NEXT_TOKEN)
                parse_output
            fi

        if [ -n "${BotID}" ]
            then
                echo " Bot ${BOT} import complete with BotID=${BotID}"

                echo "Building DRAFT locale for en_US"
                if aws lexv2-models build-bot-locale --bot-id ${BotID} --bot-version DRAFT --locale-id en_US >/dev/null
                    then
                        echo "Creating Version 1..."
                        BOT_VERSION=`aws lexv2-models create-bot-version --bot-id ${BotID} --bot-version-locale-specification file://createBotVersion-botVersionLocaleSpecification.json | grep botVersion\" | sed 's/.*botVersion\"\: \"\([0-9]*\)".*/\1/'`
                        if [ -n "${BOT_VERSION}" ]
                            then 
                                VERSION_CREATED="yes"
                                if aws lexv2-models wait bot-version-available --bot-id ${BotID} --bot-version ${BOT_VERSION} >/dev/null
                                    then
                                        echo "Creating bot alias ${BOT_ALIAS}..."
                                        echo " BOT_VERSION=${BOT_VERSION}"

                                        sed -i "s|replaceme|$BOT_LOG_GROUP_ARN|" createBotAlias-conversationLogSettings.json
                                        lambdaARN=`aws lambda get-function --function-name selfserve_fulfillmentHook | grep FunctionArn | sed 's/.*FunctionArn\"\: \"\(.*\)".*/\1/'`
                                        if [ -n "${lambdaARN}" ]
                                            then
                                                echo " Lambda ARN=${lambdaARN}"
                                                sed -i "s|replaceme|$lambdaARN|" createBotAlias-botAliasLocaleSettings.json
                                                echo "Creating bot alias ${BOT_ALIAS}"
                                                BOT_ALIAS_ID=`aws lexv2-models create-bot-alias --bot-alias-name ${BOT_ALIAS} --bot-id ${BotID} --bot-version ${BOT_VERSION} --conversation-log-settings file://createBotAlias-conversationLogSettings.json --bot-alias-locale-settings file://createBotAlias-botAliasLocaleSettings.json | grep botAliasId | sed 's/.*botAliasId\"\: \"\([0-9A-Z]*\)".*/\1/'`
                                                if [ -n "${BOT_ALIAS_ID}" ]
                                                    then
                                                        if aws lexv2-models wait bot-alias-available --bot-id ${BotID} --bot-alias-id ${BOT_ALIAS_ID} >/dev/null
                                                            then 
                                                                echo " Created bot version ${BOT_VERSION}, alias ${BOT_ALIAS}, alias ID ${BOT_ALIAS_ID}"
                                                                echo "Updating lambda permissions..."
                                                                statementId="lexv2-lambda-invokeFunction-${BotID}-${BOT_ALIAS_ID}"
                                                                echo " StatementID: ${statementId}"
                                                                echo " Region: ${AWS_REGION}"
                                                                myAccount=`aws sts get-caller-identity | grep Account | sed 's/.*Account\"\: \"\(.*\)".*/\1/'`
                                                                echo " Account: ${myAccount}"
                                                                sourceARN="arn:aws:lex:${AWS_REGION}:${myAccount}:bot-alias/${BotID}/${BOT_ALIAS_ID}"
                                                                echo " SourceARN: ${sourceARN}"
                                                                if aws lambda add-permission --function-name ${lambdaARN} --statement-id ${statementId} --action lambda:InvokeFunction --principal lexv2.amazonaws.com --source-arn ${sourceARN} >/dev/null
                                                                    then echo " Lambda permissions updated"
                                                                    else echo " Error: ${BOT} Lambda permissions failed to update"
                                                                fi
                                                            else echo "Error: ${BOT} bot alias creation failed, check the log for errors"; exit 1
                                                        fi
                                                    else echo "Error: ${BOT} alias ${BOT_ALIAS} failed to create"; exit 1
                                                fi
                                            else echo "Error: ${BOT} unable to get ARN for function selfserve_fulfillmentHook"; exit 1
                                        fi
                                    else echo "Error: ${BOT} version ${BOT_VERSION} not available"; exit 1
                                fi
                            else echo "Error: ${BOT} bot version ${BOT_VERSION} creation failed, check the log for errors"; exit 1
                        fi
                    else echo "Error: ${BOT} failed to build locale"; exit 1
                fi
            else
                echo "Still searching..."
            fi
        done  #pagination loop
        if [ "$VERSION_CREATED" == "yes" ]
            then 
                echo "Pagination loop completed."
            else 
                echo "Imported Bot not found..."
        fi
    else "Error: ${BOT} failed to import"; exit 1
fi
