# プロンプト: common_transforms を使ったシードとモデルの生成

以下のブロックを dbt Copilot、Claude、その他のコーディングアシスタントに
貼り付けてください。冒頭の角括弧2行を自分の題材に置き換え、それ以外はその
まま使ってください。API リファレンスと制約条件が、出力を正しく保つ部分です。

ワークショップで有用なのは、受講者ごとに `SUBJECT` を変えれば、同じ部品に
対して**それぞれ異なるデータセット**が生成される点です。全員が同じ例を
写経するより、API を理解しているかどうかが問われます。

---

```
Snowflake 上の dbt プロジェクトで、common_transforms というパッケージが
インストール済みです。このパッケージの全部品を使うシードとモデルを生成して
ください。

SUBJECT: [例: 店舗マスタ — 日本の小売店舗]
ROWS: [例: 6行]

## パッケージ API — 以下のシグネチャを厳密に使用すること

すべてのマクロは `common_transforms.` の接頭辞を付けて呼び出す。

`common_transforms.normalize_text(column)`
    前後の空白を除去し、全角スペース（U+3000）を含む連続した空白を半角
    スペース1つに圧縮する。結果が空文字列または空白のみの場合は NULL を
    返す。

`common_transforms.change_case(column, case='upper')`
    case は 'upper' | 'lower' | 'initcap'。それ以外はコンパイルエラーに
    なる。メールアドレスと結合キーには 'lower'、コード類には 'upper'、
    人名には 'initcap' を使う。

`common_transforms.fill_null(column, kind='string', default_value=none)`
    kind は 'string' | 'number' | 'date'。入力が NULL のときのみ置換する。
    default_value を省略した場合は vars の unknown_string /
    unknown_number / epoch_date にフォールバックする。default_value は
    その呼び出し箇所のみ上書きする。

`common_transforms.constant(key)`
    `constants` var から1つのリテラルを、型に応じてクォートして出力する。

`common_transforms.standard_constants()`
    `constants` var の全キーを `<リテラル> as <キー>` 形式でカンマ区切りで
    出力する。末尾にカンマは付かない。standard_constants() が既に出力する
    キーに対して constant() を併用してはならない。同名の列が2つできる。

`common_transforms.audit_columns()`
    dbt_loaded_at、dbt_invocation_id、dbt_target_name、dbt_target_schema を
    出力する。前後どちらにもカンマを付けないため、select 句の最後に置く
    必要がある。

`ref('region_master')`
    パッケージが同梱するシード。列は region_code varchar(2)、
    region_name_ja、region_name_en、sort_order。コードは '01'〜'07' と、
    不明を意味する '99'。

`common_transforms.not_null_or_placeholder`（汎用テスト）
    NULL またはプレースホルダ値と一致する行を検出する。任意引数
    placeholder を持つ。

## 成果物

1. `seeds/<名前>.csv`
2. `seeds/schema.yml`
3. `models/<名前>_cleaned.sql`
4. `models/schema.yml`

## 要件

シードデータ:
- 上記の各マクロが、少なくとも1行で「目に見える効果」を持つこと。意図的に
  データを汚す: 前後の余分な空白、氏名の区切りに全角スペース、大文字に
  すべきコードを小文字で、大文字小文字が不統一なメールアドレス、そして
  文字列列・数値列・日付列それぞれに NULL を含める。
- テキスト列が「空白のみ」の行を少なくとも1行含めること。normalize_text が
  NULL を返し、それが空文字列とは明確に異なることが分かるようにする。
- region_code が NULL の行を少なくとも1行含めること。
- CSV で前後に空白を含むフィールドは必ずクォートすること。
- 自然な箇所には日本語を使うこと。もっともらしい内容にし、意味のない文字列
  は避けること。

`seeds/schema.yml`:
- 全列に対して `config.column_types` を宣言すること。これは書式の好みでは
  なく必須である。型推論に任せると '02' のようなコードが数値の 2 として
  読み込まれ、region_master との結合が静かに成立しなくなり、先頭のゼロも
  失われる。コード類は「数値に見えるが文字列」である。
- 主キーに unique と not_null テストを付けること。

モデル:
- 変換を行う `cleaned` CTE と、region_master 結合および定数・監査列を扱う
  `final` CTE に分けること。1つの select にまとめないこと。
- normalize_text と change_case を組み合わせる場合は、normalize_text を
  先に呼ぶこと。先に全角スペースを圧縮することで initcap が正しい語境界を
  認識する。順序を逆にすると結果が変わる。
- 地域コードの fill_null には、region_master に実在するコードを既定値と
  して使うこと（`default_value='99'`）。地域不明の行も結合を通過し、下流の
  レポートから消えないようにするため。
- 件数列の fill_null には default_value=0 を使うこと。パッケージ既定の
  -1 ではない。
- 各変換に、固定値セット / 文字列加工 / NULL埋め のどれを実装しているかを
  日本語のコメントで明記すること。

`models/schema.yml`:
- NULL埋め を行った全列に not_null
- 地域コードから `ref('region_master')` への `relationships` テスト
- 正規化したテキスト列に `common_transforms.not_null_or_placeholder` を
  `config: severity: warn` で付ける。空白のみの行は正当に NULL になるため、
  ビルドを止めずに可視化したい

## 併せて回答すること

- 自分の dbt_project.yml に追加すべき `vars:` ブロック。`constants` は必須で
  あり、これがないと standard_constants() はコンパイルエラーになる。また
  パッケージ側で設定した vars は利用側に伝播しないことにも触れること。
- 実行すべきコマンドを、順番どおりに。
- 各行の変換前・変換後を並べた表。各マクロが説明どおりに動作したことを
  確認できるようにするため。

## 制約

- Snowflake SQL のみ。
- ロジックをインラインで再実装しないこと。必ずマクロを呼ぶこと。
- 上記に記載のないマクロを創作しないこと。
- `packages.yml` はプロジェクトのルートに置くこと。models/ 配下には絶対に
  置かないこと。
```

---

## 生成結果の確認

生成されたファイルは「もっともらしく見える」だけで、実行するまで検証済みでは
ありません:

```sh
dbt deps
dbt seed
dbt compile --select <名前>_cleaned    # target/compiled/... を読む — これが本当の確認
dbt build  --select <名前>_cleaned
```

プロンプトで対策していますが、それでも起きやすい失敗が2つあります:

- **ロジックのインライン化。** `{{ common_transforms.fill_null('x') }}` では
  なく `coalesce(x, 'UNKNOWN')` を出力してくることがあります。動作はします
  が、演習の意味がなくなります。モデル内を `coalesce(`、`upper(`、`lower(`、
  `regexp_replace(` で grep してください。
- **`column_types` の欠落。** ビルドは成功し、`relationships` テストだけが
  失敗するため、原因がシードにあると気付きにくくなります。コード列が文字列
  型になっているか確認してください。
