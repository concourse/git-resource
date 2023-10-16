#!/bin/bash
# borrowed/mutated from https://github.com/totegamma/githubapps-content-resource/blob/master/src/getToken.sh

set -e
source $(dirname $0)/common.sh

PAYLOAD="$(cat <&0)"

ACCOUNT=$(jq -r '.source.githubApp.account // ""' <<< $PAYLOAD)
if [ -z "$ACCOUNT" ]; then
	logError "source parameter 'account' missing." >&2
	exit 1
fi

APPID=$(jq -r '.source.githubApp.appID // ""' <<< $PAYLOAD)
if [ -z "$APPID" ]; then
	logError "source parameter 'appID' missing." >&2
	exit 1
fi

jq -r '.source.githubApp.private_key // ""' <<< $PAYLOAD | base64 -d > privatekey.pem
JWT=$(jwt encode --secret @privatekey.pem --iss $APPID --exp +3min --alg RS256)
rm privatekey.pem

if [ -z "$JWT" ]; then
	logError "failed to generagte JWT (is private_key valid?)" >&2
	exit 1
fi

INSTALLATION_ID=$(curl -s -X GET -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" https://api.github.com/app/installations \
                | jq -r --arg target $ACCOUNT 'map(select(.account.login==$target)) | .[0].id // ""')
if [ -z "$INSTALLATION_ID" ]; then
	logError "failed to get INSTALLATION_ID (is your application installed to target?)" >&2
	exit 1
fi

TOKEN=$(curl -s -X POST -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens \
      | jq -r '.token // ""')
if [ -z "$TOKEN" ]; then
	logError "failed to get token (is your application installed to target?)" >&2
	exit 1
fi

echo $TOKEN

