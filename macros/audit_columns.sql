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
    {#
        ロード時刻は SQL の current_timestamp() として残し、クエリ実行時刻を記録します。
        invocation_id・target・this は dbt の実行コンテキストからコンパイル時に展開し、
        どの dbt 実行がどのターゲット／スキーマへ書き込んだかを追跡できる列にします。

        Jinja 展開後の例（実行ごとの値は例示）:
          {{ common_transforms.audit_columns() }}
          -> current_timestamp() as dbt_loaded_at,
             '2f6c1b5a-0000-0000-0000-123456789abc' as dbt_invocation_id,
             'default' as dbt_target_name,
             'analytics' as dbt_target_schema
    #}
    current_timestamp()               as dbt_loaded_at,
    '{{ invocation_id }}'             as dbt_invocation_id,
    '{{ target.name }}'               as dbt_target_name,
    '{{ this.schema }}'               as dbt_target_schema
{% endmacro %}
