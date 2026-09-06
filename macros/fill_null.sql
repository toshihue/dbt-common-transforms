{#
    fill_null: NULL埋めの共通部品

    Replaces NULL with a type-appropriate default. The defaults live in vars so
    they can be changed in one place, per project or per environment.

    Usage:
        {{ common_transforms.fill_null('region_code') }}                as region_code
        {{ common_transforms.fill_null('order_count', kind='number') }} as order_count
        {{ common_transforms.fill_null('ordered_at',  kind='date') }}   as ordered_at
        {{ common_transforms.fill_null('status', default_value='未設定') }} as status

    kind: 'string' (default) | 'number' | 'date'
    default_value: overrides the var for a single call site.
#}

{% macro fill_null(column, kind='string', default_value=none) %}

    {%- if kind not in ['string', 'number', 'date'] -%}
        {{ exceptions.raise_compiler_error(
            "fill_null: kind must be 'string', 'number' or 'date', got '" ~ kind ~ "'"
        ) }}
    {%- endif -%}

    {%- if kind == 'string' -%}
        {%- set fallback = default_value if default_value is not none
                           else var('unknown_string', 'UNKNOWN') -%}
        coalesce({{ column }}, '{{ fallback }}')

    {%- elif kind == 'number' -%}
        {%- set fallback = default_value if default_value is not none
                           else var('unknown_number', -1) -%}
        coalesce({{ column }}, {{ fallback }})

    {%- elif kind == 'date' -%}
        {%- set fallback = default_value if default_value is not none
                           else var('epoch_date', '1900-01-01') -%}
        coalesce({{ column }}, date '{{ fallback }}')

    {%- endif -%}

{% endmacro %}
