#!/usr/bin/env sh
# Mailcow EasyPanel scoped Vercel DNS-01 provider.
# Based on acme.sh 3.1.6 dnsapi/dns_vercel.sh at
# 807da6498377ee5e0cf43a78091f46f12dc59a89.

dns_vercel_info='Vercel.com
Site: Vercel.com
Docs: github.com/acmesh-official/acme.sh/wiki/dnsapi2#dns_vercel
Options:
 VERCEL_TOKEN API Token
 VERCEL_TEAM_ID Team ID
'

VERCEL_API="https://api.vercel.com"
_VERCEL_ZONE="ya.com.bo"
_VERCEL_RECORD_NAME="_acme-challenge.notificaciones"
_VERCEL_CHALLENGE="${_VERCEL_RECORD_NAME}.${_VERCEL_ZONE}"

dns_vercel_add() {
  if ! _vercel_prepare "$1" "$2"; then
    return 1
  fi
  if ! _get_root "$1"; then
    _err "Vercel DNS zone is unavailable."
    return 1
  fi

  _saveaccountconf_mutable VERCEL_TOKEN "$VERCEL_TOKEN"
  _vercel_payload="$(jq -cn --arg name "$_VERCEL_RECORD_NAME" --arg value "$2" \
    '{type:"TXT",name:$name,value:$value}')" || return 1
  if ! _vercel_rest POST "v2/domains/$_VERCEL_ZONE/records" "$_vercel_payload"; then
    _err "Could not add the ACME TXT record."
    return 1
  fi
  if ! printf '%s' "$response" | jq -e '.uid | type == "string" and length > 0' >/dev/null; then
    _err "Unexpected Vercel response while adding the ACME TXT record."
    return 1
  fi
  _info "Added the ACME TXT record."
}

dns_vercel_rm() {
  if ! _vercel_prepare "$1" "$2"; then
    return 1
  fi
  if ! _get_root "$1"; then
    _err "Vercel DNS zone is unavailable."
    return 1
  fi

  _vercel_records='[]'
  _vercel_cursor=''
  _vercel_seen='|'
  _vercel_page=0
  while :; do
    _vercel_page=$((_vercel_page + 1))
    if [ "$_vercel_page" -gt 100 ]; then
      _err "Vercel DNS record listing is too long; refusing to delete."
      return 1
    fi
    _vercel_endpoint="v5/domains/$_VERCEL_ZONE/records?limit=100"
    if [ -n "$_vercel_cursor" ]; then
      _vercel_endpoint="$_vercel_endpoint&until=$_vercel_cursor"
    fi
    if ! _vercel_rest GET "$_vercel_endpoint"; then
      _err "Could not list Vercel DNS records; refusing to delete."
      return 1
    fi
    if ! printf '%s' "$response" | jq -e \
      '(.records | type == "array") and
       (.pagination | type == "object" and has("count") and has("next")) and
       (.pagination.count == (.records | length)) and
       (.pagination.next == null or (.pagination.next | type == "number"))' >/dev/null; then
      _err "Incomplete Vercel DNS listing; refusing to delete."
      return 1
    fi
    _vercel_records="$(jq -cn --argjson old "$_vercel_records" --argjson page "$response" \
      '$old + $page.records')" || return 1
    _vercel_next="$(printf '%s' "$response" | jq -r '.pagination.next // empty')" || return 1
    if [ -z "$_vercel_next" ]; then
      break
    fi
    case "$_vercel_next" in
      *[!0-9]*|'') _err "Invalid Vercel DNS cursor; refusing to delete."; return 1 ;;
    esac
    case "$_vercel_seen" in
      *"|$_vercel_next|"*) _err "Repeated Vercel DNS cursor; refusing to delete."; return 1 ;;
    esac
    _vercel_seen="${_vercel_seen}${_vercel_next}|"
    _vercel_cursor="$_vercel_next"
  done

  _vercel_count="$(printf '%s' "$_vercel_records" | jq --arg name "$_VERCEL_RECORD_NAME" \
    --arg value "$2" '[.[] | select(.name == $name and .type == "TXT" and .value == $value)] | length')" || return 1
  if [ "$_vercel_count" = 0 ]; then
    _info "ACME TXT record already absent."
    return 0
  fi
  if [ "$_vercel_count" != 1 ]; then
    _err "Ambiguous ACME TXT records; refusing to delete."
    return 1
  fi

  _vercel_record_id="$(printf '%s' "$_vercel_records" | jq -r --arg name "$_VERCEL_RECORD_NAME" \
    --arg value "$2" '.[] | select(.name == $name and .type == "TXT" and .value == $value) | .id // empty')" || return 1
  case "$_vercel_record_id" in
    ''|*[!A-Za-z0-9_-]*) _err "Invalid ACME TXT record ID; refusing to delete."; return 1 ;;
  esac
  _vercel_id_count="$(printf '%s' "$_vercel_records" | jq --arg id "$_vercel_record_id" \
    '[.[] | select(.id == $id)] | length')" || return 1
  if [ "$_vercel_id_count" != 1 ]; then
    _err "Ambiguous Vercel DNS record ID; refusing to delete."
    return 1
  fi
  if ! _vercel_rest DELETE "v2/domains/$_VERCEL_ZONE/records/$_vercel_record_id"; then
    _err "Could not remove the ACME TXT record."
    return 1
  fi
  _info "Removed the ACME TXT record."
}

_vercel_prepare() {
  if [ "$1" != "$_VERCEL_CHALLENGE" ]; then
    _err "Only the Mailcow ACME challenge is allowed."
    return 1
  fi
  if ! printf '%s' "$2" | LC_ALL=C grep -Eq '^[A-Za-z0-9_-]{43}$'; then
    _err "Invalid ACME TXT value."
    return 1
  fi
  VERCEL_TOKEN="${VERCEL_TOKEN:-$(_readaccountconf_mutable VERCEL_TOKEN)}"
  if [ -z "$VERCEL_TOKEN" ]; then
    _err "VERCEL_TOKEN is required."
    return 1
  fi
  VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
  if [ "${#VERCEL_TEAM_ID}" -gt 128 ] || \
    ! printf '%s' "${VERCEL_TEAM_ID:-}" | LC_ALL=C grep -Eq '^team_[A-Za-z0-9]+$'; then
    _err "VERCEL_TEAM_ID must be a valid team_ identifier."
    return 1
  fi
}

_get_root() {
  if [ "$1" != "$_VERCEL_CHALLENGE" ]; then
    return 1
  fi
  if ! _vercel_rest GET "v5/domains/$_VERCEL_ZONE"; then
    return 1
  fi
  if ! printf '%s' "$response" | jq -e --arg zone "$_VERCEL_ZONE" \
    --arg team "$VERCEL_TEAM_ID" \
    '.domain | objects | select(.name == $zone and ((has("teamId") | not) or .teamId == $team))' >/dev/null; then
    return 1
  fi
  _domain="$_VERCEL_ZONE"
  _sub_domain="$_VERCEL_RECORD_NAME"
}

_vercel_rest() {
  _vercel_method="$1"
  _vercel_ep="$2"
  _vercel_data="${3:-}"
  case "$_vercel_ep" in
    *\?*) _vercel_path="$VERCEL_API/$_vercel_ep&teamId=$VERCEL_TEAM_ID" ;;
    *) _vercel_path="$VERCEL_API/$_vercel_ep?teamId=$VERCEL_TEAM_ID" ;;
  esac
  export _H1="Content-Type: application/json"
  export _H2="Authorization: Bearer $VERCEL_TOKEN"

  if [ "$_vercel_method" = GET ]; then
    response="$(_get "$_vercel_path")"
  else
    response="$(_post "$_vercel_data" "$_vercel_path" "" "$_vercel_method")"
  fi
  _vercel_ret=$?
  _vercel_code="$(awk '/^HTTP/{code=$2} END{print code}' "$HTTP_HEADER")"
  if [ "$_vercel_ret" -ne 0 ]; then
    _err "Vercel request failed."
    return 1
  fi
  case "$_vercel_code" in
    2??) ;;
    *) _err "Vercel returned HTTP $_vercel_code."; return 1 ;;
  esac
  if [ -n "$response" ]; then
    if ! printf '%s' "$response" | jq -e 'type == "object" and .error == null' >/dev/null; then
      _err "Vercel returned an invalid or error response."
      return 1
    fi
  elif [ "$_vercel_method" != DELETE ]; then
    _err "Vercel returned an empty response."
    return 1
  fi
  return 0
}
