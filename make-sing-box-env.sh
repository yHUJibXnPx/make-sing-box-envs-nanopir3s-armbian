#!/bin/bash
IFS_BAK=$IFS
IFS=$'\n'
set -e

echo "检查操作系统..."

if [[ "$(uname)" != "Linux" ]]; then
  echo "本脚本仅支持 Linux。"
  exit 1
fi

echo "操作系统是 Linux"

# 检查 apt 是否已安装
if ! command -v apt >/dev/null 2>&1; then
  echo "未检测到 apt..."
  exit 2
else
  echo "已安装 apt"
fi

# 更新 apt 软件包信息
echo "正在更新 apt..."
sudo apt update

# 安装 unzip（解压 .zip）
echo "安装/升级 unzip..."
sudo apt -y install unzip || sudo apt -y upgrade unzip

# 安装 uuid（生成时间戳）
echo "安装/升级 uuid..."
sudo apt -y install uuid || sudo apt -y upgrade uuid

# 安装 unar（解压 .rar/.zip）
echo "安装/升级 unar..."
sudo apt -y install unar || sudo apt -y upgrade unar

# 安装 jq（后面提取节点、按国家分组全靠它）
#echo "安装/升级 jq..."
#sudo apt -y install jq || sudo apt -y upgrade jq

# 检查 python3
if ! command -v python3 >/dev/null 2>&1; then
  echo "未检测到 python3，请先自行安装后再运行本脚本。"
  exit 1
fi

echo "所有工具安装完成"

USER_HOME="$HOME"
SING_BOX_DIR_PATH="${USER_HOME}/Desktop/sing-boxs"
if [[ ! -d ${SING_BOX_DIR_PATH} && ! -f ${SING_BOX_DIR_PATH} ]]; then
  SING_BOX_DIR=${SING_BOX_DIR_PATH}'/sing-box_config'
else
  SING_BOX_DIR_PATH=${SING_BOX_DIR_PATH}-$(uuid)
  SING_BOX_DIR=${SING_BOX_DIR_PATH}'/sing-box_config'
fi

# =========================
# 订阅输入（URL / 本地文件）
# =========================
echo "请输入订阅来源（https 链接 / Sub-Store 下载链 / 本地文件路径）"
echo "直接回车则使用默认（不保证有效）:"
echo "默认: https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/singbox.json"
read -r SUBS
SUBS=${SUBS:-'https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/singbox.json'}

# 本地文件：不走 URL 编码、不强制进转换 API
if [[ -f "$SUBS" ]]; then
  SUBS_KIND="file"
  SUBS_SRC="$SUBS"
elif [[ "$SUBS" == file://* ]]; then
  SUBS_KIND="file"
  SUBS_SRC="${SUBS#file://}"
  if [[ ! -f "$SUBS_SRC" ]]; then
    echo "本地文件不存在: $SUBS_SRC"
    exit 1
  fi
else
  SUBS_KIND="url"
  SUBS_SRC="$SUBS"
fi

# =========================
# 转换 API（可选）
# 仅当「原文不是 sing-box JSON」时使用
# 输入 none / off / disable 表示禁用
# =========================
echo "请输入在线订阅转换 API（仅订阅来源非 sing-box JSON 时使用）"
echo "输入 none 禁用转换；直接回车使用默认:"
echo "默认: https://sub.d1.mk/sub"
read -r SUBS_API
SUBS_API=${SUBS_API:-'https://sub.d1.mk/sub'}
if [[ "$(echo "$SUBS_API" | tr 'A-Z' 'a-z')" =~ ^(none|off|disable|disabled)$ ]]; then
  SUBS_API="none"
fi

# 供启动脚本使用的变量（不再拼死 SUB_URL）
# SUBS_KIND / SUBS_SRC / SUBS_API 会写入 sing-box-start.sh
SING_BOX_PATH='/SagerNet/sing-box/releases/download/v1.15.0-alpha.14'
VERSION=sing-box-$(basename ${SING_BOX_PATH} | tr 'A-Z' 'a-z' | sed 's;v;;g')-linux-arm64.tar.gz
echo "https://github.com${SING_BOX_PATH}/${VERSION}"
SING_BOX_BIN_FILE_URL="https://github.com${SING_BOX_PATH}/${VERSION}"
SING_BOX_BIN_FILE_GZ="${SING_BOX_DIR_PATH}/${VERSION}"
SING_BOX_BIN_FILE="$(echo ${SING_BOX_BIN_FILE_GZ} | sed 's;.tar.gz;;g')"
SING_BOX_BIN_FILE_RENAME="${SING_BOX_DIR_PATH}/sing-box"
UI_PATH=$(curl -SL --connect-timeout 30 -m 60 --speed-time 30 --speed-limit 1 --retry 2 -H "Connection: keep-alive" -k 'https://github.com/Zephyruso/zashboard/releases' | sed 's;";\n;g;s;tag;download;g' | grep '/download/' | head -n 1)
UI_URL="https://github.com${UI_PATH}/dist.zip"
UI_FILE=${SING_BOX_DIR}'/ui.zip'
SING_BOX_CONFIG_TEMPLATES_URL="https://github.com/yHUJibXnPx/make-sing-box-envs-nanopir3s-armbian/raw/refs/heads/master/1.15.0-alpha.14.json"
SING_BOX_CONFIG_TEMPLATES_FILE=${SING_BOX_DIR_PATH}'/1.15.0-alpha.14.json'
TMP_FILE=${SING_BOX_DIR_PATH}'/temp_config.json'
OUT_FILE=${SING_BOX_DIR_PATH}'/out_config.json'
BASE_FILE=${SING_BOX_DIR_PATH}'/base_config.json'
SING_BOX_FILE=${SING_BOX_DIR_PATH}'/config.json'
NODES=${SING_BOX_DIR_PATH}'/filtered_nodes.json'
NODES_CONFIG=${SING_BOX_DIR_PATH}'/config_with_nodes.json'
# other
#游戏_469138946ba5fa|游戏|Game|加速|Steam|Origin|🎮
#流媒体_469138946ba5fa|Netflix|奈飞|Media|NF|Disney|YouTube|流媒体|🎥
#省流_469138946ba5fa|省流|低倍率|大流量|0.1x|0.2x|📺
#高级_469138946ba5fa|专线|高级|IEPL|IPLC|AIA|CTM|CC|Premium|👍
#智能_469138946ba5fa|AI|GPT|ChatGPT|OpenAI|Claude|Anthropic|Gemini|Google AI|Copilot|Microsoft AI|Perplexity|🤖
GROUPS_PATTERNS=$(cat <<'469138946ba5fa'
德国_469138946ba5fa|德国|德|\bDE\b|Germany|Frankfurt|Frankfurt am Main|Berlin|Munich|München|Hamburg|Dusseldorf|Düsseldorf|Cologne|Köln|Stuttgart|法兰克福|柏林|慕尼黑|汉堡|杜塞尔多夫|科隆|斯图加特|🇩🇪
日本_469138946ba5fa|日本|日|\bJP\b|Japan|Tokyo|Osaka|Nagoya|Yokohama|Sapporo|Fukuoka|东京|大阪|名古屋|横滨|札幌|福冈|🇯🇵
新加坡_469138946ba5fa|新加坡|坡|\bSG\b|Singapore|Singapore City|Lion City|狮城|🇸🇬
香港_469138946ba5fa|香港|港|\bHK\b|Hong Kong|HongKong|HKG|🇭🇰
台湾_469138946ba5fa|台湾|台|\bTW\b|Taiwan|Taipei|Taichung|Kaohsiung|Tainan|Hsinchu|Changhua|New Taipei|台北|台中|高雄|台南|新竹|彰化|新北|🇹🇼
韩国_469138946ba5fa|韩国|韩|\bKR\b|Korea|South Korea|Seoul|Busan|Incheon|首尔|釜山|仁川|🇰🇷
英国_469138946ba5fa|英国|英|\bUK\b|\bGB\b|United Kingdom|England|London|Manchester|伦敦|曼彻斯特|🇬🇧
加拿大_469138946ba5fa|加拿大|加|\bCA\b|Canada|Toronto|Vancouver|Montreal|多伦多|温哥华|蒙特利尔|🇨🇦
澳大利亚_469138946ba5fa|澳大利亚|澳|\bAU\b|Australia|Sydney|Melbourne|Brisbane|Perth|悉尼|墨尔本|布里斯班|珀斯|🇦🇺
法国_469138946ba5fa|法国|法|\bFR\b|France|Paris|Marseille|巴黎|马赛|🇫🇷
荷兰_469138946ba5fa|荷兰|荷|\bNL\b|Netherlands|Amsterdam|阿姆斯特丹|🇳🇱
美国_469138946ba5fa|美国|美|\bUS\b|\bUSA\b|United States|America|Los Angeles|\bLA\b|San Francisco|\bSF\b|Silicon Valley|San Jose|Seattle|Chicago|Dallas|New York|\bNY\b|Miami|Atlanta|Ashburn|Phoenix|Las Vegas|Denver|洛杉矶|旧金山|硅谷|圣何塞|西雅图|芝加哥|达拉斯|纽约|迈阿密|亚特兰大|阿什本|凤凰城|拉斯维加斯|丹佛|🇺🇸
469138946ba5fa
)
BASE_SING_BOX_CONFIG_FIXSCRIPT=$(cat <<'469138946ba5fa'
# 需要用 Python 或 JSON 专用工具转换
#command -v python
import json
import sys

def ensure_tls_insecure(node):
    """
    为支持 TLS 的 outbound 节点插入 tls.insecure = true
    """
    if not isinstance(node, dict):
        return node

    tls_supported = {"http", "vmess", "trojan", "hysteria", "vless", 
                     "shadowtls", "tuic", "hysteria2", "anytls"}

    if node.get("type") in tls_supported:
        tls = node.get("tls")
        if isinstance(tls, dict):
            # 只在 TLS 实际启用时才处理
            if tls.get("enabled", True):
                if "insecure" not in tls:
                    tls["insecure"] = True
        else:
            # 没有 tls 字段，补全
            #node["tls"] = {"enabled": True, "insecure": True}
            # 没有 tls 字段 = 不启用 TLS，不需要补全
            pass  # 替换掉原来的 else 分支

    return node

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, "r", encoding="utf-8") as f:
    data = json.load(f)

#if isinstance(data, dict) and isinstance(data.get("outbounds"), list):
#    data["outbounds"] = [ensure_tls_insecure(node) for node in data["outbounds"]]

with open(output_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"修复完成，所有 outbounds 节点已确保包含 tls.insecure: true → {output_path}")
469138946ba5fa
)
GROUPS_FILE=${SING_BOX_DIR_PATH}'/group_patterns.txt'
BASE_CONFIG_FIXSCRIPT_FILE=${SING_BOX_DIR_PATH}'/subs-fix.py'
SING_BOX_START=${SING_BOX_DIR_PATH}'/sing-box-start.sh'

mkdir -pv ${SING_BOX_DIR}

curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${SING_BOX_BIN_FILE_GZ} ${SING_BOX_BIN_FILE_URL}
[ ! -f "$SING_BOX_BIN_FILE_GZ" ] && echo "sing-box压缩文件不存在：$SING_BOX_BIN_FILE_GZ" && exit 1
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${UI_FILE} ${UI_URL}
[ ! -f "$UI_FILE" ] && echo "UI压缩文件不存在：$UI_FILE" && exit 1
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${SING_BOX_CONFIG_TEMPLATES_FILE} ${SING_BOX_CONFIG_TEMPLATES_URL}
[ ! -f "$SING_BOX_CONFIG_TEMPLATES_FILE" ] && echo "模板配置文件不存在：$SING_BOX_CONFIG_TEMPLATES_FILE" && exit 1

unar -f ${SING_BOX_BIN_FILE_GZ} -o ${SING_BOX_DIR_PATH}
mv -fv ${SING_BOX_BIN_FILE}/sing-box ${SING_BOX_BIN_FILE_RENAME}
rm -frv ${SING_BOX_BIN_FILE}
chmod -v a+x ${SING_BOX_BIN_FILE_RENAME}
if [[ -d ${SING_BOX_DIR}/ui ]]; then
  rm -frv ${SING_BOX_DIR}/ui
fi
unzip -o ${SING_BOX_DIR}'/ui.zip' -d ${SING_BOX_DIR}
mv -fv ${SING_BOX_DIR}/dist ${SING_BOX_DIR}/ui

# 合并自定义头部 + 提取部分
echo "${GROUPS_PATTERNS}" > "${GROUPS_FILE}"
[ ! -f "$GROUPS_FILE" ] && echo "分组定义文件不存在：$GROUPS_FILE" && exit 1
echo "${BASE_SING_BOX_CONFIG_FIXSCRIPT}" > "${BASE_CONFIG_FIXSCRIPT_FILE}"
[ ! -f "$BASE_CONFIG_FIXSCRIPT_FILE" ] && echo "修复脚本文件不存在：$BASE_CONFIG_FIXSCRIPT_FILE" && exit 1

chmod -Rv u+rwX,go-rwx ${SING_BOX_DIR_PATH}
chown -Rv $USER ${SING_BOX_DIR_PATH}

cat << 469138946ba5fa | tee ${SING_BOX_START}
#!/bin/bash
IFS_BAK=\$IFS
IFS=\$'\n'
set -e

DISABLE_TUN="\${DISABLE_TUN:-0}"
FIX_WEIRD_NODES="\${FIX_WEIRD_NODES:-0}"
echo "start sing-box..."
if [ -f '${TMP_FILE}' ]; then
  rm -fv '${TMP_FILE}'
fi

# -L --retry 3 --retry-delay 5 --progress-bar 
# =========================
# 订阅拉取 + 分支转换 → 得到 TMP_FILE（sing-box JSON）
# =========================
TMP_RAW='${SING_BOX_DIR_PATH}/tmp_raw_sub'
TMP_FILE='${TMP_FILE}'
SUBS_KIND='${SUBS_KIND}'
SUBS_SRC='${SUBS_SRC}'
SUBS_API='${SUBS_API}'

rm -f "\$TMP_RAW" "\$TMP_FILE"

urlencode() {
  # 优先 python3，避免依赖外部工具
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "\$1"
  else
    local LANG=C
    local length="\${#1}"
    local i c
    for (( i = 0; i < length; i++ )); do
      c="\${1:i:1}"
      case \$c in
        [a-zA-Z0-9.~_-]) printf '%s' "\$c" ;;
        *) printf '%%%02X' "'\$c" ;;
      esac
    done
  fi
}

fetch_raw() {
  local dest="\$1"
  if [[ "\$SUBS_KIND" == "file" ]]; then
    if [[ ! -f "\$SUBS_SRC" ]]; then
      echo "Error: local subscription file not found: \$SUBS_SRC"
      exit 1
    fi
    cp -f "\$SUBS_SRC" "\$dest"
    echo "Loaded local subscription: \$SUBS_SRC"
  else
    if ! curl -fsSL -k --retry 3 --retry-delay 5 --progress-bar -o "\$dest" "\$SUBS_SRC"; then
      echo "Error: failed to download subscription: \$SUBS_SRC"
      exit 2
    fi
    echo "Downloaded subscription: \$SUBS_SRC"
  fi
  if [[ ! -s "\$dest" ]]; then
    echo "Error: subscription content is empty: \$dest"
    exit 1
  fi
}

is_singbox_json() {
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if isinstance(d,dict) and isinstance(d.get("outbounds"),list) else 1)' "\$1" >/dev/null 2>&1
}

# 有的转换器会返回「纯 outbounds 数组」，包一层便于后续 jq
normalize_to_singbox_file() {
  local src="\$1" dest="\$2"
  python3 - "\$src" "\$dest" << 'PY'
import json, shutil, sys
src, dest = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8") as f:
    d = json.load(f)
if isinstance(d, list):
    with open(dest, "w", encoding="utf-8") as f:
        json.dump({"outbounds": d}, f, indent=2, ensure_ascii=False)
else:
    shutil.copyfile(src, dest)
PY
}

convert_via_api() {
  local api="\$1" src_ref="\$2" dest="\$3"
  local enc tmp_conv
  tmp_conv='${SING_BOX_DIR_PATH}/tmp_converted.json'

  if [[ "\$api" == "none" ]]; then
    echo "Error: content is not sing-box JSON, and conversion API is disabled (SUBS_API=none)."
    exit 1
  fi

  # 本地文件：很多在线 API 无法读你的磁盘，提示改用 URL 或先转成 sing-box
  if [[ "\$SUBS_KIND" == "file" ]]; then
    echo "Error: online conversion API cannot read local files."
    echo "请改用: 1) 已是 sing-box 的 JSON 文件  2) 可公网/局域网访问的订阅 URL  3) Sub-Store 的 sing-box 下载链"
    exit 1
  fi

  enc=\$(urlencode "\$src_ref")
  echo "Converting via API: \$api"
  if ! curl -fsSL -k --retry 3 --retry-delay 5 --progress-bar -o "\$tmp_conv" \\
    "\${api}?target=singbox&insert=false&new_name=true&scv=true&udp=true&exclude=&include=&url=\${enc}"; then
    echo "Error: conversion API request failed."
    exit 2
  fi
  if [[ ! -s "\$tmp_conv" ]]; then
    echo "Error: conversion API returned empty body."
    exit 1
  fi
  if ! is_singbox_json "\$tmp_conv"; then
    # 尝试数组形式
    if python3 -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if isinstance(d,list) else 1)' "\$tmp_conv" >/dev/null 2>&1; then
      normalize_to_singbox_file "\$tmp_conv" "\$dest"
      return 0
    fi
    echo "Error: conversion API did not return sing-box JSON."
    head -c 400 "\$tmp_conv" || true
    echo
    exit 1
  fi
  cp -f "\$tmp_conv" "\$dest"
}

# ---- 主流程：原文 → TMP_FILE ----
fetch_raw "\$TMP_RAW"

if is_singbox_json "\$TMP_RAW"; then
  echo "Detected sing-box JSON — skip conversion API (preserves Reality fields better)."
  normalize_to_singbox_file "\$TMP_RAW" "\$TMP_FILE"
elif python3 -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if isinstance(d,list) and len(d)>0 and isinstance(d[0],dict) else 1)' "\$TMP_RAW" >/dev/null 2>&1; then
  echo "Detected JSON array — wrap as outbounds."
  normalize_to_singbox_file "\$TMP_RAW" "\$TMP_FILE"
else
  echo "Not sing-box JSON — try conversion API..."
  convert_via_api "\$SUBS_API" "\$SUBS_SRC" "\$TMP_FILE"
fi

if [[ ! -s "\$TMP_FILE" ]]; then
  echo "Error: ${TMP_FILE} is empty or missing after fetch/convert."
  exit 1
fi
if ! is_singbox_json "\$TMP_FILE"; then
  echo "Error: final ${TMP_FILE} is not valid sing-box JSON with outbounds[]."
  exit 1
fi

echo "Temporary config ready: \$TMP_FILE"

[ ! -f '${TMP_FILE}' ] && echo "原始节点文件不存在：${TMP_FILE}" && exit 1

# 提取节点→合并模板→按分组分类这一段，任何一步失败都只影响分类效果本身，
# 不该导致整个启动脚本在最后一步拉起 sing-box 之前就退出
set +e

# 从订阅中提取节点
python3 - '${TMP_FILE}' '${SING_BOX_CONFIG_TEMPLATES_FILE}' '${NODES}' '${NODES_CONFIG}' '${GROUPS_FILE}' << 'PY469138946ba5fa'
import json, re, sys

tmp_file, tmpl_file, nodes_file, out_file, groups_file = sys.argv[1:6]

with open(tmp_file, "r", encoding="utf-8") as f:
    sub_data = json.load(f)

nodes = [
    ob for ob in sub_data.get("outbounds", [])
    if isinstance(ob, dict) and ob.get("server")
]
with open(nodes_file, "w", encoding="utf-8") as f:
    json.dump(nodes, f, indent=2, ensure_ascii=False)

with open(tmpl_file, "r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg["outbounds"].extend(nodes)
all_tags = [n["tag"] for n in nodes if "tag" in n]

for ob in cfg["outbounds"]:
    if ob.get("tag") == "自动_469138946ba5fa" and ob.get("type") == "urltest":
        ob["outbounds"] = all_tags
    elif ob.get("tag") == "手动_469138946ba5fa" and ob.get("type") == "selector":
        ob["outbounds"] = all_tags

matched_all = set()
with open(groups_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line or "|" not in line:
            continue
        tag, pattern = line.split("|", 1)
        print(f"处理分组：{tag}")
        try:
            rx = re.compile(pattern, re.IGNORECASE)
        except re.error as e:
            print(f"  ⚠ 正则匹配出错，跳过该分组: {e}")
            continue

        matched = [t for t in all_tags if t not in matched_all and rx.search(t)]
        if not matched:
            print("  ➤ 无匹配节点，跳过")
            continue

        matched_all.update(matched)
        target = next((ob for ob in cfg["outbounds"] if ob.get("tag") == tag), None)
        if target is None:
            print("  ➤ 分组不存在，创建新 selector")
            cfg["outbounds"].append({"type": "selector", "tag": tag, "outbounds": matched})
        elif target.get("type") in ("selector", "urltest"):
            print("  ➤ 分组已存在，更新节点列表")
            target["outbounds"] = matched

with open(out_file, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PY469138946ba5fa

set -e

cp -fv '${NODES_CONFIG}' '${SING_BOX_FILE}'
[ ! -f "$SING_BOX_FILE" ] && echo "新节点配置文件不存在：$SING_BOX_FILE" && exit 1

# 修复 sing-box config.json 中自动选择策略的 url-test 设置
if [ -f '${SING_BOX_FILE}' ]; then
    echo "正在增强自动选择策略组配置..."

    # 替换测试 URL 为更稳定的 Cloudflare
    # 修复 sing-box config.json 中自动选择策略的 url-test 设置
    DISABLE_TUN="\$DISABLE_TUN" FIX_WEIRD_NODES="\$FIX_WEIRD_NODES" python3 - '${SING_BOX_FILE}' << 'PY469138946ba5fa'
import importlib.util, json, os, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

# 1. 修改 mixed 的 listen_port
for ib in cfg.get("inbounds", []):
    if ib.get("type") == "mixed":
        ib["listen_port"] = 7890

for ob in cfg.get("outbounds", []):
    # 2. 修改所有 urltest 测速频率
    if ob.get("type") == "urltest":
        ob["url"] = "http://cp.cloudflare.com/generate_204"
        ob["interval"] = "10m0s"
        ob["tolerance"] = 100

    # 3. 修复 WS + TLS 的 ALPN 冲突
    tr = ob.get("transport")
    tls = ob.get("tls")
    if isinstance(tr, dict) and tr.get("type") == "ws" and isinstance(tls, dict):
        tls["alpn"] = ["http/1.1"]

    # 8. 去掉 transport.path 里的 ? 之后部分
    if isinstance(tr, dict) and isinstance(tr.get("path"), str):
        tr["path"] = tr["path"].split("?", 1)[0]

    # 10. 修复 tuic 节点 uuid 和端口类型
    if ob.get("type") == "tuic":
        u = ob.get("uuid", "")
        if isinstance(u, str):
            for sep in ("%3A", ":", "@["):
                u = u.split(sep, 1)[0]
            ob["uuid"] = u
        if isinstance(ob.get("server_port"), str) and ob["server_port"].isdigit():
            ob["server_port"] = int(ob["server_port"])

# 4. 修改 experimental.clash_api
clash_api = cfg.get("experimental", {}).get("clash_api")
if isinstance(clash_api, dict):
    clash_api["external_controller"] = ":9999"
    clash_api["external_ui"] = "ui"

# 9. 探针开关：删除 TUN 入站
if os.environ.get("DISABLE_TUN") == "1":
    cfg["inbounds"] = [ib for ib in cfg.get("inbounds", []) if ib.get("tag") != "TUN入站_469138946ba5fa"]
    for r in cfg.get("route", {}).get("rules", []):
        if isinstance(r.get("inbound"), list):
            r["inbound"] = [x for x in r["inbound"] if x != "TUN入站_469138946ba5fa"]

# 11. 探针开关：清理 2026 订阅里的怪字段（结构化操作，绝不破坏 JSON）
if os.environ.get("FIX_WEIRD_NODES") == "1":
    for ob in cfg.get("outbounds", []):
        if not isinstance(ob, dict):
            continue
        if ob.get("method") == "chacha20-poly1305":
            ob["method"] = "chacha20-ietf-poly1305"
        if ob.get("packet_encoding") == "none":
            ob["packet_encoding"] = "xudp"
        if ob.get("flow") == "xtls-rprx-vision-udp443":
            ob.pop("flow", None)
        if ob.get("plugin") == "simple-obfs":
            ob.pop("plugin", None)
            ob.pop("plugin_opts", None)
        ob.pop("encryption", None)
        ob.pop("tcp_fast_open", None)
        if isinstance(ob.get("server_ports"), list):
            ob["server_ports"] = [str(p).replace("-", ":") for p in ob["server_ports"]]
        utls = (ob.get("tls") or {}).get("utls")
        if isinstance(utls, dict) and utls.get("fingerprint") == "unsafe":
            utls["fingerprint"] = "firefox"

# 12. 可选外部热插拔钩子：如果同目录存在 custom_fix.py 且定义了 patch(cfg)，自动加载执行
hook_file = os.path.join(os.path.dirname(path), "custom_fix.py")
if os.path.isfile(hook_file):
    spec = importlib.util.spec_from_file_location("custom_fix", hook_file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if hasattr(mod, "patch"):
        mod.patch(cfg)

with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PY469138946ba5fa
else
  echo "Error: ${SING_BOX_FILE} is not exist. Exiting."
  exit 3
fi

cp -fv '${SING_BOX_FILE}' '${SING_BOX_FILE}.bak'

# 每个人的系统环境如此的不同
# 假如你原本就有python环境，而我如果写了一个脚本安装python环境，那一定会破坏你原本的python环境
# 所以python环境这块，你自己搭建好吗？
if \$(command -v python3) '${BASE_CONFIG_FIXSCRIPT_FILE}' '${SING_BOX_FILE}.bak' '${SING_BOX_FILE}'; then
  echo ok
else
  cp -fv '${SING_BOX_FILE}.bak' '${SING_BOX_FILE}'
fi

echo "配置已生成: ${SING_BOX_FILE}"

# 配置ip转发
ip_forward() {

  ANCHOR_FILE="/etc/sysctl.d/99-forwarding-singbox.conf"

  # 删除旧规则
  sudo rm -fv \$ANCHOR_FILE

  # 写入规则
  cat <<469138946ba5fa_1 | sudo tee \$ANCHOR_FILE
# /etc/sysctl.d/99-forwarding-singbox.conf
#
# 启用 IPv4 转发
net.ipv4.ip_forward=1

# 启用 IPv6 转发
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1

# 接受上游路由通告 (RA)，获取 IPv6 前缀
net.ipv6.conf.all.accept_ra=1
net.ipv6.conf.default.accept_ra=1

# 开启 IPv6 临时地址 (隐私扩展)
net.ipv6.conf.all.use_tempaddr=1
net.ipv6.conf.default.use_tempaddr=1
469138946ba5fa_1

  # 加载并启用 ip 转发
  sudo systemctl restart systemd-sysctl
  sudo sysctl -p

  # 应该能看到 singbox 的规则
  sudo sysctl net.ipv4.ip_forward
  sudo sysctl net.ipv6.conf.all.forwarding
}

ip_forward

# 刷新缓存重启 dnsmasq 当然系统不一定有
sudo systemctl restart dnsmasq || true
sudo resolvectl flush-caches || true

sudo '${SING_BOX_BIN_FILE_RENAME}' -c '${SING_BOX_FILE}' format > '${SING_BOX_FILE}.tmp' && mv -fv '${SING_BOX_FILE}.tmp' '${SING_BOX_FILE}'
sudo pkill -f 'sing-box -D' || true
sudo '${SING_BOX_BIN_FILE_RENAME}' -D '${SING_BOX_DIR}' -c '${SING_BOX_FILE}' run
IFS=\$IFS_BAK
469138946ba5fa

chmod -v u+x,go-rwx ${SING_BOX_START}
echo "已生成启动脚本: ${SING_BOX_START}"

echo "如果想要全局路由你需要配置路由器 DHCP 下发的 Gateway 和 DNS 最好都配置为公共dns比如 8.8.8.8 或 1.1.1.1，不要将 DNS 设置为 172.19.0.1 或 fake-ip 地址"
echo "如果想要旁路由，你需要为单个联网设备配置 Gateway 和 DNS 最好都配置为公共dns比如 8.8.8.8 或 1.1.1.1，不要将 DNS 设置为 172.19.0.1 或 fake-ip 地址"
echo "如果想要端口代理，你需要将联网代理设置为本机 IP:7890"
echo "如果想要本机，那就什么都没什么可说的了"
echo "执行脚本 ${SING_BOX_START} 启动测试看看吧"

IFS=$IFS_BAK