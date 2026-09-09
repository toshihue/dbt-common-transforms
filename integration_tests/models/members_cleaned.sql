{#
    common_transforms の全マクロを、利用側プロジェクトから実行検証するモデルです。
    意図的に汚した raw_members を変換し、期待値は tests/assert_members_cleaned.sql
    で検証します。
#}

with raw_members as (

    select * from {{ ref('raw_members') }}

),

cleaned as (

    select
        member_id,
        {{ common_transforms.zero_pad('member_id', 4) }} as padded_member_id,
        {{ common_transforms.change_case(
             common_transforms.normalize_text('member_name'),
             case='initcap') }} as member_name,
        {{ common_transforms.change_case('email', case='lower') }} as email,
        {{ common_transforms.change_case('member_code', case='upper') }} as member_code,
        {{ common_transforms.normalize_text('postal_code') }} as postal_code,
        {{ common_transforms.fill_null(
             'region_code', default_value='99') }} as region_code,
        {{ common_transforms.normalize_text(
             'region_unknown_reason') }} as region_unknown_reason,
        {{ common_transforms.fill_null(
             'order_count', kind='number', default_value=0) }} as order_count,
        {{ common_transforms.fill_null(
             'last_login_date', kind='date') }} as last_login_date

    from raw_members

),

final as (

    select
        cleaned.member_id,
        cleaned.padded_member_id,
        cleaned.member_name,
        cleaned.email,
        cleaned.member_code,
        cleaned.postal_code,
        cleaned.region_code,
        cleaned.region_unknown_reason,
        region_master.region_name_ja,
        region_master.region_name_en,
        cleaned.order_count,
        cleaned.last_login_date,
        {{ common_transforms.constant('system_code') }} as source_system_code,
        {{ common_transforms.standard_constants() }},
        {{ common_transforms.audit_columns() }}

    from cleaned

    left join {{ ref('region_master') }} as region_master
        on cleaned.region_code = region_master.region_code

)

select * from final
