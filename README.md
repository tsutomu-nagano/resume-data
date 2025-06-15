# resume-data
Data for [ReSUME](https://github.com/tsutomu-nagano/resume)

## Description
- ReSUMEで参照しているデータを管理しているリポジトリです
- githab-actionを使って日時で次の作業を行っています
  1. e-Stat APIを使用してテーブルの一覧を取得 (R)
  2. リポジトリに保存されている状態と比較し差分データのメタデータを取得　(R)
  3. 変更があった場合はOracleDBのデータを全削除 >> 全挿入 (python)

## System Configuration
- テーブルの一覧はCSV
- メタデータはサイズが大きくなりそうだったのでparqeut
- どちらも政府統計コードごとにファイルを作成

## Note
- このサービスは、政府統計総合窓口(e-Stat)のAPI機能を使用していますが、サービスの内容は国によって保証されたものではありません。