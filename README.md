# common_transforms

A small dbt package of reusable transformation components — and a worked example
of **how to build a package of your own**.

Everything here is validated against Snowflake.

## What's in it

| Component | Type | 用途 |
|---|---|---|
| `constant(key)` / `standard_constants()` | macro | 固定値セット — assign literals unconditionally |
| `normalize_text(column)` | macro | 文字列加工 — trim + collapse whitespace incl. 全角スペース |
| `zenkaku_to_hankaku(column)` | macro | 文字列加工 — 全角英数字 → 半角 |
| `fill_null(column, kind)` | macro | NULL埋め — typed defaults from vars |
| `audit_columns()` | macro | standard audit columns |
| `region_master.csv` | seed | 固定値の集合 — code master as version-controlled data |
| `not_null_or_placeholder` | generic test | catch data that is NULL *or* still a placeholder |

Note that 固定値セット and NULL埋め are deliberately separate. `constant()` assigns
a literal **always**; `fill_null()` only substitutes **when the input is NULL**.
Conflating the two is a common source of quiet data bugs.

---

# Part 1 — Using this package

Add it to `packages.yml` in your dbt project:

```yaml
packages:
  - git: "https://github.com/toshihue/dbt-common-transforms.git"
    revision: v0.1.0        # always pin to a tag
```

Install:

```sh
dbt deps
```

Call the macros in a model. Prefix with the package name to make the
dependency obvious at the call site:

```sql
-- models/customers_cleaned.sql
select
    customer_id,
    {{ common_transforms.normalize_text('customer_name') }}      as customer_name,
    {{ common_transforms.zenkaku_to_hankaku('postal_code') }}    as postal_code,
    {{ common_transforms.fill_null('region_code') }}             as region_code,
    {{ common_transforms.fill_null('order_count', kind='number') }} as order_count,
    {{ common_transforms.standard_constants() }},
    {{ common_transforms.audit_columns() }}
from {{ ref('stg_customers') }}
```

Override the defaults from your own `dbt_project.yml`:

```yaml
vars:
  unknown_string: '未設定'
  constants:
    system_code: 'KIRIN01'
    created_by: 'BATCH'
```

**Then look at the generated SQL** — this is the single most useful moment:

```sh
dbt compile --select customers_cleaned
# open target/compiled/<your_project>/models/customers_cleaned.sql
```

A macro is a SQL *generator*, not a function the warehouse calls. Seeing the
expanded SQL is what makes that click.

You can also execute a macro standalone, without a model:

```sh
dbt run-operation my_macro --args '{some_key: some_value}'
```

---

# Part 2 — Building a package of your own

A dbt package is just a git repository containing a dbt project. There is no
registry to publish to and no build step. Minimum viable package:

```
my-package/
├── dbt_project.yml
└── macros/
    └── my_macro.sql
```

## 1. `dbt_project.yml`

```yaml
name: 'my_package'          # this is the calling prefix: {{ my_package.my_macro() }}
version: '0.1.0'
config-version: 2

require-dbt-version: ">=1.10.0,<3.0.0"

macro-paths: ["macros"]
seed-paths: ["seeds"]
test-paths: ["tests"]
```

**`require-dbt-version` is not optional if consumers run the dbt Fusion engine.**
Fusion only installs packages whose range contains `2.0.0`. A package with no
`require-dbt-version` is rejected at `dbt deps`. This is the single most common
reason a hand-rolled package fails on Fusion.

A package's `dbt_project.yml` needs no `profile:` — it never connects to a
warehouse itself. It runs inside the consumer's project, using the consumer's
connection.

## 2. Write macros

```sql
{% macro my_macro(column) %}
    /* SQL that gets pasted in place of the call */
{% endmacro %}
```

Guidelines that hold up over time:

- **One macro per file**, filename matching the macro name. Easy to find.
- **Document in a `{# ... #}` block** with a usage example. This is the only
  documentation most callers will read.
- **Fail loudly** on bad input — `exceptions.raise_compiler_error()` at compile
  time beats wrong data at runtime. See `fill_null` and `constant`.
- **Defaults via `var('name', fallback)`**, so the package works whether or not
  the consumer configures anything.
- **Watch string escaping.** `normalize_text` needs a doubled backslash because
  Snowflake treats `\x` as a string escape. Always verify against the real
  warehouse — the macro looks fine right up until the SQL reaches the database.

## 3. Version with git tags

```sh
git tag -a v0.1.0 -m "First release"
git push origin v0.1.0
```

Consumers pin `revision: v0.1.0`. Pinning to a tag rather than a branch is what
stops your package from silently changing under someone else's project. Bump the
tag on every change; never move an existing tag.

## 4. Public vs private

Public repos install over HTTPS with no credentials — simplest by far. Private
repos need a deploy key or token configured in the consuming environment, which
is worth doing for real company packages but adds setup you don't want mid-workshop.

## 5. Before you share it

- `dbt deps && dbt compile` in a scratch consumer project
- Inspect the compiled SQL, not just the exit code
- Run the actual SQL against the warehouse — a macro can compile cleanly and
  still produce invalid SQL

---

## Note for the dbt platform IDE

You cannot author a package from the dbt platform IDE — the IDE is bound to its
project's single repository, so you can't create or edit a second repo there.
For a workshop with no local dbt install, the practical loop is:

1. **Author** the package in the GitHub web UI — create the repo, add files, tag a release
2. **Consume** it from the dbt platform IDE — add `packages.yml`, run `dbt deps`, call the macros

Browser only, and it still exercises the entire create → publish → consume cycle.

## Compatibility

- Validated on **Snowflake**
- `require-dbt-version: ">=1.10.0,<3.0.0"` — installs on dbt Core 1.10+ and the
  Fusion engine
- Uses `regexp_replace` and `translate`, which exist on most warehouses, but
  whitespace-class and escaping behaviour differs by platform. Re-validate
  before using on anything other than Snowflake.
