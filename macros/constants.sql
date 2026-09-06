{#
    固定値セットの共通部品

    ETL tools (Informatica, DataStage, HULFT ...) call this a "constant" or
    "fixed value" component: assign a literal to an output column
    unconditionally, regardless of the input. This is NOT the same as NULL埋め,
    which only fires when the input is NULL — see fill_null().

    Two macros here:

    `constant(key)` — emit one named constant as a quoted SQL literal:

        select
            customer_id,
            {{ common_transforms.constant('system_code') }} as system_code
        from {{ ref('stg_customers') }}

    `standard_constants()` — emit the whole standard set at once:

        select
            customer_id,
            {{ common_transforms.standard_constants() }}
        from {{ ref('stg_customers') }}

    The values live in vars, so a consuming project overrides them in its own
    dbt_project.yml, and they can differ per environment:

        vars:
          constants:
            system_code: 'KIRIN01'
            created_by:  'BATCH'
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
