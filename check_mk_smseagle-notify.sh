#!/bin/bash
# SMSEagle
#
# Script Name   : check_mk_smseagle-notify.sh
# Description   : Send Checkmk notifications via SMSEagle device (APIv2)
# Author        : SMSEagle Team
# ======================================================================================

# SMSEAGLE_URL - base URL of the SMSEagle device (e.g. https://192.168.0.100)
if [[ -n "${NOTIFY_CONTACT_SMSEAGLE_URL}" ]]; then
    SMSEAGLE_URL="${NOTIFY_CONTACT_SMSEAGLE_URL}"
    echo "DEBUG: SMSEAGLE_URL set from NOTIFY_CONTACT_SMSEAGLE_URL: ${SMSEAGLE_URL}" >&2
elif [[ -n "${NOTIFY_PARAMETER_1}" ]]; then
    SMSEAGLE_URL="${NOTIFY_PARAMETER_1}"
    echo "DEBUG: SMSEAGLE_URL set from NOTIFY_PARAMETER_1: ${SMSEAGLE_URL}" >&2
else
    echo "ERROR: No SMSEagle URL provided. Set NOTIFY_PARAMETER_1 or custom attribute SMSEAGLE_URL. Exiting." >&2
    exit 2
fi

# API_TOKEN - access token generated in SMSEagle web GUI (Users menu)
if [[ -n "${NOTIFY_CONTACT_SMSEAGLE_TOKEN}" ]]; then
    API_TOKEN="${NOTIFY_CONTACT_SMSEAGLE_TOKEN}"
    echo "DEBUG: API_TOKEN set from NOTIFY_CONTACT_SMSEAGLE_TOKEN (hidden)" >&2
elif [[ -n "${NOTIFY_PARAMETER_2}" ]]; then
    API_TOKEN="${NOTIFY_PARAMETER_2}"
    echo "DEBUG: API_TOKEN set from NOTIFY_PARAMETER_2 (hidden)" >&2
else
    echo "ERROR: No API Access Token provided. Set NOTIFY_PARAMETER_2 or custom attribute SMSEAGLE_TOKEN. Exiting." >&2
    exit 2
fi

# PHONE_NUMBER - recipient's phone number
if [[ -n "${NOTIFY_CONTACTPAGER}" ]]; then
    PHONE_NUMBER="${NOTIFY_CONTACTPAGER}"
    echo "DEBUG: PHONE_NUMBER set from NOTIFY_CONTACTPAGER: ${PHONE_NUMBER}" >&2
else
    echo "ERROR: No phone number. Set the Pager field on the Checkmk contact. Exiting." >&2
    exit 2
fi

# VERIFY_SSL - optional: set to "no" to skip SSL verification (for self-signed certs)
if [[ -n "${NOTIFY_CONTACT_SMSEAGLE_VERIFY_SSL}" ]]; then
    VERIFY_SSL="${NOTIFY_CONTACT_SMSEAGLE_VERIFY_SSL}"
elif [[ -n "${NOTIFY_PARAMETER_3}" ]]; then
    VERIFY_SSL="${NOTIFY_PARAMETER_3}"
else
    VERIFY_SSL="yes"
fi

CURL_OPTS=""
if [[ "${VERIFY_SSL,,}" == "no" || "${VERIFY_SSL,,}" == "false" || "${VERIFY_SSL}" == "0" ]]; then
    CURL_OPTS="--insecure"
    echo "DEBUG: SSL verification disabled" >&2
fi

# PRIORITY - optional: SMS priority (0-9, higher = sent sooner)
if [[ -n "${NOTIFY_CONTACT_SMSEAGLE_PRIORITY}" ]]; then
    PRIORITY="${NOTIFY_CONTACT_SMSEAGLE_PRIORITY}"
elif [[ -n "${NOTIFY_PARAMETER_4}" ]]; then
    PRIORITY="${NOTIFY_PARAMETER_4}"
else
    PRIORITY=""
fi

# ENCODING - optional: "standard" (default) or "unicode" (for national characters)
if [[ -n "${NOTIFY_CONTACT_SMSEAGLE_ENCODING}" ]]; then
    ENCODING="${NOTIFY_CONTACT_SMSEAGLE_ENCODING}"
elif [[ -n "${NOTIFY_PARAMETER_5}" ]]; then
    ENCODING="${NOTIFY_PARAMETER_5}"
else
    ENCODING="standard"
fi

# MODEM_NO - optional: modem number for multi-modem devices
if [[ -n "${NOTIFY_CONTACT_SMSEAGLE_MODEM_NO}" ]]; then
    MODEM_NO="${NOTIFY_CONTACT_SMSEAGLE_MODEM_NO}"
elif [[ -n "${NOTIFY_PARAMETER_6}" ]]; then
    MODEM_NO="${NOTIFY_PARAMETER_6}"
else
    MODEM_NO=""
fi

# --- Determine state ---

if [[ "${NOTIFY_WHAT}" == "SERVICE" ]]; then
    STATE="${NOTIFY_SERVICESHORTSTATE}"
else
    STATE="${NOTIFY_HOSTSHORTSTATE}"
fi

case "${STATE}" in
    OK|UP)
        STATE_LABEL="OK"
        [[ "${STATE}" == "UP" ]] && STATE_LABEL="UP"
        ;;
    WARN)
        STATE_LABEL="WARNING"
        ;;
    CRIT|DOWN)
        STATE_LABEL="CRITICAL"
        [[ "${STATE}" == "DOWN" ]] && STATE_LABEL="DOWN"
        ;;
    UNKN)
        STATE_LABEL="UNKNOWN"
        ;;
    *)
        STATE_LABEL="${STATE}"
        ;;
esac

# --- Build the SMS message ---

MESSAGE="${NOTIFY_NOTIFICATIONTYPE}: ${NOTIFY_HOSTNAME}"

if [[ "${NOTIFY_WHAT}" == "SERVICE" ]]; then
    MESSAGE+=" / ${NOTIFY_SERVICEDESC}"
    MESSAGE+=" is ${STATE_LABEL}"
    if [[ -n "${NOTIFY_PREVIOUSSERVICEHARDSHORTSTATE}" ]]; then
        MESSAGE+=" (was ${NOTIFY_PREVIOUSSERVICEHARDSHORTSTATE})"
    fi
    MESSAGE+="\n${NOTIFY_SERVICEOUTPUT}"
else
    MESSAGE+=" is ${STATE_LABEL}"
    if [[ -n "${NOTIFY_PREVIOUSHOSTHARDSHORTSTATE}" ]]; then
        MESSAGE+=" (was ${NOTIFY_PREVIOUSHOSTHARDSHORTSTATE})"
    fi
    MESSAGE+="\n${NOTIFY_HOSTOUTPUT}"
    MESSAGE+="\nIP: ${NOTIFY_HOST_ADDRESS_4}"
fi

MESSAGE+="\n${NOTIFY_SHORTDATETIME} | ${OMD_SITE}"

echo "DEBUG: Message: ${MESSAGE}" >&2

# --- Build JSON payload ---

# Escape special characters for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo -n "${str}"
}

ESCAPED_MESSAGE=$(json_escape "$(echo -e "${MESSAGE}")")

JSON_PAYLOAD="{\"to\": [\"${PHONE_NUMBER}\"], \"text\": \"${ESCAPED_MESSAGE}\""

if [[ -n "${PRIORITY}" && "${PRIORITY}" =~ ^[0-9]$ ]]; then
    JSON_PAYLOAD+=", \"priority\": ${PRIORITY}"
fi

if [[ "${ENCODING,,}" == "unicode" ]]; then
    JSON_PAYLOAD+=", \"encoding\": \"unicode\""
fi

if [[ -n "${MODEM_NO}" && "${MODEM_NO}" =~ ^[0-9]+$ ]]; then
    JSON_PAYLOAD+=", \"modem_no\": ${MODEM_NO}"
fi

JSON_PAYLOAD+="}"

# --- Send SMS via SMSEagle APIv2 ---

ENDPOINT="${SMSEAGLE_URL%/}/api/v2/messages/sms"
echo "DEBUG: Sending to endpoint: ${ENDPOINT}" >&2

response=$(curl -s -w "\n%{http_code}" -X POST "${ENDPOINT}" \
    ${CURL_OPTS} \
    --max-time 30 \
    -H "Content-Type: application/json" \
    -H "access-token: ${API_TOKEN}" \
    -d "${JSON_PAYLOAD}")

# Extract HTTP status code (last line) and body (everything before)
http_code=$(echo "${response}" | tail -n1)
body=$(echo "${response}" | sed '$d')

echo "DEBUG: HTTP ${http_code}, Response: ${body}" >&2

if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
    # Check if response contains "queued" status (success)
    if echo "${body}" | grep -q '"status".*"queued"'; then
        echo "SMSEagle: SMS sent successfully to ${PHONE_NUMBER}" >&2
        exit 0
    elif echo "${body}" | grep -q '"message".*"OK"'; then
        echo "SMSEagle: SMS sent successfully to ${PHONE_NUMBER}" >&2
        exit 0
    else
        echo "ERROR: ${body}" >&2
        exit 2
    fi
else
    echo "ERROR: HTTP ${http_code} from ${ENDPOINT}: ${body}" >&2
    exit 2
fi
