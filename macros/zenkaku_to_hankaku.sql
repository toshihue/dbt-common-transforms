{#
    zenkaku_to_hankaku: 全角英数字 → 半角英数字

    Converts full-width digits and Latin letters to their half-width
    equivalents using translate(), which is a plain character-by-character
    map — no regex, and cheap.

    Usage:
        select {{ common_transforms.zenkaku_to_hankaku('postal_code') }} as postal_code

    Note: this deliberately does NOT touch 全角カナ. Half-width kana is not a
    normalization most Japanese datasets want, so that stays out of scope.
    Compose with normalize_text() when you also need whitespace cleanup:

        {{ common_transforms.normalize_text(
             common_transforms.zenkaku_to_hankaku('postal_code')) }}
#}

{% macro zenkaku_to_hankaku(column) %}
    translate(
        {{ column }},
        '０１２３４５６７８９ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ－',
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-'
    )
{% endmacro %}
