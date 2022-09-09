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

STUBBED_CUSTOMER_DIRECTORY = {
    '+13018732558': {
		'firstName': 'Yean', 
        'fullName': 'Wang', 
        'address': '333 Test Street, Anytown, USA 56788', 
        'customerTier': 'Gold',
        'accounts': [
            { 'account_number': '323233389', 'account_name': 'Checking', 'balance': 333.33 },
            { 'account_number': '323233389', 'account_name': 'Savings', 'balance': 5899.99 },
            { 'account_number': '323233389', 'account_name': 'Investments', 'balance': 398989.88 }
        ]
    },    '+12015550123': {
		'firstName': 'Diego', 
        'fullName': 'Diego Ramirez', 
        'address': '555 Test Street, Anytown, USA 12345', 
        'customerTier': 'Gold',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Checking', 'balance': 294.05 },
            { 'account_number': '123456789', 'account_name': 'Savings', 'balance': 4025.12 },
            { 'account_number': '123456789', 'account_name': 'Investments', 'balance': 32015.50 },
            { 'account_number': '123456789', 'account_name': 'Mortgage', 'balance': 224560.75 }
        ]
    },
    '+12125550123': {
        'firstName': 'John', 
        'fullName': 'John Doe', 
        'address': '1234 Main Street, Anytown, USA 12345', 
        'customerTier': 'Platinum Plus',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Savings', 'balance': 2019.20 }
        ]
    },
    '+14085550123': {
        'firstName': 'Mary', 
        'fullName': 'Mary Major', 
        'address': '1234 First Avenue, Anytown, USA 12345', 
        'customerTier': 'Platinum Plus',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Checking', 'balance': 524.04 },
            { 'account_number': '123456789', 'account_name': 'Savings', 'balance': 5212.51 },
            { 'account_number': '123456789', 'account_name': 'Line of Credit', 'balance': 12015.50 },
            { 'account_number': '123456789', 'account_name': 'Personal Loan', 'balance': 33210.11 }
        ]
    },
    '+19085550123': {
        'firstName': 'Richard', 
        'fullName': 'Richard Roe', 
        'address': '4848 Broadway, Anytown, USA 12345', 
        'customerTier': 'Platinum Plus',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Checking', 'balance': 524.04 },
            { 'account_number': '123456789', 'account_name': 'Savings', 'balance': 5212.51 },
            { 'account_number': '123456789', 'account_name': 'Personal Loan', 'balance': 33210.11 }
        ]
    },
    '+18625550123': {
        'firstName': 'Ana Carolina', 
        'fullName': 'Ana Carolina Silva', 
        'address': '4760 Riverside Ave, Anytown, USA 12345', 
        'customerTier': 'Platinum',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Checking', 'balance': 521.33 },
            { 'account_number': '123456789', 'account_name': 'Savings', 'balance': 5001.23 },
            { 'account_number': '123456789', 'account_name': 'Line of Credit', 'balance': 33210.11 }
        ]
    },
    '+19735550123': {
        'firstName': 'Susan', 
        'fullName': 'John Stiles', 
        'address': '100-B Front Street, Anytown, USA 12345', 
        'customerTier': 'Gold',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Checking', 'balance': 1204.21 }
        ]        
    },
    '+15165550123': {
        'firstName': 'Nikki', 
        'fullName': 'Nikki Wolf', 
        'address': '205 Sunnyvale Ave, Anytown, USA 12345', 
        'customerTier': 'Gold',
        'accounts': [
            { 'account_number': '123456789', 'account_name': 'Checking', 'balance': 2209.30 }
        ]        
    },
    'n/a': {
        'firstName': 'Unknown', 
        'fullName': 'Unknown Caller', 
        'address': 'Unknown Address',
        'customerTier': 'Unknown',
        'accounts': None
    }
}

SLOTS = {
    'userPhone': {
        'prompts': [
            'I did\'t get that, please say or enter your 10-digit phone number',
            'Your phone number should include the area code, and be ten digits in length',
            'Sorry, was not able to understand your phone number.'
        ]
    }
}

