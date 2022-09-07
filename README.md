# Wise Balance Transfer Automator
Automatically transfers funds out of your Wise account, performs currency conversion at a current rate and performs an automated transfer to a recipient of your choice.

# Installation

I highly recommend testing this with the Wise sandbox first: https://sandbox.transferwise.tech/

1. Login to the Wise portal and generate an API key
2. In the Wise portal, create a recipient that you wish to automate a transfer to
3. Open the wise.sh file and edit the various particulars
4. Setup a crontab to run periodically run the script

# Process

The script when run, logs in and checks the balance of the "SOURCE_CURRENCY" account. It then checks if the balance is under the "MINIMUM_BALANCE".

If the balance is under the "MINIMUM_BALANCE" (Eg. $500), the script does nothing, otherwise it triggers the "getRecipient" function.

The "getRecipient" function simply looks for a pre existing recipient id by the bank account number configured in the "TARGET_ACCOUNT" variable.
Once complete, the "getQuote" function is called.

The "getQuote" function gets the current offered rate (for a "BALANCE" to "BANK_TRANSFER" rate) from Wise for transfers between the "SOURCE_CURRENCY" and "TARGET_CURRENCY" and generates a "Quote ID" which is required for requesting a transfer. Once a quote is generated, the "startTransfer" function is called.

The "startTransfer" function simply executes a transfer request by using the information gathered by the earlier three functions.

# Disclaimer

This script is really dodgy. I am not a programmer, and I muddled my way through it over a few coffees. It has no error handling or anything. Use this at your own risk.

Happy for others to contribute or make it better, otherwise if you ask for help I'll probably be clueless.
