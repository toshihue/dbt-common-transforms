{#
    not_null_or_placeholder: 汎用テスト（generic test）の自作例

    位置づけ:
    これは「よく使われる標準的なテスト」ではありません。dbt 標準の
    not_null / unique / accepted_values / relationships と dbt_utils で
    足りない要件が出たときに、自分でテストを部品化する方法の例です。

    解決したい課題:
    プレースホルダで NULL埋め をすると、その時点で通常の not_null は
    役に立たなくなります。'UNKNOWN' は NULL ではないため必ず合格し、
    欠損データが見えなくなります。このテストは NULL とプレースホルダの
    両方を検出し、可視性を取り戻します。

    schema.yml での使い方:

        columns:
          - name: region_code
            data_tests:
              - common_transforms.not_null_or_placeholder
              - common_transforms.not_null_or_placeholder:
                  arguments:
                    placeholder: '未設定'

    model と column_name は dbt が自動的に渡します。指定できる引数は
    placeholder だけです。

    severity について:
    実務では severity: warn を推奨します。「不明」データの存在自体は多くの
    業務で想定内であり、ビルドを止めるべきものではありません。件数を毎回
    ログに出して推移を見るのが目的です。その列が本当に完全であるべきだと
    決めた時点で error に切り替えてください。

        - common_transforms.not_null_or_placeholder:
            config:
              severity: warn

    同じ目的の一般的な代替手段:
      - accepted_values で '99' を正規の値として列挙する
      - dbt_utils.not_null_proportion で欠損率に閾値を設ける
      - 不明件数を集計する監視用モデルを作り、指標として追う
#}

{% test not_null_or_placeholder(model, column_name, placeholder=none) %}

{%- set placeholder = placeholder if placeholder is not none
                      else var('unknown_string', 'UNKNOWN') -%}

select *
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} = '{{ placeholder }}'

{% endtest %}
