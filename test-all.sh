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

# Environment variables
# S3_BUCKET - location to upload the test run results file (.CSV)
#

# run tests
DATE_TIME=`TZ=America/New_York date '+%Y-%m-%d-%H:%M'`
OUTPUT_FILE="test-run-${DATE_TIME}.csv"
cd tests
bash run.sh; exit_status=$?
mv test_output.csv ${OUTPUT_FILE}
ls -l ${OUTPUT_FILE}
aws s3 cp "${OUTPUT_FILE}" "s3://${S3_BUCKET}"
cd ..

exit ${exit_status} 
