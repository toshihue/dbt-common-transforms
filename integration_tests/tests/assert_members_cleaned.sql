{#
    全マクロの決定的な出力をfixtureの期待値と比較します。
    監査列は実行ごとに値が変わるため、models/schema.yml の not_null で検証します。
#}

with actual as (

    select
        cast(member_id as varchar) as member_id,
        padded_member_id,
        member_name,
        email,
        member_code,
        postal_code,
        region_code,
        region_unknown_reason,
        region_name_ja,
        region_name_en,
        cast(order_count as varchar) as order_count,
        to_char(last_login_date, 'YYYY-MM-DD') as last_login_date,
        source_system_code,
        created_by,
        record_type,
        system_code

    from {{ ref('members_cleaned') }}

),

expected as (

    select
        column1 as member_id,
        column2 as padded_member_id,
        column3 as member_name,
        column4 as email,
        column5 as member_code,
        column6 as postal_code,
        column7 as region_code,
        column8 as region_unknown_reason,
        column9 as region_name_ja,
        column10 as region_name_en,
        column11 as order_count,
        column12 as last_login_date,
        column13 as source_system_code,
        column14 as created_by,
        column15 as record_type,
        column16 as system_code

    from values
        ('1', '0001', '山田 太郎', 'yamada.taro@example.com', 'AB-001', '100-0001', '02', null, '関東', 'Kanto', '3', '2026-08-01', 'KIRIN01', 'O''Brien', '1', 'KIRIN01'),
        ('2', '0002', '佐藤 花子', 'sato.hanako@example.co.jp', 'CD-002', '530-0001', '04', null, '近畿', 'Kinki', '0', '2026-07-15', 'KIRIN01', 'O''Brien', '1', 'KIRIN01'),
        ('3', '0003', 'Tanaka Ichiro', 'tanaka@example.com', 'EF-003', '810-0001', '99', 'ソース地域コード欠損', '不明', 'Unknown', '7', '1900-01-01', 'KIRIN01', 'O''Brien', '1', 'KIRIN01'),
        ('4', '0004', null, 'suzuki@example.com', 'GH-004', '060-0001', '01', null, '北海道・東北', 'Hokkaido-Tohoku', '0', '1900-01-01', 'KIRIN01', 'O''Brien', '1', 'KIRIN01'),
        ('5', '0005', '高橋 次郎', 'takahashi@example.com', 'IJ-005', '460-0001', '03', null, '中部', 'Chubu', '12', '2026-09-01', 'KIRIN01', 'O''Brien', '1', 'KIRIN01')

),

actual_not_expected as (

    select * from actual
    except
    select * from expected

),

expected_not_actual as (

    select * from expected
    except
    select * from actual

)

select 'actual_not_expected' as difference, *
from actual_not_expected

union all

select 'expected_not_actual' as difference, *
from expected_not_actual
