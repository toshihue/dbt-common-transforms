{#
    not_null_or_placeholder: 共通テスト部品

    Once you NULL-fill with a placeholder, `not_null` can no longer detect
    missing data — the placeholder satisfies it. This test fails on rows that
    are either NULL or still carry the placeholder, so you keep visibility.

    Usage in schema.yml:

        columns:
          - name: region_code
            data_tests:
              - common_transforms.not_null_or_placeholder
              - common_transforms.not_null_or_placeholder:
                  placeholder: '未設定'
#}

{% test not_null_or_placeholder(model, column_name, placeholder=none) %}

{%- set placeholder = placeholder if placeholder is not none
                      else var('unknown_string', 'UNKNOWN') -%}

select *
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} = '{{ placeholder }}'

{% endtest %}
