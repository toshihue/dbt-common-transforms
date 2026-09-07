{#
    固定値セットの共通部品

    ETL ツール（Informatica、DataStage、HULFT など）で「固定値」「定数」
    コンポーネントと呼ばれる処理に相当します。入力値に関係なく、出力列に
    リテラルを常に設定します。

    NULL埋め とは別物です。fill_null() は入力が NULL のときだけ動作します
    が、こちらは常に上書きします。

    マクロは2つあります。

    `constant(key)` — 名前付き定数を1つ、クォート済みの SQL リテラルとして
    出力します:

        select
            customer_id,
            {{ common_transforms.constant('system_code') }} as system_code
        from {{ ref('stg_customers') }}

    `standard_constants()` — 定義済みの全定数をまとめて出力します:

        select
            customer_id,
            {{ common_transforms.standard_constants() }}
        from {{ ref('stg_customers') }}

    値は vars に持たせているため、利用側プロジェクトの dbt_project.yml で
    上書きでき、環境ごとに変えることもできます:

        vars:
          constants:
            system_code: 'KIRIN01'
            created_by:  'BATCH'

    注意: standard_constants() は `constants` の全キーを出力します。同じ
    キーに対して constant() を併用すると、同名の列が2つできてしまいます。
#}

{% macro constant(key) %}
    {%- set constants = var('constants', {}) -%}
    {%- if key not in constants -%}
        {{ exceptions.raise_compiler_error(
            "constant: '" ~ key ~ "' is not defined in the `constants` var. "
            ~ "Defined keys: " ~ (constants.keys() | list | join(', ') or '(none)')
        ) }}
    {%- endif -%}
    {%- set value = constants[key] -%}
    {%- if value is number -%}
        {{ value }}
    {%- else -%}
        '{{ value }}'
    {%- endif -%}
{% endmacro %}


{% macro standard_constants() %}
    {%- set constants = var('constants', {}) -%}
    {%- if constants | length == 0 -%}
        {{ exceptions.raise_compiler_error(
            "standard_constants: the `constants` var is empty. Define it in dbt_project.yml."
        ) }}
    {%- endif -%}
    {%- for key in constants | sort -%}
        {{ common_transforms.constant(key) }} as {{ key }}{{ "," if not loop.last }}
    {% endfor -%}
{% endmacro %}
