{#
    SQL固定値にシングルクォートを含む場合も、生成SQLが壊れず値を保持することを
    検証します。constant() は members_cleaned の created_by でも検証されます。
#}

with actual as (

    select
        {{ common_transforms.fill_null(
             'cast(null as varchar)', default_value="O'Brien") }} as filled_value,
        {{ common_transforms.zero_pad("'A'", 2, pad="'") }} as padded_value

)

select *
from actual
where filled_value != 'O''Brien'
   or padded_value != '''A'
