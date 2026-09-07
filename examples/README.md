# examples

実行可能な完全なデモです。意図的に汚したソースデータのシードと、パッケージの
全部品を適用したモデル1本で構成されています。読んでコピーするためのもので、
このディレクトリ自体は実行可能な dbt プロジェクトではありません。

| ファイル | 内容 |
|---|---|
| `packages.yml` | このパッケージと `dbt_utils` をタグ指定でインストール |
| `seeds/raw_members.csv` | 汚したソースデータ — 全角スペース、大文字小文字の不統一、NULL |
| `seeds/schema.yml` | `column_types` の指定（**省略不可**） |
| `models/members_cleaned.sql` | 全部品を使ったモデルとコードマスタ結合 |
| `models/schema.yml` | テスト。パッケージ自作の汎用テストを含む |

## 試す

```sh
cp examples/packages.yml .
cp examples/seeds/*   seeds/
cp examples/models/*  models/
```

`dbt_project.yml` に必須の `constants` var を追加します:

```yaml
vars:
  constants:
    system_code: 'KIRIN01'
    record_type: '1'
    created_by: 'BATCH'
```

続いて:

```sh
dbt deps
dbt seed
dbt compile --select members_cleaned
```

`target/compiled/<プロジェクト名>/models/members_cleaned.sql` を開いてください。
このファイルこそが本題です。マクロ呼び出しがすべて、生成された SQL に
置き換わっています。マクロはウェアハウスが実行する関数ではなく、SQL を
生成するものです。

```sh
dbt build --select members_cleaned
```

## 検証済みの出力

生成された SQL を Snowflake に対して実行した結果です。変換前 → 変換後:

| id | member_name | email | member_code | postal_code | region | orders | last_login |
|---|---|---|---|---|---|---|---|
| 1 | `　山田　　太郎 ` → `山田 太郎` | `Yamada.TARO@Example.COM` → `yamada.taro@example.com` | `ab-001` → `AB-001` | `" 100-0001 "` → `100-0001` | 02 → 関東 | 3 | 2026-08-01 |
| 2 | `  佐藤 花子  ` → `佐藤 花子` | → `sato.hanako@example.co.jp` | → `CD-002` | 530-0001 | 04 → 近畿 | **NULL → 0** | 2026-07-15 |
| 3 | `  tanaka　ichiro ` → `Tanaka Ichiro` | → `tanaka@example.com` | → `EF-003` | → `810-0001` | **NULL → 99 → 不明** | 7 | **NULL → 1900-01-01** |
| 4 | `"   "` → **NULL** | → `suzuki@example.com` | → `GH-004` | 060-0001 | 01 → 北海道・東北 | **NULL → 0** | **NULL → 1900-01-01** |
| 5 | `高橋　次郎` → `高橋 次郎` | → `takahashi@example.com` | → `IJ-005` | → `460-0001` | 03 → 中部 | 12 | 2026-09-01 |

## 立ち止まって説明したい3点

**部品を組み合わせる順序。** id = 3 の `  tanaka　ichiro ` は、
`change_case(case='initcap')` より**先に** `normalize_text` を通す必要が
あります。先に全角スペースを圧縮しておけば initcap は2語と認識して
それぞれの先頭を大文字にします。順序を逆にすると結果が変わります。
部品は組み合わせられますが、可換ではありません。

**`column_types` は省略できません。** 型推論に任せると `region_code: '02'`
は数値の `2` として読み込まれ、`'01'`〜`'99'` という文字列コードを持つ
`region_master` との結合が静かに成立しなくなります。`postal_code` も同様に
先頭のゼロを失います。コード類は「数値に見えるが文字列」です。必ず明示して
ください。

**NULL埋め の既定値は、下流でも有効な値にする。** `region_code` は `'99'`
で埋めています。これは region_master に実在する「不明」のコードなので、
地域不明の行もマスタ結合を通過します。`'UNKNOWN'` で埋めていたら、マスタと
結合するすべてのレポートからその行が消えていました。`models/schema.yml` の
`relationships` テストは、まさにこの誤りを検出するために置いています。

## 正直に伝えるべきトレードオフ

変換前:

```sql
coalesce(order_count, 0) as order_count
```

変換後:

```sql
{{ common_transforms.fill_null('order_count', kind='number', default_value=0) }} as order_count
```

後者の方が長いです。ワークショップでは、この点を隠さず言った方が誠実です。
呼び出し箇所が1つなら、マクロ化は可読性を犠牲にします。効いてくるのは
10箇所目からで、そしてルールを一斉に変更しなければならなくなった瞬間です。
**繰り返し現れるルール**を部品化してください。単に複雑なだけのルールを
部品化する必要はありません。
