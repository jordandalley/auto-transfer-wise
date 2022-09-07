#!/bin/bash
######################################################################
############ Wise (Formerly Transferwise) Automation Tool ############
############ Version 0.1 alpha                            ############
######################################################################
############ Set up as a cron job. Periodically checks    ############
############ account balance and if over a defined amount ############
############ triggers an automated transfer to an account ############
############ of your choosing.                            ############
######################################################################
############ Requires: curl, jq and bc                    ############
######################################################################

# Test
BASE_URL=https://api.sandbox.transferwise.tech
API_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Production
#BASE_URL=https://api.transferwise.com
#API_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Source and target currencies
SOURCE_CURRENCY=AUD
TARGET_CURRENCY=NZD

# Minimum amount in whole dollars that will trigger an automatic transfer
MINIMUM_BALANCE=500

# Enter the account number of the recipient to receive the funds (This account must already be added as a recipient in the web portal)
TARGET_ACCOUNT=060901078703100

checkAccount() {
        # Generate a UUID for idempotency
        UUID=`cat /proc/sys/kernel/random/uuid`
        # Fetch the profile ID related to a personal account (change to business if it's a business account)
        PROFILE_JSON=`curl -s -X GET "$BASE_URL/v1/profiles" -H "Authorization: Bearer $API_TOKEN"`
        PROFILE_ID=`echo $PROFILE_JSON | jq ".[] | select(.type==\"personal\") | .id"`

        # Fetch the balance of current account $SOURCE_CURRENCY
        SOURCE_ACCOUNT_JSON=`curl -s -X GET "$BASE_URL/v4/profiles/$PROFILE_ID/balances?types=STANDARD" -H "Authorization: Bearer $API_TOKEN"`
        SOURCE_ACCOUNT_ID=`echo $SOURCE_ACCOUNT_JSON | jq ".[] | select(.currency==\"$SOURCE_CURRENCY\") | .id"`
        SOURCE_ACCOUNT_BALANCE=`echo $SOURCE_ACCOUNT_JSON | jq ".[] | select(.currency==\"$SOURCE_CURRENCY\") | .amount.value"`

        if (( $(echo "$SOURCE_ACCOUNT_BALANCE < $MINIMUM_BALANCE" | bc -l) )); then
                exit
        else
                getRecipient
                getQuote
                startTransfer
        fi
}

getRecipient() {
        echo "Minimum balance of \$$MINIMUM_BALANCE $SOURCE_CURRENCY threshold triggered by account balance of \$$SOURCE_ACCOUNT_BALANCE $SOURCE_CURRENCY..."
        RECIPIENT_JSON=`curl -s -X GET "$BASE_URL/v1/accounts?currency=$TARGET_CURRENCY" -H "Authorization: Bearer $API_TOKEN"`
        RECIPIENT_ID=`echo $RECIPIENT_JSON | jq ".[] | select(.details.accountNumber==\"$TARGET_ACCOUNT\") | .id"`
        RECIPIENT_NAME=`echo $RECIPIENT_JSON | jq ".[] | select(.details.accountNumber==\"$TARGET_ACCOUNT\") | .accountHolderName"`
        if [ -z $RECIPIENT_ID ]
        then
                echo "ERROR: No recipient matches the account number $TARGET_ACCOUNT"
                exit
        else
                echo "Found recipient $RECIPIENT_NAME by account number \"$TARGET_ACCOUNT\"..."
        fi
}

getQuote() {
        QUOTE_JSON=`curl -s -X POST "$BASE_URL/v3/profiles/$PROFILE_ID/quotes" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
        -d "{
                \"sourceCurrency\": \"$SOURCE_CURRENCY\",
                \"targetCurrency\": \"$TARGET_CURRENCY\",
                \"sourceAmount\": $SOURCE_ACCOUNT_BALANCE,
                \"targetAmount\": null,
                \"payOut\": \"BANK_TRANSFER\",
                \"preferredPayIn\": \"BALANCE\"
        }"`
        QUOTE_ID=`echo $QUOTE_JSON | jq .id`
        PAIR_RATE=`echo $QUOTE_JSON | jq .rate`
        SOURCE_AMOUNT=`echo $QUOTE_JSON | jq .sourceAmount`
        TARGET_AMOUNT=`echo $QUOTE_JSON | jq ".paymentOptions[] | select(.payIn==\"BALANCE\") | .targetAmount"`
        WISE_FEE=`echo $QUOTE_JSON | jq ".paymentOptions[] | select(.payIn==\"BALANCE\") | .fee.total"`

        echo "*** Quotation Received ***"
        echo "Current Rate: $PAIR_RATE"
        echo "Source Amount: \$$SOURCE_AMOUNT $SOURCE_CURRENCY"
        echo "Wise Fee: \$$WISE_FEE $SOURCE_CURRENCY"
        echo "Target Amount: \$$TARGET_AMOUNT $TARGET_CURRENCY"
}

startTransfer() {
        echo "Beginning Transfer Request..."
        TRANSFER_JSON=`curl -s -X POST "$BASE_URL/v1/transfers" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
        -d "{
          \"targetAccount\": $RECIPIENT_ID,
          \"quoteUuid\": $QUOTE_ID,
          \"customerTransactionId\": \"$UUID\",
          \"details\" : {
              \"reference\" : \"Salary\",
              \"transferPurpose\": \"Salary\",
              \"transferPurposeSubTransferPurpose\": \"Salary\",
              \"sourceOfFunds\": \"Salary\"
            }
        }"`
        TRANSFER_ID=`echo $TRANSFER_JSON | jq .id`

        FUND_JSON=`curl -s -X POST "$BASE_URL/v3/profiles/$PROFILE_ID/transfers/$TRANSFER_ID/payments" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
        -d "{
              \"type\": \"BALANCE\"
            }
        }"`
        FUND_STATUS=`echo $FUND_JSON | jq .status`
        echo "Funding has been completed with status: $FUND_STATUS"
}

checkAccount
