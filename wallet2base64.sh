#!/bin/bash

# wallet ディレクトリを wallet.zip に圧縮
zip -r wallet.zip ./worker/python/wallet

# base64 エンコードして標準出力
export WALLET_BASE64=$(base64 wallet.zip)
# base64 wallet.zip > wallet.b64.txt

# （不要なら zip ファイルを削除）
rm wallet.zip
