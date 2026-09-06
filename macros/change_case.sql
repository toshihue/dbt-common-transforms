{#
    change_case: 大文字・小文字変換の共通部品

    Normalizes the case of a text column. Parameterized rather than three
    separate macros, so there is one component to learn and one place to change.

    Usage:
        {{ common_transforms.change_case('email') }}                     -- upper (default)
        {{ common_transforms.change_case('email', case='lower') }}
        {{ common_transforms.change_case('first_name', case='initcap') }}

    case: 'upper' (default) | 'lower' | 'initcap'

    Which one you want depends on the column:
      - 'lower'   for email addresses and anything used as a join key
      - 'upper'   for codes and identifiers
      - 'initcap' for person and place names ('JIMMY c.' -> 'Jimmy C.')

    Composes with the other string components:
        {{ common_transforms.change_case(
             common_transforms.normalize_text('first_name'), case='initcap') }}
#}

{% macro change_case(column, case='upper') %}

    {%- if case not in ['upper', 'lower', 'initcap'] -%}
        {{ exceptions.raise_compiler_error(
            "change_case: case must be 'upper', 'lower' or 'initcap', got '" ~ case ~ "'"
        ) }}
    {%- endif -%}

    {{ case }}({{ column }})

{% endmacro %}
