{#
    non_negative: 負数を検出する汎用テスト（自作テストの入門例）

    金額・数量・件数など「負になってはいけない列」を検証します。
    汎用テスト（generic test）を自作する例として最も分かりやすいため、
    ワークショップの教材として置いています。

    最重要の考え方:
    汎用テストには「問題のあるレコードを返す SQL」を書きます。

        0件返る    → テスト成功
        1件以上返る → テスト失敗

    条件を書くのではなく「違反行を抽出するクエリ」を書く、という点が
    直感と逆になりがちです。ここを押さえると、あとは普通の SQL です。

    schema.yml での使い方:

        version: 2

        models:
          - name: orders
            columns:
              - name: order_amount
                data_tests:
                  - common_transforms.non_negative

    model と column_name は dbt が自動的に渡します。1つのテストを、複数
    モデル・複数カラムから YAML だけで再利用できます。

    NULL の扱い（重要）:
    NULL はこのテストを通過します。SQL では `NULL < 0` の評価結果が NULL に
    なり、where 句が真にならないためです。NULL も検出したい場合は not_null を
    併記してください。テストは重ねて掛けるものです。

        data_tests:
          - not_null
          - common_transforms.non_negative

    where 条件を足したい場合は、テスト側を改造せず config で絞れます:

        - common_transforms.non_negative:
            config:
              where: "is_deleted = false"

    練習問題として、引数を追加してみてください。例えば allow_zero=false を
    受け取り、0 も失敗と判定する形にすると、引数付きテストの書き方が
    身につきます（fill_null や change_case が引数付きの実装例です）。

    参考: 同じことは dbt_utils でも書けます。

        - dbt_utils.accepted_range:
            arguments:
              min_value: 0

    実運用では dbt_utils で足りる場面が多いですが、「標準や dbt_utils で
    足りない要件が出たときに自分で部品化できる」ことを学ぶのが目的です。
#}

{% test non_negative(model, column_name) %}

    select *
    from {{ model }}
    where {{ column_name }} < 0

{% endtest %}
