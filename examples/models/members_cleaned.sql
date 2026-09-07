{#
    common_transforms の全部品を1つのモデルで使った例です。意図的に汚した
    シードデータを使っているため、各マクロの効果が目に見えます。元のシードと
    出力を見比べてください。

    使用している部品:
      normalize_text        文字列加工 — 全角スペースを含む空白の正規化
      change_case           文字列加工 — lower / upper / initcap
      fill_null             NULL埋め — 文字列・数値・日付
      standard_constants    固定値セット — 入力に関係なく常に設定
      audit_columns         監査列
      region_master（seed） 固定値の集合 — コードマスタとの結合
#}

with raw_members as (

    select * from {{ ref('raw_members') }}

),

cleaned as (

    select
        member_id,

        -- 文字列加工: まず空白（全角スペース含む）を圧縮し、その後に
        -- 大文字小文字を整えます。順序が重要です。normalize_text を先に
        -- 実行することで initcap が正しい語境界を認識できます。
        {{ common_transforms.change_case(
             common_transforms.normalize_text('member_name'),
             case='initcap') }}                                     as member_name,

        -- lower: メールアドレスは識別子です。大文字小文字が不統一な結合
        -- キーは、エラーにならず静かに結合漏れを起こします。
        {{ common_transforms.change_case('email', case='lower') }}  as email,

        -- upper: コード類はソースが小文字で送ってきても、ウェアハウス側
        -- では大文字に統一するのが慣例です。
        {{ common_transforms.change_case('member_code', case='upper') }} as member_code,

        -- コードに余分な空白が付いて届くケースへの対応。
        {{ common_transforms.normalize_text('postal_code') }}       as postal_code,

        -- NULL埋め: 既定値に region_master に実在するコードを使います。
        -- '99'（不明）を使うことで、地域不明の行も結合が成立し、下流の
        -- レポートから消えません。
        {{ common_transforms.fill_null(
             'region_code', default_value='99') }}                  as region_code,

        -- NULL埋め: 数値と日付
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

        -- 固定値の集合: コードをマスタテーブルで名称に解決します
        cleaned.region_code,
        region_master.region_name_ja,
        region_master.region_name_en,

        cleaned.order_count,
        cleaned.last_login_date,

        -- 固定値セット: 定義済みの定数をまとめて出力します。
        --
        -- 一部だけ使いたい場合や別名を付けたい場合は、1つずつ出力する
        -- 書き方もあります:
        --
        --     {{ '{{' }} common_transforms.constant('system_code') {{ '}}' }} as source_system,
        --
        -- ただし同じキーで両方を使わないでください。standard_constants()
        -- は `constants` の全キーを出力するため、constant('system_code') を
        -- 併用すると system_code という列が2つできます。
        {{ common_transforms.standard_constants() }},

        {{ common_transforms.audit_columns() }}

    from cleaned

    left join {{ ref('region_master') }} as region_master
        on cleaned.region_code = region_master.region_code

)

select * from final
