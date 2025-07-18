#!/bin/bash

# スクリプトを安全に実行
set -e

# ユーザー変数
USER_NAME=$(id -un)
PARENT_CMD=$(ps -o comm= -p "$PPID")
if [ $USER_NAME = "root" ] && [ $PARENT_CMD = "sudo" ]; then
    USER_NAME=$SUDO_USER
fi
# Snipe-IT-Agentの展開先ディレクトリ
SIA_DIR="/usr/local/snipe-it-agent"
# Snipe-IT-Agentのプログラム本体
SCRIPT_PATH="$SIA_DIR/snipe-it-agent.py"
if [ -f /etc/redhat-release ]; then
    # RedHat系OSの場合
    PKG_CMD="dnf"
else
    # Ubuntu系OSの場合
    PKG_CMD="apt"
fi
TMP_FILE="/tmp/crontab_$USER_NAME"


echo ">>> パッケージをインストール中..."

# 必要なパッケージをdnfでインストール
sudo $PKG_CMD install -y python3 python3-requests python3-psutil pciutils

echo ">>> crontab を設定中..."

# crontab に登録するジョブ内容
CRON_JOB="* 4 * * * python3 $SCRIPT_PATH --model-id 2 --fieldset-id 2 > /dev/null 2>&1"

# sudo を使って crontab 読み取り（存在しない場合は空ファイルを使う）
if sudo crontab -l -u $USER_NAME > $TMP_FILE 2>/dev/null; then
    echo ">>> 既存の crontab を取得しました"
else
    echo ">>> crontab が存在しないため新規作成します"
    touch $TMP_FILE
fi

# 同じジョブがすでに入っていない場合のみ追加
grep -F "$CRON_JOB" $TMP_FILE || echo "$CRON_JOB" >> $TMP_FILE

# crontab を登録
sudo crontab -u $USER_NAME $TMP_FILE
rm -f $TMP_FILE

echo ">>> crontab 登録完了"
