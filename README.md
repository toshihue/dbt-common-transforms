# common_transforms

再利用可能な変換部品を集めた小さな dbt パッケージです。あわせて、**自分で
パッケージを作る方法**の実例にもなっています。

動作確認はすべて Snowflake で行っています。

## 収録している部品

| 部品 | 種類 | 用途 |
|---|---|---|
| `constant(key)` / `standard_constants()` | マクロ | 固定値セット — 入力に関係なく固定値を設定 |
| `normalize_text(column)` | マクロ | 文字列加工 — 前後空白の除去と、全角スペースを含む連続空白の圧縮 |
| `change_case(column, case)` | マクロ | 文字列加工 — lower / upper / initcap |
| `fill_null(column, kind)` | マクロ | NULL埋め — vars から型に応じた既定値 |
| `zero_pad(column, length)` | マクロ | 0埋め — 桁数の足りない値を左から埋めて固定長にそろえる |
| `audit_columns()` | マクロ | 標準的な監査列 |
| `placeholder_requires_reason` | 汎用テスト | プレースホルダ値を使う行に理由を必須化 |

固定値セット と NULL埋め をあえて別部品にしています。`constant()` は
**常に**固定値を設定し、`fill_null()` は**入力が NULL のときだけ**置換
します。この2つを混同すると、原因の分かりにくいデータ不具合につながります。

`zero_pad()` は、入力が指定桁数より長いと `lpad()` が右側を切り捨てます。
入力の最大長と変換後の固定長は、dbt_expectationsの既存テストで検証できます。

### あえて収録していないもの

`dbt` 標準、`dbt_utils`、`dbt_expectations` にある処理は、このパッケージでは
再実装しません。利用側プロジェクトで必要なパッケージを導入して使用します。

以下のテスト例を使う場合は、利用側の `packages.yml` にパッケージを追加します。
このリポジトリ自体は依存しません。`<PINNED_VERSION>` はdbt Package Hubで利用中の
dbtバージョンとの互換性を確認し、具体的なバージョンへ置き換えてください。

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: "<PINNED_VERSION>"
  - package: calogica/dbt_expectations
    version: "<PINNED_VERSION>"
```

追加後に `dbt deps` を実行します。

| 要件 | 使うもの |
|---|---|
| 文字列結合 | `dbt.concat(['a', 'b'])` |
| 数値の範囲・非負 | `dbt_utils.accepted_range` |
| 文字列長の完全一致 | `dbt_expectations.expect_column_value_lengths_to_equal` |
| 文字列長の範囲・上限 | `dbt_expectations.expect_column_value_lengths_to_be_between` |
| 特定の固定値を禁止 | `dbt_expectations.expect_column_values_to_not_be_in_set` |

```yaml
columns:
  - name: order_count
    data_tests:
      - dbt_utils.accepted_range:
          arguments:
            min_value: 0

  - name: member_code
    data_tests:
      - dbt_expectations.expect_column_value_lengths_to_equal:
          arguments:
            value: 6

  - name: source_code
    data_tests:
      - dbt_expectations.expect_column_value_lengths_to_be_between:
          arguments:
            min_value: 1
            max_value: 8

  - name: region_code
    data_tests:
      - not_null
      - dbt_expectations.expect_column_values_to_not_be_in_set:
          arguments:
            value_set: ['99']
          config:
            severity: warn
```

`dbt.concat()` は dbt 本体に同梱されているcross-databaseマクロです:

```sql
{{ dbt.concat(['last_name', "' '", 'first_name']) }} as full_name
```

SQLリテラル（固定値）を混ぜる場合、クォートの入れ子に注意してください。上の例のように
Jinja の文字列の中に SQL のシングルクォートを書きます。

## 汎用テストについて

このパッケージ独自のgeneric testは `placeholder_requires_reason` だけです。
プレースホルダ値そのものの禁止は `dbt_expectations` で検証できますが、このテストは
「プレースホルダを使う場合は理由列が必要」という複数列の条件を検証します。

```yaml
columns:
  - name: region_code
    data_tests:
      - not_null
      - common_transforms.placeholder_requires_reason:
          arguments:
            placeholder: '99'
            reason_column: region_unknown_reason
```

`region_code = '99'` かつ `region_unknown_reason` がNULLまたは空文字の行を
違反として返します。

---

# 第1部 — パッケージを使う

プロジェクトの `packages.yml` に追加します:

```yaml
packages:
  - git: "https://github.com/toshihue/dbt-common-transforms.git"
    revision: v1.2.0        # 必ずタグを指定する
```

インストール:

```sh
dbt deps
```

モデル内でマクロを呼び出します。パッケージ名の接頭辞を付けることで、
呼び出し箇所を見ただけで依存関係が分かります:

```sql
-- models/members_cleaned.sql
select
    member_id,
    {{ common_transforms.change_case(
         common_transforms.normalize_text('member_name'), case='initcap') }} as member_name,
    {{ common_transforms.change_case('email', case='lower') }}       as email,
    {{ common_transforms.change_case('member_code', case='upper') }} as member_code,
    {{ common_transforms.fill_null('region_code', default_value='99') }} as region_code,
    {{ common_transforms.fill_null('order_count', kind='number', default_value=0) }} as order_count,
    {{ common_transforms.standard_constants() }},
    {{ common_transforms.audit_columns() }}
from {{ ref('raw_members') }}
```

シード・コードマスタとの結合・全マクロ・全generic testの実行検証は
`integration_tests/` にあります。

### 利用側で必須の設定

`constant()` と `standard_constants()` は、利用側プロジェクトの
`dbt_project.yml` に `constants` var が定義されていないとコンパイルエラーに
なります。組織固有の値であり、妥当な既定値が存在しないためです:

```yaml
vars:
  constants:
    system_code: 'KIRIN01'
    record_type: '1'
    created_by: 'BATCH'
```

### 任意の上書き設定

他のマクロは無設定でも動作します。必要なら上書きしてください:

```yaml
vars:
  unknown_string: '未設定'
  unknown_number: 0
  epoch_date: '1900-01-01'
```

### パッケージ側の vars は利用側の既定値にならない

**このパッケージ**の `dbt_project.yml` で設定した vars は、利用側の
プロジェクトには伝播しません。パッケージのマクロが `var('x')` を呼ぶと、
dbt は**ルートプロジェクト**の vars を参照します。

これは頻繁に誤解される点です。パッケージをインストールし、その
`dbt_project.yml` にもっともらしい既定値が書かれているのを見て、それが
効いていると思い込む、というパターンです。無設定でも動作させたい
パッケージのマクロは、`var('unknown_string', 'UNKNOWN')` のように固定値の
フォールバックを渡す必要があります。このパッケージも `constants` を除いて
そうしています。

### 生成された SQL を必ず見る

ここが一番理解の進むポイントです:

```sh
dbt compile --select members_cleaned
# target/compiled/<プロジェクト名>/models/members_cleaned.sql を開く
```

マクロはウェアハウスが実行する関数ではなく、**SQL を生成するもの**です。
展開後の SQL を見ることで、これが腑に落ちます。

モデルを介さずマクロ単体を実行することもできます:

```sh
dbt run-operation my_macro --args '{some_key: some_value}'
```

---

# 第2部 — 自分でパッケージを作る

dbtパッケージは、`dbt_project.yml` を含むGitリポジトリとして作成できます。
Gitパッケージにはビルドや公開処理は不要で、タグまたはcommitを利用側から参照します。
広く公開する場合はdbt Package Hubへ登録する方法もあります。最小構成は次です:

```
my-package/
├── dbt_project.yml
├── macros/
│   └── my_macro.sql
└── tests/
    └── generic/
```

## 1. `dbt_project.yml`

```yaml
name: 'my_package'          # 呼び出し時の接頭辞になります: {{ my_package.my_macro() }}
version: '0.1.0'
config-version: 2

require-dbt-version: ">=1.10.0,<3.0.0"

macro-paths: ["macros"]
test-paths: ["tests"]
```

**利用側がdbt Fusionエンジンを使う場合、`require-dbt-version` は必須です。**
Fusionは範囲に `2.0.0` を含むパッケージしかインストールしません。
`require-dbt-version` を書いていないパッケージは `dbt deps` の時点で
拒否されます。

パッケージの `dbt_project.yml` に `profile:` は不要です。パッケージ自身が
ウェアハウスに接続することはなく、利用側プロジェクトの接続を使って動作します。

## 2. マクロを書く

```sql
{% macro my_macro(column) %}
    /* 呼び出し箇所にそのまま貼り込まれる SQL */
{% endmacro %}
```

長く運用して効いてくる指針:

- **1ファイル1マクロ**、ファイル名はマクロ名と一致させる。探しやすさが違います。
- **`{# ... #}` ブロックで使用例を書く。** 呼び出す側が読むドキュメントは、
  実質これだけです。
- **不正な入力には大きな声で失敗する。** 実行時に誤ったデータが出るより、
  `exceptions.raise_compiler_error()` でコンパイル時に落ちる方が良いです。
  `fill_null` と `constant` が例になっています。
- **既定値は `var('name', フォールバック)` で渡す。** 利用側が設定して
  いなくても動作します。
- **SQL文字列を生成するときはシングルクォートをエスケープする。**
  `constant`、`fill_null`、`zero_pad` は `O'Brien` を `O''Brien` として生成します。
  `integration_tests/tests/assert_escaped_literals.sql` が回帰テストです。
- **ウェアハウス固有のエスケープ規則を実機で検証する。** `normalize_text` が
  バックスラッシュを2重にしているのは、Snowflakeが `\x` をエスケープとして
  解釈するためです。

## 3. git タグでバージョン管理する

```sh
git tag -a v0.1.0 -m "First release"
git push origin v0.1.0
```

利用側は `revision: v0.1.0` でピン留めします。ブランチではなくタグを指定
することが、他プロジェクトの下で自分のパッケージが勝手に変わるのを防ぎます。
変更のたびにタグを上げ、既存のタグは決して動かさないでください。

複数バージョンの共存は、これだけで実現できます。git リポジトリは全履歴を
保持しているため、`v0.1.0` を参照しているプロジェクトと `v1.0.0` を参照して
いるプロジェクトが同時に存在できます。

なお **git パッケージはバージョン範囲指定に対応していません。** hub
パッケージの `version: [">=1.0.0", "<2.0.0"]` のような書き方はできず、
`revision` は常に単一の参照です。つまり利用側は手動で上げる必要があります。

## 4. 公開リポジトリか、プライベートか

公開リポジトリは認証情報なしで HTTPS 経由でインストールできるため、圧倒的に
簡単です。プライベートリポジトリは利用側の環境にデプロイキーやトークンの
設定が必要で、実運用の社内パッケージでは行う価値がありますが、ワークショップ
中に増やしたくない手順ではあります。

## 5. 共有する前に

- `integration_tests` で `dbt deps` を実行する
- `dbt build --no-partial-parse` を通し、モデル・seed・data testを実行する
- 終了コードだけでなく、生成されたSQLと期待値比較の結果を確認する
- シングルクォートやNULLなど、壊れやすい境界値をfixtureに含める

---

## dbt Platform Studioについての注意

Studioでも、現在のプロジェクトに接続されたGitリポジトリをdbtパッケージとして
開発できます。このリポジトリがその構成です。

制約は、同じStudioプロジェクトから別のリモートリポジトリを新規作成・編集する
用途には向かないことです。パッケージ本体の検証には、同じリポジトリ内に
`integration_tests/` を独立dbtプロジェクトとして置き、Project subdirectoryを
切り替えて実行します。

別リポジトリの利用側プロジェクトでは、`packages.yml` にタグを指定して
パッケージを導入し、`dbt deps` を実行します。

## 動作環境

- **Snowflake** で検証済み
- `require-dbt-version: ">=1.10.0,<3.0.0"` — dbt Core 1.10 以降および
  Fusion エンジンでインストール可能
- 使用している関数は `regexp_replace`、`initcap`、`upper`、`lower` です。
  いずれも広く利用可能ですが、正規表現の空白クラスや文字列エスケープの
  規則はプラットフォームごとに異なります。特に `normalize_text` の
  `\x{3000}` の扱いは Snowflake 固有です。他のプラットフォームで使う前に
  必ず再検証してください。
