{#
    fill_null: NULL埋めの共通部品

    NULL を型に応じた既定値に置き換えます。既定値は vars に持たせている
    ため、プロジェクト単位・環境単位で1箇所だけ変更すれば済みます。

    使い方:
        {{ common_transforms.fill_null('region_code') }}                as region_code
        {{ common_transforms.fill_null('order_count', kind='number') }} as order_count
        {{ common_transforms.fill_null('ordered_at',  kind='date') }}   as ordered_at
        {{ common_transforms.fill_null('status', default_value='未設定') }} as status

    kind: 'string'（既定） | 'number' | 'date'
    default_value: その呼び出し箇所のみ var を上書きします。

    固定値セットとの違い:
    このマクロは入力が NULL の場合にのみ置換します。入力に関係なく常に
    リテラルを設定したい場合は constant() を使ってください。両者を混同
    すると、原因の分かりにくいデータ不具合につながります。
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
