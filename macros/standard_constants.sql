{#
    standard_constants: constants var の全固定値をselectリストとして出力するマクロ

    キーをソートして生成順を安定させ、値の型判定とエスケープは constant() に
    集約します。同じキーを constant() でも出力すると同名列になるため、併用時は
    別名を付けてください。

    Jinja展開後の例:
        {{ common_transforms.standard_constants() }}
        -> 'BATCH' as created_by,
           '1' as record_type,
           'DEMO01' as system_code
#}

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
