# integration_tests

`common_transforms` を利用側プロジェクトとしてインストールし、Snowflake上で
生成SQLとデータテストを検証する独立したdbtプロジェクトです。

## 検証範囲

- 全マクロ: `constant`、`standard_constants`、`normalize_text`、`change_case`、
  `fill_null`、`zero_pad`、`audit_columns`
- `dbt_utils` / `dbt_expectations` と重複するgeneric testは実装せず、
  ルートREADMEに利用例を記載
- 独自generic test `placeholder_requires_reason` で、プレースホルダ使用時の
  理由列を検証
- `region_master` はパッケージに含めず、integration test専用のseed fixtureとして検証
- `tests/assert_members_cleaned.sql` によるfixtureと期待値の完全比較
- `tests/assert_escaped_literals.sql` によるシングルクォートの回帰テスト

## 実行

このディレクトリをdbtプロジェクトとして実行します。dbt PlatformではProject
subdirectoryを `integration_tests` に設定してください。

```sh
dbt deps
dbt build --no-partial-parse
```

`packages.yml` は親ディレクトリをlocal packageとして参照するため、未コミットの
パッケージ変更もそのまま検証できます。
