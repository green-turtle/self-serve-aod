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
# Environment variables to be set in the CodeBuild project
# $LAMBDAS      	???
# $LAMBDA_ROLE_NAME    	Name for the Lambda execution role
#

LAMBDAS="selfserve_fulfillmentHook selfserve_get_customer_data"
# LAMBDA_ROLE_NAME="selfserve_role"
# 
# LAMBDA_ROLE_ARN=`aws iam get-role --role-name ${LAMBDA_ROLE_NAME} | grep 'Arn' | sed 's/.*"Arn": "\(.*\)".*/\1/'`
# echo "Lambda execution role = $LAMBDA_ROLE_ARN"

for i in ${LAMBDAS}
do
    # module_name=`echo $i | tr '[:upper:]' '[:lower:]'`

    cd lambda
    python zip.py ${i}.zip ${i}.py selfserve_config.py >/dev/null
    cd ..

    if aws lambda get-function --function-name ${i} >/dev/null
    then
        echo -n "Updating Lambda function: ${i} from ${i}.py... "
        if aws lambda update-function-code \
               --function-name ${i} \
               --zip-file fileb://lambda/${i}.zip \
               >/dev/null
        then echo "done"
        else echo "failed"
        fi
        if aws lambda wait function-updated-v2 --function-name ${i} >/dev/null
            then
                echo -n "Updating Lambda configuration: ${i}... "
                if aws lambda update-function-configuration \
                    --function-name ${i} \
                    --description "${i} function" \
                    --environment Variables="{QNABOT=$QNABOT,QNABOTALIAS=$QNABOTALIAS}" \
                    --role $LAMBDA_ROLE_ARN \
                    >/dev/null
                then echo "done"
                else echo "failed"
                fi
            else echo "Error: Function ${i} not updated"; exit 1
        fi
    else
        echo -n "Creating Lambda function: ${i} from ${i}.py... "
        if aws lambda create-function \
               --function-name ${i} \
               --description "${i} function" \
               --timeout 300 \
               --zip-file fileb://lambda/${i}.zip \
               --role $LAMBDA_ROLE_ARN \
               --environment Variables="{QNABOT=$QNABOT,QNABOTALIAS=$QNABOTALIAS}" \
               --handler ${i}.lambda_handler \
               --runtime python3.8 \
               >/dev/null
        then echo "done"
        else echo "failed"
        fi
    fi

    rm lambda/${i}.zip

done

