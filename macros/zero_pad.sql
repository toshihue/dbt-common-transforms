{#
    zero_pad: 0埋め（左詰めパディング）の共通部品

    桁数の足りない値の左側を埋めて、固定長の文字列にそろえます。
    コード類・伝票番号・郵便番号など「桁数が意味を持つ列」で使います。

    使い方:
        {{ common_transforms.zero_pad('region_code', 2) }}      as region_code
        {{ common_transforms.zero_pad('member_id', 8) }}        as member_id
        {{ common_transforms.zero_pad('branch_code', 5, pad='*') }} as branch_code

    length: そろえたい桁数（必須）
    pad:    埋める文字1字（既定は '0'）

    数値列でも使えます。内部で文字列にキャストしてから埋めるためです。
    1 は 2桁指定で '01' になります。ここが目的の中心です。CSV や外部
    システムから来たコードが数値として読み込まれ、'01' が 1 になって
    しまう事故は頻出します。

    NULL の扱い:
    NULL は NULL のまま返ります。埋める対象がないためです。既定値を
    入れたい場合は fill_null() と組み合わせてください。適用順に注意し、
    先に NULL を埋めてから桁をそろえます:

        {{ common_transforms.zero_pad(
             common_transforms.fill_null('region_code', default_value='0'), 2) }}

    重要 — 桁数を超える値は切り捨てられます:
    Snowflake の lpad() は、入力が length より長い場合に右側を捨てます。
    lpad('12345', 3, '0') は '123' です。エラーにはならず、静かに桁が
    落ちます。0埋めのつもりで使って、想定より長いデータが混ざっていた
    場合、この挙動はデータ欠損として現れます。

    切り捨てを防ぐには、zero_pad() を適用する前の列で最大長を検証してください。
    dbt_expectations を利用する場合は、次のように書けます:

        columns:
          - name: region_code
            data_tests:
              - dbt_expectations.expect_column_value_lengths_to_be_between:
                  arguments:
                    min_value: 0
                    max_value: 2

    変換後の列が固定長であることは
    dbt_expectations.expect_column_value_lengths_to_equal で検証できます。
    外部パッケージについて:
    0埋めそのものを提供するマクロは dbt 標準にも dbt_utils にもありません。
    lpad() はほとんどのウェアハウスが備える標準的な SQL 関数のため、
    パッケージ側で用意されていないという事情です。このマクロは lpad() の
    薄いラッパーであり、キャストと桁数の指定を1箇所にまとめることが目的
    です。
#}

{% macro zero_pad(column, length, pad='0') %}

    {%- if length is not number or length < 1 or length != (length | int) -%}
        {{ exceptions.raise_compiler_error(
            "zero_pad: length must be a positive integer, got '" ~ length ~ "'"
        ) }}
    {%- endif -%}

    {%- if pad is not string or pad | length != 1 -%}
        {{ exceptions.raise_compiler_error(
            "zero_pad: pad must be a single character, got '" ~ pad ~ "'"
        ) }}
    {%- endif -%}

    {#
        column を先に文字列へ変換するのは、数値として読み込まれたコードにも
        先頭の埋め文字を付けられるようにするためです。dbt.type_string() を使うことで、
        実行先アダプターに対応する文字列型へ展開されます。その後 lpad() で指定桁数に
        そろえます。

        Jinja 展開後の例（Snowflake）:
          {{ common_transforms.zero_pad('region_code', 2) }}
          -> lpad(cast(region_code as varchar), 2, '0')
    #}
    {# pad がシングルクォートでもSQL文字列を閉じないよう、2つ重ねてエスケープします。 #}
    {%- set escaped_pad = pad | replace("'", "''") -%}

    lpad(cast({{ column }} as {{ dbt.type_string() }}), {{ length }}, '{{ escaped_pad }}')

{% endmacro %}
