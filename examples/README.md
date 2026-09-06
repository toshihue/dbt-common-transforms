# Examples

A complete, runnable demonstration: a seed of deliberately messy source data,
and one model that applies every component in the package. For reading and
copying — this directory is not itself a runnable dbt project.

| File | What it shows |
|---|---|
| `packages.yml` | Installing this package plus `dbt_utils`, pinned to a tag |
| `seeds/raw_members.csv` | Messy source data — 全角スペース, mixed-case values, NULLs |
| `seeds/schema.yml` | `column_types`, which is **not** optional here |
| `models/members_cleaned.sql` | All components in one model, plus a code-master join |
| `models/schema.yml` | Tests, including the package's own generic test |

## Try it

```sh
cp examples/packages.yml .
cp examples/seeds/*   seeds/
cp examples/models/*  models/
```

Add the required `constants` var to your `dbt_project.yml`:

```yaml
vars:
  constants:
    system_code: 'KIRIN01'
    record_type: '1'
    created_by: 'BATCH'
```

Then:

```sh
dbt deps
dbt seed
dbt compile --select members_cleaned
```

Open `target/compiled/<project>/models/members_cleaned.sql`. That file is the
lesson: every macro call has been replaced by the SQL it generates. A macro is a
SQL generator, not a function the warehouse executes.

```sh
dbt build --select members_cleaned
```

## Verified output

The compiled SQL was executed against Snowflake. Raw → cleaned:

| id | member_name | email | member_code | postal_code | region | orders | last_login |
|---|---|---|---|---|---|---|---|
| 1 | `　山田　　太郎 ` → `山田 太郎` | `Yamada.TARO@Example.COM` → `yamada.taro@example.com` | `ab-001` → `AB-001` | `" 100-0001 "` → `100-0001` | 02 → 関東 | 3 | 2026-08-01 |
| 2 | `  佐藤 花子  ` → `佐藤 花子` | → `sato.hanako@example.co.jp` | → `CD-002` | 530-0001 | 04 → 近畿 | **NULL → 0** | 2026-07-15 |
| 3 | `  tanaka　ichiro ` → `Tanaka Ichiro` | → `tanaka@example.com` | → `EF-003` | → `810-0001` | **NULL → 99 → 不明** | 7 | **NULL → 1900-01-01** |
| 4 | `"   "` → **NULL** | → `suzuki@example.com` | → `GH-004` | 060-0001 | 01 → 北海道・東北 | **NULL → 0** | **NULL → 1900-01-01** |
| 5 | `高橋　次郎` → `高橋 次郎` | → `takahashi@example.com` | → `IJ-005` | → `460-0001` | 03 → 中部 | 12 | 2026-09-01 |

## Three things worth pausing on

**Order of composition.** Row 3, `  tanaka　ichiro `, needs `normalize_text`
*before* `change_case(case='initcap')`. Collapse the 全角スペース first and
initcap sees two words and capitalizes each once. Reverse the order and you get
a different answer. Components compose, but not commutatively.

**`column_types` is mandatory.** Under type inference `region_code: '02'` loads
as the number `2` and silently stops joining to `region_master`, whose codes are
`'01'`..`'99'`. `postal_code` loses its leading zero the same way. Codes are text
that happens to look numeric — always declare them.

**Fill with a value that stays valid downstream.** `region_code` fills with
`'99'`, a real `region_master` code meaning 不明, so unknown regions still
resolve through the join. Filling with `'UNKNOWN'` would make those rows
disappear from every report that joins the master. The `relationships` test in
`models/schema.yml` is what catches that mistake.

## Honest tradeoff

Before:

```sql
coalesce(order_count, 0) as order_count
```

After:

```sql
{{ common_transforms.fill_null('order_count', kind='number', default_value=0) }} as order_count
```

The second is longer. Worth saying out loud in a workshop: for a single call
site a macro costs you clarity. It pays off at the tenth call site, and at the
moment the rule has to change everywhere at once. Componentize rules that
**repeat**, not rules that are merely complicated.
