{#
    constant: constants var から名前付き固定値を1つ出力するマクロ

    数値はクォートせず、文字列はSQLリテラル（固定値）としてクォートします。
    利用側プロジェクトの dbt_project.yml に constants var が必要です。

    使い方:
        {{ common_transforms.constant('system_code') }} as system_code

    Jinja展開後の例:
        {{ common_transforms.constant('system_code') }}
        -> 'DEMO01'
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
        {# O'Brien を 'O''Brien' として生成し、SQL文字列を閉じないようにします。 #}
        {%- set escaped_value = (value | string) | replace("'", "''") -%}
        '{{ escaped_value }}'
    {%- endif -%}
{% endmacro %}
