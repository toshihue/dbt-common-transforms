{#
    change_case: 大文字・小文字変換の共通部品

    テキスト列の大文字・小文字を正規化します。3つのマクロに分けず引数で
    切り替える設計にしているのは、覚える部品を1つに、変更箇所を1箇所に
    するためです。

    使い方:
        {{ common_transforms.change_case('email') }}                     -- upper（既定）
        {{ common_transforms.change_case('email', case='lower') }}
        {{ common_transforms.change_case('first_name', case='initcap') }}

    case: 'upper'（既定） | 'lower' | 'initcap'

    どれを使うかは列の性質で決まります:
      - 'lower'   メールアドレス、および結合キーに使う値
      - 'upper'   コード類、識別子
      - 'initcap' 人名・地名（'JIMMY c.' -> 'Jimmy C.'）

    他の文字列部品と組み合わせて使えます:
        {{ common_transforms.change_case(
             common_transforms.normalize_text('first_name'), case='initcap') }}
#}

{% macro change_case(column, case='upper') %}

    {%- if case not in ['upper', 'lower', 'initcap'] -%}
        {{ exceptions.raise_compiler_error(
            "change_case: case must be 'upper', 'lower' or 'initcap', got '" ~ case ~ "'"
        ) }}
    {%- endif -%}

    {#
        検証済みの case を SQL 関数名として展開し、同じ処理で upper / lower /
        initcap を切り替えます。関数名を文字列のSQLリテラル（固定値）として渡すのではなく、
        {{ case }}({{ column }}) の形にすることで、ウェアハウスのネイティブ関数呼び出しを
        生成します。

        Jinja 展開後の例:
          {{ common_transforms.change_case('email', case='lower') }}
          -> lower(email)
    #}
    {{ case }}({{ column }})

{% endmacro %}
