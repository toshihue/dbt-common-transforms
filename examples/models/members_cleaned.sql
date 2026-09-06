{#
    Every common_transforms component in one model, against deliberately messy
    seed data. Each macro has a visible effect — diff this against the raw seed.

    Components used:
      normalize_text        文字列加工 — whitespace incl. 全角スペース
      change_case           文字列加工 — lower / upper / initcap
      fill_null             NULL埋め — string, number and date
      standard_constants    固定値セット — assigned unconditionally
      audit_columns         audit metadata
      region_master (seed)  固定値の集合 — code master join
#}

with raw_members as (

    select * from {{ ref('raw_members') }}

),

cleaned as (

    select
        member_id,

        -- 文字列加工: collapse whitespace (including 全角スペース), then
        -- normalize case. Order matters — normalize_text runs first so
        -- initcap sees single spaces and capitalizes each word once.
        {{ common_transforms.change_case(
             common_transforms.normalize_text('member_name'),
             case='initcap') }}                                     as member_name,

        -- lower: emails are identity, and case-inconsistent keys silently
        -- fail to join.
        {{ common_transforms.change_case('email', case='lower') }}  as email,

        -- upper: codes are conventionally uppercase in the warehouse even
        -- when the source system sends them lowercase.
        {{ common_transforms.change_case('member_code', case='upper') }} as member_code,

        -- Codes arrive padded with stray spaces.
        {{ common_transforms.normalize_text('postal_code') }}       as postal_code,

        -- NULL埋め with a default that is itself a valid master code, so
        -- unknown regions still join to region_master ('99' = 不明) instead of
        -- dropping out of downstream reports.
        {{ common_transforms.fill_null(
             'region_code', default_value='99') }}                  as region_code,

        -- NULL埋め: numeric and date
        {{ common_transforms.fill_null(
             'order_count', kind='number', default_value=0) }}      as order_count,
        {{ common_transforms.fill_null(
             'last_login_date', kind='date') }}                     as last_login_date

    from raw_members

),

final as (

    select
        cleaned.member_id,
        cleaned.member_name,
        cleaned.email,
        cleaned.member_code,
        cleaned.postal_code,

        -- 固定値の集合: resolve the code against the master table
        cleaned.region_code,
        region_master.region_name_ja,
        region_master.region_name_en,

        cleaned.order_count,
        cleaned.last_login_date,

        -- 固定値セット: emit the whole configured set at once.
        --
        -- The alternative is one constant at a time, when you only want some
        -- of them or need a different alias:
        --
        --     {{ '{{' }} common_transforms.constant('system_code') {{ '}}' }} as source_system,
        --
        -- Don't mix the two for the same key — standard_constants() already
        -- emits every key in the `constants` var, so adding constant('system_code')
        -- alongside it produces two columns called system_code.
        {{ common_transforms.standard_constants() }},

        {{ common_transforms.audit_columns() }}

    from cleaned

    left join {{ ref('region_master') }} as region_master
        on cleaned.region_code = region_master.region_code

)

select * from final
