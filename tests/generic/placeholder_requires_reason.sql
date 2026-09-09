{#
    placeholder_requires_reason: プレースホルダ値を使う行に理由を必須化する汎用テスト

    NULLを「不明」コードなどの固定値で補完すると、not_null や relationships は
    合格しても、なぜ不明なのかを追跡できないことがあります。このテストは、対象列が
    指定したプレースホルダ値の場合に、理由列がNULLまたは空文字の行を検出します。

    schema.yml での使い方:

        columns:
          - name: region_code
            data_tests:
              - common_transforms.placeholder_requires_reason:
                  arguments:
                    placeholder: '99'
                    reason_column: region_unknown_reason

    model と column_name はdbtが自動的に渡します。placeholderとreason_columnは
    必須です。対象列自体のNULLや参照整合性は、not_nullやrelationshipsで別に
    検証してください。

    Jinja展開後の違反条件例:
      region_code = '99'
      and nullif(trim(cast(region_unknown_reason as varchar)), '') is null
#}

{% test placeholder_requires_reason(model, column_name, placeholder, reason_column) %}

{#
    placeholder はSQLの文字列としてクォートして比較するため、文字列だけを受け付けます。
    region_codeが数値型でも、YAMLでは placeholder: '99' のように文字列で指定します。
    型が違う値を暗黙変換に任せず、下の比較時に対象列側を文字列へそろえます。
#}
{%- if placeholder is not string -%}
    {{ exceptions.raise_compiler_error(
        "placeholder_requires_reason: placeholder must be a string"
    ) }}
{%- endif -%}

{#
    reason_column は値ではなく列名としてSQLへ直接展開します。未指定やリストなどの
    誤った引数をここで止めます。実在する列かどうかは、dbt build時にウェアハウスが
    検証します。
#}
{%- if reason_column is not string -%}
    {{ exceptions.raise_compiler_error(
        "placeholder_requires_reason: reason_column must be a column name"
    ) }}
{%- endif -%}

{#
    SQLの文字列中ではシングルクォートを2つ重ねて表します。例えば O'Brien は
    'O''Brien' として生成し、クォートを含む固定値でもSQLが壊れないようにします。
#}
{%- set escaped_placeholder = placeholder | replace("'", "''") -%}

{#
    dbtのdata testは「問題のある行」を返します。対象列を文字列へcastすることで、
    文字列コードと数値コードを同じ比較方法で扱います。対象列がNULLの行はこの比較に
    一致せず通過するため、必要ならnot_nullを別に設定します。

    理由列はcastしてからtrimし、nullif(..., '') で空文字と空白だけの値をNULLへ
    そろえます。結果がNULLなら、プレースホルダを使った理由がない違反行です。
#}
select *
from {{ model }}
where cast({{ column_name }} as {{ dbt.type_string() }}) = '{{ escaped_placeholder }}'
  and nullif(trim(cast({{ reason_column }} as {{ dbt.type_string() }})), '') is null

{% endtest %}
