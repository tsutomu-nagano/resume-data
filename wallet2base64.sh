#!/bin/bash

# wallet ディレクトリを wallet.zip に圧縮
zip -r wallet.zip ./wallet

# base64 エンコードして標準出力
base64 wallet.zip > wallet_b64.txt

# （不要なら zip ファイルを削除）
rm wallet.zip
