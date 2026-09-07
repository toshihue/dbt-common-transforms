# common_transforms

再利用可能な変換部品を集めた小さな dbt パッケージです。あわせて、**自分で
パッケージを作る方法**の実例にもなっています。

動作確認はすべて Snowflake で行っています。

## 収録している部品

| 部品 | 種類 | 用途 |
|---|---|---|
| `constant(key)` / `standard_constants()` | マクロ | 固定値セット — 入力に関係なくリテラルを設定 |
| `normalize_text(column)` | マクロ | 文字列加工 — 前後空白の除去と、全角スペースを含む連続空白の圧縮 |
| `change_case(column, case)` | マクロ | 文字列加工 — lower / upper / initcap |
| `fill_null(column, kind)` | マクロ | NULL埋め — vars から型に応じた既定値 |
| `audit_columns()` | マクロ | 標準的な監査列 |
| `region_master.csv` | シード | 固定値の集合 — コードマスタをバージョン管理下のデータとして持つ |
| `non_negative` | 汎用テスト | 負数を検出（自作テストの入門例） |
| `not_null_or_placeholder` | 汎用テスト | NULL **または** プレースホルダのまま残っている行を検出 |

固定値セット と NULL埋め をあえて別部品にしています。`constant()` は
**常に**リテラルを設定し、`fill_null()` は**入力が NULL のときだけ**置換
します。この2つを混同すると、原因の分かりにくいデータ不具合につながります。

## 汎用テストの自作について

同梱の2つのテストは「広く使われている標準的なテスト」ではなく、**汎用テストを
自作する方法の例**です。実務で頻出する要件は、まず dbt 標準と `dbt_utils` で
足りるかを確認してください。

| 要件 | 使うもの |
|---|---|
| 必須・一意 | `not_null` / `unique`（dbt 標準） |
| コード値の列挙 | `accepted_values`（dbt 標準） |
| 外部キー整合性 | `relationships`（dbt 標準） |
| 複合キーの一意性 | `dbt_utils.unique_combination_of_columns` |
| 条件付きの整合性 | `dbt_utils.relationships_where`、または任意のテストに `config: where:` |
| 数値の範囲・非負 | `dbt_utils.accepted_range` |
| 欠損率の閾値 | `dbt_utils.not_null_proportion` |
| 空文字の禁止 | `dbt_utils.not_empty_string` |
| 件数の一致 | `dbt_utils.equal_rowcount` |
| 日付の順序 | `dbt_utils.expression_is_true` |

上記で足りない要件が出たときに、`tests/generic/` に `{% test %}` を書いて
部品化します。書き方の要点は「問題のあるレコードを返す SQL を書く」ことだけ
です。0件なら成功、1件以上なら失敗です。

---

# 第1部 — パッケージを使う

プロジェクトの `packages.yml` に追加します:

```yaml
packages:
  - git: "https://github.com/toshihue/dbt-common-transforms.git"
    revision: v1.0.0        # 必ずタグを指定する
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

シード・コードマスタとの結合・テストまで含んだ実行可能な完全版は
`examples/` にあります。

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
パッケージのマクロは、`var('unknown_string', 'UNKNOWN')` のようにリテラルの
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

dbt パッケージとは、dbt プロジェクトが入った git リポジトリにすぎません。
公開先のレジストリもビルド手順もありません。最小構成はこれだけです:

```
my-package/
├── dbt_project.yml
└── macros/
    └── my_macro.sql
```

## 1. `dbt_project.yml`

```yaml
name: 'my_package'          # 呼び出し時の接頭辞になります: {{ my_package.my_macro() }}
version: '0.1.0'
config-version: 2

require-dbt-version: ">=1.10.0,<3.0.0"

macro-paths: ["macros"]
seed-paths: ["seeds"]
test-paths: ["tests"]
```

**利用側が dbt Fusion エンジンを使う場合、`require-dbt-version` は必須です。**
Fusion は範囲に `2.0.0` を含むパッケージしかインストールしません。
`require-dbt-version` を書いていないパッケージは `dbt deps` の時点で
拒否されます。自作パッケージが Fusion で動かない原因として最も多いのが
これです。

パッケージの `dbt_project.yml` に `profile:` は不要です。パッケージ自身が
ウェアハウスに接続することはなく、利用側プロジェクトの中で、利用側の接続を
使って動作します。

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
- **文字列のエスケープに注意する。** `normalize_text` がバックスラッシュを
  2重にしているのは、Snowflake が `\x` をエスケープとして解釈するためです。
  必ず実際のウェアハウスで検証してください。マクロは、SQL がデータベースに
  届く直前まで正しく見えます。

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

- 検証用のプロジェクトで `dbt deps && dbt compile` を通す
- 終了コードだけでなく、生成された SQL を目で確認する
- 実際にウェアハウスに対して SQL を実行する。マクロは正常にコンパイルされて
  なお、不正な SQL を生成することがあります

---

## dbt platform の IDE についての注意

**IDE からパッケージを作ることはできません。** IDE はプロジェクトに紐づいた
単一のリポジトリに固定されているため、2つ目のリポジトリを作成・編集できない
ためです。ローカルに dbt をインストールせずにワークショップを行う場合、
現実的な流れはこうなります:

1. **作る側** — GitHub の Web UI でリポジトリを作成し、ファイルを追加し、
   タグを打つ
2. **使う側** — dbt platform の IDE で `packages.yml` を追加し、`dbt deps`
   を実行してマクロを呼ぶ

ブラウザだけで、作成 → 公開 → 利用 のサイクル全体を体験できます。

## 動作環境

- **Snowflake** で検証済み
- `require-dbt-version: ">=1.10.0,<3.0.0"` — dbt Core 1.10 以降および
  Fusion エンジンでインストール可能
- 使用している関数は `regexp_replace`、`initcap`、`upper`、`lower` です。
  いずれも広く利用可能ですが、正規表現の空白クラスや文字列エスケープの
  規則はプラットフォームごとに異なります。特に `normalize_text` の
  `\x{3000}` の扱いは Snowflake 固有です。他のプラットフォームで使う前に
  必ず再検証してください。
