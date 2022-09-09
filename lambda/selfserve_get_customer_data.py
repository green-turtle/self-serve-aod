#
# Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

import logging
import json
import selfserve_config as config

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

def lambda_handler(event, context):
    logger.debug('lambda_handler: Lex event = ' + json.dumps(event))
    
    customer_key = 'n/a'
    if event.get('Details', False):
        if event['Details'].get('ContactData', False):
            if event['Details']['ContactData'].get('CustomerEndpoint', False):
                customer_key = event['Details']['ContactData']['CustomerEndpoint'].get('Address', 'n/a')
                
    customer_data = config.STUBBED_CUSTOMER_DIRECTORY.get(customer_key, {})

    for attribute in customer_data:
      if type(customer_data[attribute]) not in [str, float, int]:
        del customer_data[attribute]

    logger.debug('returned data = ' + json.dumps(customer_data))
    
    return customer_data
    

# sample input from Amazon Connect
'''
{
  "Details": {
    "ContactData": {
      "Attributes": {},
      "Channel": "VOICE",
      "ContactId": "82d2bd3e-592b-4eed-8783-32c12bc7fe32",
      "CustomerEndpoint": {
        "Address": "+18622683016",
        "Type": "TELEPHONE_NUMBER"
      },
      "InitialContactId": "82d2bd3e-592b-4eed-8783-32c12bc7fe32",
      "InitiationMethod": "INBOUND",
      "InstanceARN": "arn:aws:connect:us-east-1:687551564203:instance/6b93fff5-49b9-41d5-8026-b49a2e7e9858",
      "MediaStreams": {
        "Customer": {
          "Audio": "None"
        }
      },
      "PreviousContactId": "82d2bd3e-592b-4eed-8783-32c12bc7fe32",
      "Queue": "None",
      "SystemEndpoint": {
        "Address": "+18778405257",
        "Type": "TELEPHONE_NUMBER"
      }
    },
    "Parameters": {}
  },
  "Name": "ContactFlowEvent"
}
'''


