{#
    normalize_text: 文字列加工の共通部品

    Trims leading/trailing whitespace, collapses any run of whitespace —
    including the full-width space U+3000 (全角スペース) — into a single
    half-width space, and turns the empty string into NULL.

    Usage:
        select {{ common_transforms.normalize_text('customer_name') }} as customer_name

    Why a macro: this rule has to be identical in every model. Written inline,
    one model eventually gets it slightly wrong and nobody notices.

    Two details worth pointing out in the workshop:

    1. `\s` alone does NOT match the full-width space on Snowflake.
       regexp_replace(col, '\\s+', ' ') leaves 「山田　太郎」 untouched — which
       is exactly the kind of bug that survives code review.
    2. The backslash is doubled on purpose. Snowflake processes \x as a string
       escape in the literal, so a single backslash fails with
       "Invalid hex escape sequence '\x'". Doubling it means the regex engine
       receives \x{3000}. Writing a literal 全角スペース inside the character
       class also works, but puts an invisible character in your source.
#}

{% macro normalize_text(column) %}
    nullif(trim(regexp_replace({{ column }}, '[[:space:]\\x{3000}]+', ' ')), '')
{% endmacro %}
