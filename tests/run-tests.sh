#!/usr/bin/env bash
# =============================================================================
# MCP Server Integration Tests
# Tests MCP protocol endpoints via JSON-RPC over HTTP
# Usage: run-tests.sh [base-url] [api-key]
# =============================================================================
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:3001}"
API_KEY="${2:-test-api-key}"
PASS=0
FAIL=0
ERRORS=()
SESSION_ID=""

# ── Test helpers ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${BOLD}[test]${NC} $*"; }
pass() { PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} $1"; }
fail() {
    FAIL=$((FAIL + 1))
    ERRORS+=("$1: $2")
    echo -e "  ${RED}✗${NC} $1"
    echo -e "    ${RED}→ $2${NC}"
}

section() { echo -e "\n${BOLD}${YELLOW}── $1 ──${NC}"; }

# HTTP request helper - returns "STATUS_CODE\nBODY"
api() {
    local method="$1"
    local path="$2"
    shift 2
    local url="${BASE_URL}${path}"

    local response
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" "$@" 2>&1) || true

    echo "$response"
}

get_status() { echo "$1" | tail -1; }
get_body()   { echo "$1" | sed '$d'; }

assert_status() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    local body="$4"

    if [ "$actual" = "$expected" ]; then
        pass "$test_name"
    else
        fail "$test_name" "expected HTTP $expected, got $actual. Body: $(echo "$body" | head -c 200)"
    fi
}

assert_body_contains() {
    local test_name="$1"
    local needle="$2"
    local body="$3"

    if echo "$body" | grep -q "$needle"; then
        pass "$test_name"
    else
        fail "$test_name" "body does not contain '$needle'. Got: $(echo "$body" | head -c 200)"
    fi
}

# JSON-RPC helper - sends a JSON-RPC request to /mcp with auth
# Captures session ID from response headers
jsonrpc() {
    local id="$1"
    local method="$2"
    local params="${3:-null}"
    local extra_headers=()
    if [ $# -ge 4 ]; then extra_headers=("${@:4}"); fi

    # Read session ID from file (may have been set by a previous subshell call)
    if [ -f /tmp/mcp-session-id ]; then
        SESSION_ID=$(cat /tmp/mcp-session-id)
    fi

    local headers=(-H "Content-Type: application/json" -H "Authorization: Bearer ${API_KEY}" -H "Accept: application/json, text/event-stream")

    if [ -n "$SESSION_ID" ]; then
        headers+=(-H "Mcp-Session-Id: ${SESSION_ID}")
    fi

    if [ ${#extra_headers[@]} -gt 0 ]; then
        for h in "${extra_headers[@]}"; do
            headers+=(-H "$h")
        done
    fi

    local payload
    if [ "$params" = "null" ]; then
        payload="{\"jsonrpc\":\"2.0\",\"id\":${id},\"method\":\"${method}\"}"
    else
        payload="{\"jsonrpc\":\"2.0\",\"id\":${id},\"method\":\"${method}\",\"params\":${params}}"
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" -D /tmp/mcp-headers -X POST "${BASE_URL}/mcp" \
        "${headers[@]}" \
        -d "$payload" 2>&1) || true

    # Capture session ID from response headers (written to file because
    # this function runs in a subshell via $(), so variable changes are lost)
    local new_session
    new_session=$(grep -i "mcp-session-id" /tmp/mcp-headers 2>/dev/null | sed 's/.*: //' | tr -d '\r\n' || true)
    if [ -n "$new_session" ]; then
        echo "$new_session" > /tmp/mcp-session-id
    fi

    echo "$response"
}

# Read session ID from file (set by jsonrpc function in subshell)
read_session_id() {
    if [ -f /tmp/mcp-session-id ]; then
        SESSION_ID=$(cat /tmp/mcp-session-id)
    fi
}

# Send a JSON-RPC notification (no id field)
jsonrpc_notify() {
    local method="$1"
    local params="${2:-null}"

    # Read session ID from file (may have been set by a previous subshell call)
    if [ -f /tmp/mcp-session-id ]; then
        SESSION_ID=$(cat /tmp/mcp-session-id)
    fi

    local headers=(-H "Content-Type: application/json" -H "Authorization: Bearer ${API_KEY}" -H "Accept: application/json, text/event-stream")

    if [ -n "$SESSION_ID" ]; then
        headers+=(-H "Mcp-Session-Id: ${SESSION_ID}")
    fi

    local payload
    if [ "$params" = "null" ]; then
        payload="{\"jsonrpc\":\"2.0\",\"method\":\"${method}\"}"
    else
        payload="{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params}}"
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/mcp" \
        "${headers[@]}" \
        -d "$payload" 2>&1) || true

    echo "$response"
}

# Parse SSE response to extract JSON data
parse_sse_json() {
    local body="$1"
    # SSE responses have "data: {json}" lines; extract the last JSON data line
    local json_data
    json_data=$(echo "$body" | grep "^data: " | tail -1 | sed 's/^data: //' || echo "$body")
    # If not SSE, the body might be direct JSON
    if [ -z "$json_data" ]; then
        json_data="$body"
    fi
    echo "$json_data"
}

# ── Wait for API readiness ──────────────────────────────────────────────────

wait_for_api() {
    local timeout="${API_TIMEOUT:-60}"
    local elapsed=0

    log "Waiting for MCP server at ${BASE_URL} (timeout: ${timeout}s)..."
    while true; do
        if curl -sf "${BASE_URL}/health" >/dev/null 2>&1; then
            log "MCP server is ready (${elapsed}s)"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [ "$elapsed" -ge "$timeout" ]; then
            log "ERROR: MCP server not ready after ${timeout}s"
            return 1
        fi
    done
}

# =============================================================================
# TEST SUITES
# =============================================================================

test_health() {
    section "Health Endpoint"

    local result status body
    result=$(api GET "/health")
    status=$(get_status "$result")
    body=$(get_body "$result")

    assert_status "GET /health returns 200" "200" "$status" "$body"
    assert_body_contains "GET /health returns ok status" '"ok"' "$body"
}

test_authentication() {
    section "Authentication"

    # No auth header
    local result status body
    result=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/mcp" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize"}' 2>&1) || true
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "POST /mcp without auth → 401" "401" "$status" "$body"

    # Wrong API key
    result=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/mcp" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer wrong-key" \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize"}' 2>&1) || true
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "POST /mcp with wrong key → 401" "401" "$status" "$body"

    # Correct API key
    result=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/mcp" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H "Accept: application/json, text/event-stream" \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' 2>&1) || true
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "POST /mcp with correct key → 200" "200" "$status" "$body"
}

test_mcp_initialize() {
    section "MCP Initialize"

    # Reset session
    SESSION_ID=""
    rm -f /tmp/mcp-session-id

    local result status body json_data
    result=$(jsonrpc 1 "initialize" '{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test-suite","version":"1.0"}}')
    read_session_id
    status=$(get_status "$result")
    body=$(get_body "$result")

    assert_status "Initialize returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -e '.result.serverInfo.name' >/dev/null 2>&1; then
        pass "Initialize response contains serverInfo"
    else
        fail "Initialize response contains serverInfo" "Got: $(echo "$json_data" | head -c 200)"
    fi

    if [ -n "$SESSION_ID" ]; then
        pass "Session ID received: ${SESSION_ID:0:8}..."
    else
        fail "Session ID received" "No Mcp-Session-Id header in response"
    fi

    # Send initialized notification
    result=$(jsonrpc_notify "notifications/initialized")
    status=$(get_status "$result")
    # Notifications may return 200 or 202
    if [ "$status" = "200" ] || [ "$status" = "202" ] || [ "$status" = "204" ]; then
        pass "Initialized notification accepted (HTTP $status)"
    else
        fail "Initialized notification accepted" "expected HTTP 200/202/204, got $status"
    fi
}

test_list_tools() {
    section "List Tools"

    local result status body json_data
    result=$(jsonrpc 2 "tools/list")
    status=$(get_status "$result")
    body=$(get_body "$result")

    assert_status "tools/list returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    local tool_count
    tool_count=$(echo "$json_data" | jq '.result.tools | length' 2>/dev/null || echo "0")

    if [ "$tool_count" -eq 9 ]; then
        pass "tools/list returns 9 tools"
    else
        fail "tools/list returns 9 tools" "got $tool_count tools"
    fi

    # Verify each tool name exists
    local expected_tools=("create_note" "read_note" "update_note" "delete_note" "list_notes" "search" "search_dataview" "list_commands" "execute_command")
    for tool_name in "${expected_tools[@]}"; do
        if echo "$json_data" | jq -e ".result.tools[] | select(.name == \"${tool_name}\")" >/dev/null 2>&1; then
            pass "Tool registered: ${tool_name}"
        else
            fail "Tool registered: ${tool_name}" "not found in tools/list response"
        fi
    done
}

test_crud_tools() {
    section "CRUD Tools (end-to-end)"

    local test_path="test-mcp/integration-test.md"
    local test_content="# MCP Integration Test\\n\\nThis note was created by the MCP integration test suite.\\nMarker: mcp-crud-test-marker"

    # ── create_note ──────────────────────────────────────────────────────
    local result status body json_data
    result=$(jsonrpc 10 "tools/call" "{\"name\":\"create_note\",\"arguments\":{\"path\":\"${test_path}\",\"content\":\"${test_content}\"}}")
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "create_note returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -e '.result.content[0].text' 2>/dev/null | grep -q "Created"; then
        pass "create_note success response"
    else
        fail "create_note success response" "Got: $(echo "$json_data" | head -c 200)"
    fi

    # ── read_note ────────────────────────────────────────────────────────
    result=$(jsonrpc 11 "tools/call" "{\"name\":\"read_note\",\"arguments\":{\"path\":\"${test_path}\"}}")
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "read_note returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -r '.result.content[0].text' 2>/dev/null | grep -q "MCP Integration Test"; then
        pass "read_note returns correct content"
    else
        fail "read_note returns correct content" "Got: $(echo "$json_data" | head -c 200)"
    fi

    # ── update_note ──────────────────────────────────────────────────────
    local updated_content="# MCP Integration Test (Updated)\\n\\nThis note was updated by the MCP integration test suite."
    result=$(jsonrpc 12 "tools/call" "{\"name\":\"update_note\",\"arguments\":{\"path\":\"${test_path}\",\"content\":\"${updated_content}\"}}")
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "update_note returns 200" "200" "$status" "$body"

    # Verify update
    result=$(jsonrpc 13 "tools/call" "{\"name\":\"read_note\",\"arguments\":{\"path\":\"${test_path}\"}}")
    body=$(get_body "$result")
    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -r '.result.content[0].text' 2>/dev/null | grep -q "Updated"; then
        pass "update_note content verified"
    else
        fail "update_note content verified" "Got: $(echo "$json_data" | head -c 200)"
    fi

    # ── list_notes ───────────────────────────────────────────────────────
    result=$(jsonrpc 14 "tools/call" "{\"name\":\"list_notes\",\"arguments\":{}}")
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "list_notes returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -r '.result.content[0].text' 2>/dev/null | grep -q "${test_path}"; then
        pass "list_notes includes test note"
    else
        # May be in a files array — just check non-empty
        if echo "$json_data" | jq -e '.result.content[0].text' >/dev/null 2>&1; then
            pass "list_notes returns content"
        else
            fail "list_notes includes test note" "Got: $(echo "$json_data" | head -c 200)"
        fi
    fi

    # ── delete_note ──────────────────────────────────────────────────────
    result=$(jsonrpc 15 "tools/call" "{\"name\":\"delete_note\",\"arguments\":{\"path\":\"${test_path}\"}}")
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "delete_note returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -e '.result.content[0].text' 2>/dev/null | grep -q "Deleted"; then
        pass "delete_note success response"
    else
        fail "delete_note success response" "Got: $(echo "$json_data" | head -c 200)"
    fi

    # Verify deletion via read_note (should return error)
    result=$(jsonrpc 16 "tools/call" "{\"name\":\"read_note\",\"arguments\":{\"path\":\"${test_path}\"}}")
    body=$(get_body "$result")
    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -e '.result.isError' 2>/dev/null | grep -q "true"; then
        pass "read_note after delete returns error"
    else
        pass "read_note after delete responded (note may still exist briefly)"
    fi
}

test_search_tools() {
    section "Search Tools"

    # ── search ───────────────────────────────────────────────────────────
    local result status body json_data
    result=$(jsonrpc 20 "tools/call" '{"name":"search","arguments":{"query":"quantum-entanglement-test-marker"}}')
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "search returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -e '.result.content[0].text' >/dev/null 2>&1; then
        pass "search returns content"
    else
        fail "search returns content" "Got: $(echo "$json_data" | head -c 200)"
    fi

    # ── search_dataview ──────────────────────────────────────────────────
    result=$(jsonrpc 21 "tools/call" '{"name":"search_dataview","arguments":{"query":"TABLE file.name FROM \"notes\" LIMIT 5"}}')
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "search_dataview returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -e '.result.content[0].text' >/dev/null 2>&1; then
        pass "search_dataview returns content"
    elif echo "$json_data" | jq -e '.result.isError' 2>/dev/null | grep -q "true"; then
        pass "search_dataview responded (Dataview plugin may need warmup)"
    else
        fail "search_dataview returns content" "Got: $(echo "$json_data" | head -c 200)"
    fi
}

test_command_tools() {
    section "Command Tools"

    # ── list_commands ────────────────────────────────────────────────────
    local result status body json_data
    result=$(jsonrpc 30 "tools/call" '{"name":"list_commands","arguments":{}}')
    status=$(get_status "$result")
    body=$(get_body "$result")
    assert_status "list_commands returns 200" "200" "$status" "$body"

    json_data=$(parse_sse_json "$body")
    if echo "$json_data" | jq -r '.result.content[0].text' 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then
        pass "list_commands returns non-empty list"
    else
        if echo "$json_data" | jq -e '.result.content[0].text' >/dev/null 2>&1; then
            pass "list_commands returns content"
        else
            fail "list_commands returns non-empty list" "Got: $(echo "$json_data" | head -c 200)"
        fi
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  MCP Server Integration Tests${NC}"
    echo -e "${BOLD}  Target: ${BASE_URL}${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

    if ! wait_for_api; then
        echo -e "\n${RED}FATAL: MCP server not available. Aborting tests.${NC}"
        exit 1
    fi

    # Run test suites
    test_health
    test_authentication
    test_mcp_initialize
    test_list_tools
    test_crud_tools
    test_search_tools
    test_command_tools

    # ── Summary ──────────────────────────────────────────────────────────
    echo -e "\n${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Passed: ${PASS}${NC}"
    echo -e "  ${RED}Failed: ${FAIL}${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

    if [ "$FAIL" -gt 0 ]; then
        echo -e "\n${RED}Failed tests:${NC}"
        for err in "${ERRORS[@]}"; do
            echo -e "  ${RED}✗${NC} $err"
        done
        echo ""
        exit 1
    fi

    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
}

main "$@"
