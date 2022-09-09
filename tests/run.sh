#!/bin/bash

#
# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
# runs test scripts from a .CSV file
#

# Environment variables to be set in the CodeBuild project, or in your environment
#
# $BOT			Name of the Lex bot
# $BOT_ALIAS      	Name of the Lex bot alias to test
#

# set -x

bot="${BOT}"
bot_alias="${BOT_ALIAS}"
input_file="test_cases.csv"
results_file="test_output.csv"
echo "Results File = $results_file"

echo -e 'Test Case,Step,Utterance,Expected Response,Expected Intent,Expected State,Actual Response,Actual Intent,Actual State,Result' >"${results_file}"

total_tests=0
failed_tests=0

# Get the Bot ID from the name

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
while [ "$NEXT_TOKEN" != "null" ]; do
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
        echo " Bot ${bot} import complete with BotID=${BotID}"

        # Get the Bot Alias ID
        BotAliasID=`aws lexv2-models list-bot-aliases --bot-id ${BotID} | jq '.botAliasSummaries[] | select(.botAliasName == "test").botAliasId' | sed -e 's/^"//' -e 's/"$//'` >/dev/null 2>&1
        echo " Bot Alias ID : ${BotAliasID}"

        while read p;  
        do 
            test_case=`echo $p | sed 's/\([^,]*\),.*/\1/'`

            if [ "${test_case}" = "Test Case" ]
            then 
                continue
            elif [ "${test_case}" = "<end>" ]
            then
                break
            fi

            if [ "$1" ] 
            then 
                if [ "${test_case}" -gt "$1" ] 
                then
                    break
                elif [ "${test_case}" -ne "$1" ]
                then
                    continue
                fi
            fi

            # temporarily substitute , characters between quotes with {comma}
            while  echo $p | grep '"[^",][^",]*,' >/dev/null 2>&1
            do
                p=`echo $p | sed 's/"\([^",][^",]*\),\(.*\)"/"\1{comma}\2"/g'`
            done
            p=`echo $p | sed 's/"//g'`

            step=`echo $p | sed 's/\([^,]*\),\([^,]*\),.*/\2/' | sed 's/{comma}/,/g'`
            utterance=`echo $p | sed 's/\([^,]*\),\([^,]*\),\([^,]*\),.*/\3/' | sed 's/{comma}/,/g'`
            # The last part of this command is probably sufficient for a single KVP only, need to update if a map is needed
            session_attributes=`echo $p | sed 's/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),.*/\4/' | sed 's/{comma}/,/g' | sed 's/^/{"/;s/$/"}/;s/:/":"/'`
            expected_response=`echo $p | sed 's/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),.*/\5/' | sed 's/{comma}/,/g'`
            expected_intent=`echo $p | sed 's/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),.*/\6/' | sed 's/{comma}/,/g'`
            expected_state=`echo $p | sed 's/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\).*/\7/' | sed 's/{comma}/,/g' | tr -d '[:cntrl:]'`

            test_case_formatted=$(printf "%03d" $test_case)
            step_formatted=$(printf "%02d" $step)
            utterance_formatted=`echo ${utterance} | cut -c1-35`
            utterance_formatted=`printf '%-35s' "${utterance_formatted}"`
            expected_response_formatted=`echo ${expected_response} | cut -c1-55`
            expected_response_formatted=`printf '%-55s' "${expected_response_formatted}"`

            echo -n "Running test case: ${test_case_formatted}-${step_formatted}: [${utterance_formatted}] - expecting: [${expected_response_formatted}]  "

            # --for testing--
            echo "Test Case:          " ${test_case}
            echo "Step:               " ${step}
            echo "Utterance:          " ${utterance}
            echo "Session Attributes: " ${session_attributes}
            echo "Expected Response:  " ${expected_response}
            echo "Expected Intent:    " ${expected_intent}
            echo "Expected State:     " ${expected_state}

            if [ "${session_attributes}" = "" ]
            then SESSION_ATTRIBUTES=" "
            else SESSION_ATTRIBUTES=" --request-attributes ${session_attributes}"
            fi

            if [ ${step_formatted} = "01" ]
            then
                # set initial session attributes from test cases
                aws lexv2-runtime delete-session --bot-id "${BotID}" --bot-alias-id "${BotAliasID}" --session-id "test-user-${test_case_formatted}" --locale-id "en_US" >/dev/null 2>&1
                test_result=`aws lexv2-runtime recognize-text --bot-id "${BotID}" \
                                --bot-alias-id "${BotAliasID}" \
                                --session-id "test-user-${test_case_formatted}" \
                                --locale-id "en_US" \
                                ${SESSION_ATTRIBUTES} \
                                --text "${utterance}"`
            else
                # do not modify session attributes > step 01
                test_result=`aws lexv2-runtime recognize-text --bot-id "${BotID}" \
                                --bot-alias-id "${BotAliasID}" \
                                --session-id "test-user-${test_case_formatted}" \
                                --locale-id "en_US" \
                                --text "${utterance}"`
            fi
        
            test_result=`echo "${test_result}" | sed 's/\\\"//g'`

            # --for testing--
            # echo; echo "test result = >${test_result}<"

            actual_response=`echo ${test_result} | jq '.messages[0].content' | sed -e 's/^"//' -e 's/"$//'`
            actual_intent=`echo ${test_result} | jq '.sessionState.intent.name' | sed -e 's/^"//' -e 's/"$//'`
            actual_state=`echo ${test_result} | jq '.sessionState.dialogAction.type' | sed -e 's/^"//' -e 's/"$//'`

            # --for testing--
            echo "Actual Response:    " ${actual_response}
            echo "Actual Intent:      " ${actual_intent}
            echo "Actual State:       " ${actual_state}

            total_tests=$((total_tests+1))

            if ! expr "${actual_response}" : "${expected_response}" >/dev/null
            then 
                result="FAILURE (response)"
                echo "FAILURE (wrong response: ${actual_response})"
                failed_tests=$((failed_tests+1))
            elif ! expr "${actual_intent}" : "${expected_intent}" >/dev/null
            then 
                result="FAILURE (intent)"
                echo "FAILURE (wrong intent: ${expected_intent}/${actual_intent})"
                failed_tests=$((failed_tests+1))
            elif ! expr "${actual_state}" : "${expected_state}" >/dev/null
            then 
                result="FAILURE (state)"
                echo "FAILURE (wrong state: ${expected_state}/${actual_state})"
                failed_tests=$((failed_tests+1))
            else
                result="SUCCESS"; echo ${result}
            fi

            # echo; echo "actual response =   >${actual_response}<"; echo "expected response = >${expected_response}<"; echo

            echo -e "\"${test_case}\",\"${step}\",\"${utterance}\",\"${expected_response}\",\"${expected_intent}\",\"${expected_state}\",${test_result},${result}" >>"${results_file}"

        done < ${input_file}
    else
        echo "Bot ${BOT} not found."
    fi
done
echo "checking overall test status..."

if [ ${failed_tests} -gt 0 ] 
then
    echo "ERROR: ${failed_tests} out of ${total_tests} test(s) failed."
    exit 1
else
    echo "All ${total_tests} test(s) passed."
    exit 0
fi