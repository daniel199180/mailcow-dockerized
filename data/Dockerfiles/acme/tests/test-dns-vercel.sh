#!/bin/sh
# Mock-only tests: _get and _post never call the network.
set -eu

PROVIDER=${1:-/opt/acme.sh/dnsapi/dns_vercel.sh}
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
HTTP_HEADER="$TMP_DIR/headers"
LOG="$TMP_DIR/requests"
TOKEN=validation-only-token
VERCEL_TOKEN=$TOKEN
VERCEL_TEAM_ID=team_Example12345678
DOMAIN=_acme-challenge.notificaciones.ya.com.bo
VALUE=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
OTHER=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB

_err() { printf 'provider error: %s\n' "$*" >&2; }
_info() { :; }
_readaccountconf_mutable() { :; }
_saveaccountconf_mutable() { :; }

_mock() {
  method=$1 url=$2 body=$3
  printf '%s|%s|%s\n' "$method" "$url" "$body" >> "$LOG"
  status=200
  case "$url" in
    */v5/domains/ya.com.bo?teamId=*)
      case "$SCENARIO" in
        forbidden) status=403; result='{"error":{"code":"forbidden"}}' ;;
        not_found) status=404; result='{"error":{"code":"not_found"}}' ;;
        domain_error) result='{"error":{"code":"invalid_domain"}}' ;;
        domain_invalid_json) result='{"domain":' ;;
        domain_wrong_name) result='{"domain":{"name":"tiendaya.com.bo","teamId":"team_Example12345678"}}' ;;
        domain_wrong_team) result='{"domain":{"name":"ya.com.bo","teamId":"team_Other12345678"}}' ;;
        domain_null_team) result='{"domain":{"name":"ya.com.bo","teamId":null}}' ;;
        domain_legacy) result='{"name":"ya.com.bo"}' ;;
        domain_no_team) result='{"domain":{"name":"ya.com.bo"}}' ;;
        *) result='{"domain":{"name":"ya.com.bo","teamId":"team_Example12345678"}}' ;;
      esac
      ;;
    */v2/domains/ya.com.bo/records?teamId=*)
      case "$SCENARIO" in
        bad_add) result='{"error":{"code":"forbidden"}}' ;;
        *) result='{"uid":"rec_created","updated":123}' ;;
      esac
      ;;
    */v5/domains/ya.com.bo/records?limit=100*teamId=*)
      case "$SCENARIO" in
        exact|domain_no_team|delete_error)
          result='{"records":[{"id":"rec_root","name":"","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},{"id":"rec_wildcard","name":"*","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},{"id":"rec_store","name":"costura","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},{"id":"rec_mail","name":"notificaciones","type":"A","value":"94.72.119.78"},{"id":"rec_spf","name":"","type":"TXT","value":"v=spf1 include:example.invalid ~all"},{"id":"rec_target","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},{"id":"rec_old","name":"_acme-challenge.notificaciones","type":"TXT","value":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"}],"pagination":{"count":7,"next":null}}'
          ;;
        absent) result='{"records":[{"id":"rec_other","name":"_acme-challenge.notificaciones","type":"TXT","value":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"}],"pagination":{"count":1,"next":null}}' ;;
        ambiguous) result='{"records":[{"id":"rec_one","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},{"id":"rec_two","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}],"pagination":{"count":2,"next":null}}' ;;
        duplicate_id) result='{"records":[{"id":"rec_target","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},{"id":"rec_target","name":"costura","type":"TXT","value":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"}],"pagination":{"count":2,"next":null}}' ;;
        invalid_id) result='{"records":[{"id":"rec/unsafe","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}],"pagination":{"count":1,"next":null}}' ;;
        incomplete) result='{"records":[{"id":"rec_target","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}]}' ;;
        forbidden_list) status=403; result='{"error":{"code":"forbidden"}}' ;;
        paginated)
          case "$url" in
            *until=123*) result='{"records":[{"id":"rec_target","name":"_acme-challenge.notificaciones","type":"TXT","value":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}],"pagination":{"count":1,"next":null}}' ;;
            *) result='{"records":[{"id":"rec_store","name":"costura","type":"CNAME","value":"stores.example.invalid"}],"pagination":{"count":1,"next":123}}' ;;
          esac
          ;;
        *) printf 'unknown scenario: %s\n' "$SCENARIO" >&2; exit 1 ;;
      esac
      ;;
    */v2/domains/ya.com.bo/records/rec_target?teamId=*)
      if [ "$SCENARIO" = delete_error ]; then
        status=403
        result='{"error":{"code":"forbidden"}}'
      else
        result='{"deleted":true}'
      fi
      ;;
    *) printf 'unexpected request: %s %s\n' "$method" "$url" >&2; exit 1 ;;
  esac
  printf 'HTTP/1.1 %s Mock\n' "$status" > "$HTTP_HEADER"
  printf '%s' "$result"
}
_get() { _mock GET "$1" ''; }
_post() { _mock "$4" "$2" "$1"; }

# shellcheck source=/dev/null
. "$PROVIDER"

reset_case() { SCENARIO=$1; : > "$LOG"; }
must_fail() { if "$@"; then printf 'expected failure: %s\n' "$*" >&2; exit 1; fi; }
assert_scoped_requests() {
  while IFS='|' read -r method url body; do
    case "$method $url" in
      'GET https://api.vercel.com/v5/domains/ya.com.bo?teamId=team_Example12345678'|\
      'GET https://api.vercel.com/v5/domains/ya.com.bo/records?limit=100&teamId=team_Example12345678'|\
      'GET https://api.vercel.com/v5/domains/ya.com.bo/records?limit=100&until=123&teamId=team_Example12345678'|\
      'POST https://api.vercel.com/v2/domains/ya.com.bo/records?teamId=team_Example12345678'|\
      'DELETE https://api.vercel.com/v2/domains/ya.com.bo/records/rec_target?teamId=team_Example12345678') ;;
      *) printf 'request escaped the expected endpoints: %s %s\n' "$method" "$url" >&2; exit 1 ;;
    esac
  done < "$LOG"
  if grep -q "$TOKEN" "$LOG"; then
    printf 'token leaked into request log\n' >&2
    exit 1
  fi
}
assert_no_delete() { if grep -q '^DELETE|' "$LOG"; then printf 'unexpected deletion\n' >&2; exit 1; fi; }
assert_delete_target() {
  test "$(grep -c '^DELETE|' "$LOG")" = 1
  grep -q '^DELETE|https://api.vercel.com/v2/domains/ya.com.bo/records/rec_target?teamId=team_Example12345678|$' "$LOG"
}

reset_case exact
dns_vercel_add "$DOMAIN" "$VALUE"
test "$(grep -c '^POST|' "$LOG")" = 1
post_body=$(sed -n 's/^POST|[^|]*|//p' "$LOG")
printf '%s' "$post_body" | jq -e --arg value "$VALUE" '.name == "_acme-challenge.notificaciones" and .type == "TXT" and .value == $value' >/dev/null
assert_scoped_requests

reset_case domain_no_team
dns_vercel_add "$DOMAIN" "$VALUE"
test "$(grep -c '^POST|' "$LOG")" = 1
assert_scoped_requests

reset_case exact
dns_vercel_rm "$DOMAIN" "$VALUE"
assert_delete_target
assert_scoped_requests

reset_case domain_no_team
dns_vercel_rm "$DOMAIN" "$VALUE"
assert_delete_target
assert_scoped_requests

reset_case paginated
dns_vercel_rm "$DOMAIN" "$VALUE"
assert_delete_target
grep -q 'until=123&teamId=team_Example12345678' "$LOG"
assert_scoped_requests

for scenario in absent ambiguous duplicate_id invalid_id incomplete forbidden_list; do
  reset_case "$scenario"
  if [ "$scenario" = absent ]; then
    dns_vercel_rm "$DOMAIN" "$VALUE"
  else
    must_fail dns_vercel_rm "$DOMAIN" "$VALUE"
  fi
  assert_no_delete
  assert_scoped_requests
done

reset_case forbidden
must_fail dns_vercel_add "$DOMAIN" "$VALUE"
test "$(grep -c '^POST|' "$LOG" || true)" = 0

for scenario in forbidden not_found domain_error domain_invalid_json domain_wrong_name domain_wrong_team domain_null_team domain_legacy; do
  reset_case "$scenario"
  must_fail dns_vercel_add "$DOMAIN" "$VALUE"
  must_fail dns_vercel_rm "$DOMAIN" "$VALUE"
  test "$(wc -l < "$LOG" | tr -d ' ')" = 2
  if grep -Eq '^(POST|DELETE)\|' "$LOG"; then
    printf 'domain failure led to a DNS write: %s\n' "$scenario" >&2
    exit 1
  fi
  assert_scoped_requests
done

reset_case bad_add
must_fail dns_vercel_add "$DOMAIN" "$VALUE"

reset_case delete_error
must_fail dns_vercel_rm "$DOMAIN" "$VALUE"
assert_delete_target

for forbidden_domain in _acme-challenge.ya.com.bo _acme-challenge.costura.ya.com.bo _acme-challenge.tiendaya.com.bo; do
  reset_case exact
  must_fail dns_vercel_add "$forbidden_domain" "$VALUE"
  must_fail dns_vercel_rm "$forbidden_domain" "$VALUE"
  test ! -s "$LOG"
done

reset_case exact
VERCEL_TEAM_ID='team_bad&other=value'
must_fail dns_vercel_add "$DOMAIN" "$VALUE"
must_fail dns_vercel_rm "$DOMAIN" "$VALUE"
test ! -s "$LOG"
VERCEL_TEAM_ID=team_Example12345678

reset_case exact
must_fail dns_vercel_add "$DOMAIN" 'unsafe'
test ! -s "$LOG"

printf 'Vercel DNS-01 mock tests passed\n'
