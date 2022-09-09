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
# Deletes the bot
#

#
# Environment variables to be set in the CodeBuild project
#
# $BOT		Name of the Lex bot
# $INTENTS      List of intent names for the bot
# $TEMP_INTENT  Temporary intent used when rebuilding the bot
# $SLOTS        List of slot type names for the bot
#

# set -x

SLEEP=1
DELETE_BOT="no"

# The below command is the one being executed and should be adapted appropriately.
# Note that the max items may need adjusting depending on how many results are returned.
aws_command="aws lexv2-models list-bots --filters name=\"BotName\",values=${BOT},operator=\"EQ\""
#aws_command="aws lexv2-models list-bots"
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

echo -n "Checking for existing bot ${BOT}... "

# The below while loop runs until either the command errors due to throttling or
# comes back with a pagination token.
while [ "$NEXT_TOKEN" != "null" ] && [ "$DELETE_BOT" != "yes" ]; do
  if [ "$NEXT_TOKEN" == "null" ] || [ -z "$NEXT_TOKEN" ] ; then
    echo "now running: $aws_command "
    cli_output=$($aws_command)
    parse_output
  else
    echo "now paginating: $aws_command --next-token $NEXT_TOKEN"
    cli_output=$($aws_command --next-token $NEXT_TOKEN)
    parse_output
  fi

  if [ -n "${BotID}" ]
    then
        echo "Deleting bot ${BotID}"
        DELETE_BOT="yes"
        if aws lexv2-models delete-bot --bot-id $BotID >/dev/null
        then
            echo "Bot deleting..."
            sleep 30
        else echo "Bot delete failed"; exit 1
        fi
    else
        echo "Still searching..."
    fi
done  #pagination loop
echo "Pagination loop completed."