{#
    audit_columns: 監査列の共通部品

    Emits a standard set of audit columns. Add it as the last item in a
    select list — note there is no leading comma, so put the comma before it.

    Usage:
        select
            customer_id,
            customer_name,
            {{ common_transforms.audit_columns() }}
        from {{ ref('stg_customers') }}

    This is the clearest demonstration of why packaging matters: when you later
    need a fifth audit column, you change it here and every consuming model
    picks it up on the next `dbt deps` + run.
#}

{% macro audit_columns() %}
    current_timestamp()               as dbt_loaded_at,
    '{{ invocation_id }}'             as dbt_invocation_id,
    '{{ target.name }}'               as dbt_target_name,
    '{{ this.schema }}'               as dbt_target_schema
{% endmacro %}
