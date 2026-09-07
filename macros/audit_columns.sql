{#
    audit_columns: 監査列の共通部品

    標準的な監査列をまとめて出力します。select 句の最後に置いてください。
    先頭にカンマを付けていないため、直前の項目の後ろにカンマが必要です。

    使い方:
        select
            customer_id,
            customer_name,
            {{ common_transforms.audit_columns() }}
        from {{ ref('stg_customers') }}

    部品化の効果が最も分かりやすい例です。後から5つ目の監査列を追加したく
    なったとき、変更するのはこのファイル1箇所だけで、利用側は次回の
    dbt deps と実行で自動的に反映されます。
#}

{% macro audit_columns() %}
    current_timestamp()               as dbt_loaded_at,
    '{{ invocation_id }}'             as dbt_invocation_id,
    '{{ target.name }}'               as dbt_target_name,
    '{{ this.schema }}'               as dbt_target_schema
{% endmacro %}
