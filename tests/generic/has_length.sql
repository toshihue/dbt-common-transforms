{#
    has_length: 桁数（文字列長）を検証する汎用テスト

    「必ず N 桁であるべき列」を検証します。郵便番号7桁、地域コード2桁、
    伝票番号8桁のように、桁数そのものが仕様になっている列が対象です。

    zero_pad との対で使うことを想定しています。lpad() は入力が指定桁数
    より長いとき、エラーを出さずに右側を切り捨てます。0埋めした列に
    このテストを掛けておくと、その静かな桁落ちを検出できます。

    schema.yml での使い方:

        version: 2

        models:
          - name: members_cleaned
            columns:
              - name: region_code
                data_tests:
                  - common_transforms.has_length:
                      arguments:
                        length: 2
              - name: postal_code
                data_tests:
                  - common_transforms.has_length:
                      arguments:
                        length: 7

    model と column_name は dbt が自動的に渡します。length は必須です。

    引数は `arguments:` の下に書きます。この入れ子は dbt 1.10 以降の形式で、
    Fusion では必須です。旧来のトップレベル記法はエラーになります:

        [error] Deprecated test arguments: ["length"] at top-level detected.

    NULL の扱い:
    NULL は通過します。桁数の話と欠損の話は別の関心事であり、1つの
    テストに混ぜると失敗時に原因が読み取れなくなるためです。両方を
    検証したい場合は not_null を併記してください:

        data_tests:
          - not_null
          - common_transforms.has_length:
              arguments:
                length: 2

    数値列に掛けた場合:
    文字列にキャストしてから長さを数えます。数値の 1 は '1' の1桁です。
    ただし数値列の桁数を数える設計自体を疑ってください。桁数が意味を
    持つのはコードであり、コードは文字列として持つべきです。

    外部パッケージについて:
    同じことは dbt_expectations でも書けます。桁数の検証はこちらが
    定番です:

        - dbt_expectations.expect_column_value_lengths_to_equal:
            arguments:
              value: 2

    範囲で見たい場合は dbt_expectations 側にしかない機能です:

        - dbt_expectations.expect_column_value_lengths_to_be_between:
            arguments:
              min_value: 1
              max_value: 5

    dbt_expectations は Fusion でもインストールできます
    （require-dbt-version が 2.0.0 を含むため）。実運用で桁数以外にも
    分布や統計の検証が必要なら、自作せず dbt_expectations を入れる方が
    妥当です。このテストを同梱しているのは、パッケージを1つ増やさずに
    済ませたい場合の最小構成と、引数付き汎用テストの実装例を兼ねる
    ためです。

    dbt_utils だけで済ませることもできます:

        - dbt_utils.expression_is_true:
            arguments:
              expression: "length(region_code) = 2"
#}

{% test has_length(model, column_name, length) %}

{%- if length is not number or length < 0 -%}
    {{ exceptions.raise_compiler_error(
        "has_length: length must be a non-negative number, got '" ~ length ~ "'"
    ) }}
{%- endif -%}

select *
from {{ model }}
where {{ column_name }} is not null
  and length(cast({{ column_name }} as {{ dbt.type_string() }})) != {{ length }}

{% endtest %}
