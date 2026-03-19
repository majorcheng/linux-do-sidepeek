#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://linux.do/latest"
CDP_PORT=9222

DEFAULT_CASES=(
  "AGENT-CHROME-001"
  "AGENT-CHROME-002"
  "AGENT-CHROME-003"
  "AGENT-CHROME-004"
  "AGENT-CHROME-005"
  "AGENT-CHROME-006"
  "AGENT-CHROME-008"
  "AGENT-CHROME-009"
)

CASES=("${DEFAULT_CASES[@]}")
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/agent-smoke.sh [--cdp-port 9222] [--cases AGENT-CHROME-001,AGENT-CHROME-006]
  bash scripts/agent-smoke.sh --list-cases

Notes:
  - Requires a running Chrome with --remote-debugging-port and the extension loaded.
  - Uses agent-browser over an existing CDP session.
EOF
}

list_cases() {
  printf '%s\n' "${DEFAULT_CASES[@]}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cdp-port)
      CDP_PORT=${2:?missing port}
      shift 2
      ;;
    --cases)
      IFS=',' read -r -a CASES <<< "${2:?missing case list}"
      shift 2
      ;;
    --list-cases)
      list_cases
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

ab() {
  agent-browser --cdp "$CDP_PORT" "$@"
}

ab_eval() {
  local script=$1
  ab eval "$script"
}

record_pass() {
  local case_id=$1
  local detail=$2
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "$case_id PASS - $detail"
}

record_fail() {
  local case_id=$1
  local detail=$2
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "$case_id FAIL - $detail"
}

record_skip() {
  local case_id=$1
  local detail=$2
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo "$case_id SKIP - $detail"
}

ensure_cdp() {
  ab get url >/dev/null
}

navigate_latest() {
  ab open "$BASE_URL" >/dev/null 2>&1 || true
  wait_for_topic_list
}

current_url() {
  ab get url
}

wait_for_topic_list() {
  local attempts=0
  local result

  while [ "$attempts" -lt 12 ]; do
    result=$(ab_eval '(() => document.querySelectorAll("#list-area a.title[data-topic-id]").length)()')
    if [ "$result" -gt 0 ]; then
      return 0
    fi

    ab wait 500 >/dev/null
    attempts=$((attempts + 1))
  done

  return 1
}

drawer_state() {
  local script
  script=$(cat <<'EOF'
(() => {
  const root = document.getElementById("ld-drawer-root");
  const settingsButton = root?.querySelector(".ld-drawer-settings-toggle");
  const settingsPanel = root?.querySelector("#ld-drawer-settings");
  const link = root?.querySelector(".ld-drawer-link");
  return {
    pageUrl: location.href,
    pageOpen: document.body.classList.contains("ld-drawer-page-open"),
    overlay: document.body.classList.contains("ld-drawer-mode-overlay"),
    title: root?.querySelector(".ld-drawer-title")?.textContent?.trim() || null,
    prevText: root?.querySelector("[data-nav=\"prev\"]")?.textContent?.trim() || null,
    nextText: root?.querySelector("[data-nav=\"next\"]")?.textContent?.trim() || null,
    settingsText: settingsButton?.textContent?.trim() || null,
    settingsExpanded: settingsButton?.getAttribute("aria-expanded") || null,
    settingsHidden: settingsPanel?.hasAttribute("hidden") ?? null,
    newTabText: link?.textContent?.trim() || null,
    newTabHref: link?.getAttribute("href") || null,
    newTabTarget: link?.getAttribute("target") || null,
    newTabRel: link?.getAttribute("rel") || null
  };
})()
EOF
)
  ab_eval "$script"
}

click_topic_link_by_index() {
  local index=$1
  local script
  script=$(cat <<EOF
(() => {
  const candidates = Array.from(document.querySelectorAll("#list-area a.title[data-topic-id]")).filter((link) => {
    const text = link.textContent?.trim();
    return Boolean(text) && !link.closest("#ld-drawer-root");
  });

  const link = candidates[$index];
  if (!link) {
    return { ok: false, reason: "topic-not-found", count: candidates.length };
  }

  const text = link.textContent.trim();
  const href = link.href;
  link.click();
  return { ok: true, text, href, count: candidates.length };
})()
EOF
)
  ab_eval "$script"
}

open_topic_by_index() {
  local index=$1
  local result
  navigate_latest
  result=$(click_topic_link_by_index "$index")
  if [ "$(echo "$result" | jq -r '.ok')" != "true" ]; then
    echo "$result"
    return 1
  fi

  ab wait 1800 >/dev/null
  echo "$result"
}

ensure_settings_open() {
  local state
  state=$(drawer_state)
  if [ "$(echo "$state" | jq -r '.settingsHidden')" = "true" ]; then
    click_settings_toggle >/dev/null
    ab wait 800 >/dev/null
  fi
}

ensure_settings_closed() {
  local state
  state=$(drawer_state)
  if [ "$(echo "$state" | jq -r '.settingsHidden')" = "false" ]; then
    click_settings_toggle >/dev/null
    ab wait 800 >/dev/null
  fi
}

click_settings_toggle() {
  local script
  script=$(cat <<'EOF'
(() => {
  const button = document.querySelector("#ld-drawer-root .ld-drawer-settings-toggle");
  if (!(button instanceof HTMLButtonElement)) {
    return { ok: false, reason: "settings-toggle-not-found" };
  }

  button.click();
  return { ok: true, text: button.textContent?.trim() || null };
})()
EOF
)
  ab_eval "$script"
}

set_overlay_mode() {
  local script
  ensure_settings_open
  script=$(cat <<'EOF'
(() => {
  const select = Array.from(document.querySelectorAll("#ld-drawer-settings select")).find((node) =>
    Array.from(node.options).some((option) => option.value === "overlay")
  );

  if (!select) {
    return { ok: false, reason: "drawer-mode-select-not-found" };
  }

  select.value = "overlay";
  select.dispatchEvent(new Event("change", { bubbles: true }));
  return { ok: true, value: select.value };
})()
EOF
)
  ab_eval "$script"
}

click_header_logo() {
  local script
  script=$(cat <<'EOF'
(() => {
  const link =
    document.querySelector("header.d-header a.home-logo")
    || document.querySelector("header.d-header a[href='https://linux.do/']")
    || document.querySelector("header.d-header a[href='https://linux.do']")
    || document.querySelector("header.d-header a[href='/']");

  if (!(link instanceof HTMLAnchorElement)) {
    return { ok: false, reason: "header-link-not-found" };
  }

  link.click();
  return { ok: true, text: link.textContent?.trim() || "LINUX DO" };
})()
EOF
)
  ab_eval "$script"
}

click_next_topic() {
  local script
  script=$(cat <<'EOF'
(() => {
  const button = document.querySelector("#ld-drawer-root [data-nav=\"next\"]");
  if (!(button instanceof HTMLButtonElement)) {
    return { ok: false, reason: "next-button-not-found" };
  }

  button.click();
  return { ok: true, text: button.textContent?.trim() || null };
})()
EOF
)
  ab_eval "$script"
}

click_tracker() {
  local script
  script=$(cat <<'EOF'
(() => {
  const tracker = document.querySelector("#list-area .show-more.has-topics .alert.clickable, .contents > .show-more.has-topics .alert.clickable");
  if (!(tracker instanceof Element)) {
    return { ok: false, reason: "tracker-not-found" };
  }

  tracker.click();
  return {
    ok: true,
    text: tracker.textContent?.trim() || null,
    top: Math.round(tracker.getBoundingClientRect().top || 0)
  };
})()
EOF
)
  ab_eval "$script"
}

tracker_state() {
  local script
  script=$(cat <<'EOF'
(() => {
  const tracker = document.querySelector("#list-area .show-more.has-topics .alert.clickable, .contents > .show-more.has-topics .alert.clickable");
  const rect = tracker?.getBoundingClientRect() || null;
  return {
    text: tracker?.textContent?.trim() || null,
    top: rect ? Math.round(rect.top) : null,
    scrollY: Math.round(window.scrollY)
  };
})()
EOF
)
  ab_eval "$script"
}

run_001() {
  local case_id="AGENT-CHROME-001"
  local click_result state title clicked_text
  click_result=$(open_topic_by_index 0) || {
    record_fail "$case_id" "无法点击列表主题"
    return 0
  }
  state=$(drawer_state)
  title=$(echo "$state" | jq -r '.title // empty')
  clicked_text=$(echo "$click_result" | jq -r '.text // empty')

  if [ "$(echo "$state" | jq -r '.pageOpen')" = "true" ] \
    && [ "$(echo "$state" | jq -r '.pageUrl')" = "$BASE_URL" ] \
    && [ -n "$title" ] \
    && [ "$title" = "$clicked_text" ]; then
    record_pass "$case_id" "title=$title"
  else
    record_fail "$case_id" "pageUrl=$(echo "$state" | jq -r '.pageUrl') title=$title clicked=$clicked_text"
  fi
}

run_002() {
  local case_id="AGENT-CHROME-002"
  local state
  open_topic_by_index 0 >/dev/null || {
    record_fail "$case_id" "无法打开抽屉"
    return 0
  }
  state=$(drawer_state)

  if [ "$(echo "$state" | jq -r '.prevText // empty')" = "上一帖" ] \
    && [ "$(echo "$state" | jq -r '.nextText // empty')" = "下一帖" ] \
    && [ "$(echo "$state" | jq -r '.settingsText // empty')" = "选项" ] \
    && [ "$(echo "$state" | jq -r '.newTabText // empty')" = "新标签打开" ]; then
    record_pass "$case_id" "toolbar ready"
  else
    record_fail "$case_id" "toolbar incomplete"
  fi
}

run_003() {
  local case_id="AGENT-CHROME-003"
  local opened closed
  open_topic_by_index 0 >/dev/null || {
    record_fail "$case_id" "无法打开抽屉"
    return 0
  }

  ensure_settings_open
  opened=$(drawer_state)
  ensure_settings_closed
  closed=$(drawer_state)

  if [ "$(echo "$opened" | jq -r '.settingsExpanded')" = "true" ] \
    && [ "$(echo "$opened" | jq -r '.settingsHidden')" = "false" ] \
    && [ "$(echo "$closed" | jq -r '.settingsExpanded')" = "false" ] \
    && [ "$(echo "$closed" | jq -r '.settingsHidden')" = "true" ]; then
    record_pass "$case_id" "settings toggle works"
  else
    record_fail "$case_id" "opened=$(echo "$opened" | jq -c '{expanded: .settingsExpanded, hidden: .settingsHidden}') closed=$(echo "$closed" | jq -c '{expanded: .settingsExpanded, hidden: .settingsHidden}')"
  fi
}

run_004() {
  local case_id="AGENT-CHROME-004"
  local before after
  open_topic_by_index 0 >/dev/null || {
    record_fail "$case_id" "无法打开抽屉"
    return 0
  }
  ensure_settings_closed
  before=$(drawer_state)
  click_next_topic >/dev/null || {
    record_fail "$case_id" "无法点击下一帖"
    return 0
  }
  ab wait 1800 >/dev/null
  after=$(drawer_state)

  if [ "$(echo "$after" | jq -r '.pageOpen')" = "true" ] \
    && [ "$(echo "$after" | jq -r '.pageUrl')" = "$BASE_URL" ] \
    && [ "$(echo "$before" | jq -r '.title // empty')" != "$(echo "$after" | jq -r '.title // empty')" ]; then
    record_pass "$case_id" "title=$(echo "$after" | jq -r '.title // empty')"
  else
    record_fail "$case_id" "before=$(echo "$before" | jq -r '.title // empty') after=$(echo "$after" | jq -r '.title // empty')"
  fi
}

run_005() {
  local case_id="AGENT-CHROME-005"
  local overlay_result state
  open_topic_by_index 0 >/dev/null || {
    record_fail "$case_id" "无法打开抽屉"
    return 0
  }

  overlay_result=$(set_overlay_mode)
  if [ "$(echo "$overlay_result" | jq -r '.ok')" != "true" ]; then
    record_fail "$case_id" "无法切到浮层模式"
    return 0
  fi

  ensure_settings_closed
  click_header_logo >/dev/null || {
    record_fail "$case_id" "无法点击页头链接"
    return 0
  }
  ab wait 1200 >/dev/null
  state=$(drawer_state)

  if [ "$(echo "$state" | jq -r '.pageUrl')" = "$BASE_URL" ] \
    && [ "$(echo "$state" | jq -r '.pageOpen')" = "false" ] \
    && [ "$(echo "$state" | jq -r '.overlay')" = "false" ]; then
    record_pass "$case_id" "overlay outside click closed drawer"
  else
    record_fail "$case_id" "state=$(echo "$state" | jq -c '{pageUrl, pageOpen, overlay}')"
  fi
}

run_006() {
  local case_id="AGENT-CHROME-006"
  local first_open before second_click after target_title
  first_open=$(open_topic_by_index 0) || {
    record_fail "$case_id" "无法打开第一个话题"
    return 0
  }
  before=$(drawer_state)

  if [ "$(echo "$before" | jq -r '.title // empty')" != "$(echo "$first_open" | jq -r '.text // empty')" ]; then
    record_fail "$case_id" "初始抽屉标题不匹配"
    return 0
  fi

  if [ "$(echo "$(set_overlay_mode)" | jq -r '.ok')" != "true" ]; then
    record_fail "$case_id" "无法切到浮层模式"
    return 0
  fi

  ensure_settings_closed
  second_click=$(click_topic_link_by_index 1)
  if [ "$(echo "$second_click" | jq -r '.ok')" != "true" ]; then
    record_fail "$case_id" "无法点击第二个话题"
    return 0
  fi

  ab wait 1800 >/dev/null
  after=$(drawer_state)
  target_title=$(echo "$second_click" | jq -r '.text // empty')

  if [ "$(echo "$after" | jq -r '.pageUrl')" = "$BASE_URL" ] \
    && [ "$(echo "$after" | jq -r '.pageOpen')" = "true" ] \
    && [ "$(echo "$after" | jq -r '.overlay')" = "true" ] \
    && [ "$(echo "$after" | jq -r '.title // empty')" = "$target_title" ] \
    && [ "$(echo "$before" | jq -r '.title // empty')" != "$target_title" ]; then
    record_pass "$case_id" "title=$(echo "$after" | jq -r '.title // empty')"
  else
    record_fail "$case_id" "before=$(echo "$before" | jq -r '.title // empty') after=$(echo "$after" | jq -r '.title // empty') target=$target_title"
  fi
}

run_008() {
  local case_id="AGENT-CHROME-008"
  local before click_result after
  navigate_latest
  ab scroll down 1200 >/dev/null
  ab wait 800 >/dev/null
  before=$(tracker_state)

  if [ -z "$(echo "$before" | jq -r '.text // empty')" ]; then
    record_skip "$case_id" "当前页面没有可点击的新话题提示条"
    return 0
  fi

  click_result=$(click_tracker)
  if [ "$(echo "$click_result" | jq -r '.ok')" != "true" ]; then
    record_skip "$case_id" "提示条不可点击"
    return 0
  fi

  ab wait 1500 >/dev/null
  after=$(tracker_state)

  if [ "$(current_url)" = "$BASE_URL" ] && [ "$(echo "$after" | jq -r '.scrollY')" -le 20 ]; then
    record_pass "$case_id" "scrollY=$(echo "$after" | jq -r '.scrollY')"
  else
    record_fail "$case_id" "before=$(echo "$before" | jq -r '.scrollY') after=$(echo "$after" | jq -r '.scrollY')"
  fi
}

run_009() {
  local case_id="AGENT-CHROME-009"
  local state
  open_topic_by_index 0 >/dev/null || {
    record_fail "$case_id" "无法打开抽屉"
    return 0
  }
  state=$(drawer_state)

  if [ "$(echo "$state" | jq -r '.newTabTarget // empty')" = "_blank" ] \
    && [ "$(echo "$state" | jq -r '.newTabRel // empty')" = "noopener noreferrer" ] \
    && [[ "$(echo "$state" | jq -r '.newTabHref // empty')" == https://linux.do/t/* ]]; then
    record_pass "$case_id" "href=$(echo "$state" | jq -r '.newTabHref // empty')"
  else
    record_fail "$case_id" "attrs=$(echo "$state" | jq -c '{newTabHref, newTabTarget, newTabRel}')"
  fi
}

run_case() {
  local case_id=$1
  case "$case_id" in
    AGENT-CHROME-001) run_001 ;;
    AGENT-CHROME-002) run_002 ;;
    AGENT-CHROME-003) run_003 ;;
    AGENT-CHROME-004) run_004 ;;
    AGENT-CHROME-005) run_005 ;;
    AGENT-CHROME-006) run_006 ;;
    AGENT-CHROME-008) run_008 ;;
    AGENT-CHROME-009) run_009 ;;
    *)
      record_fail "$case_id" "未知用例 ID"
      ;;
  esac
}

require_cmd agent-browser
require_cmd jq
ensure_cdp

echo "Running agent smoke against CDP port $CDP_PORT"

for case_id in "${CASES[@]}"; do
  if ! run_case "$case_id"; then
    record_fail "$case_id" "脚本执行异常"
  fi
done

echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
