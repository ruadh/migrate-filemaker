# migrate-filemaker

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that guides full migrations from FileMaker Pro to modern open-source stacks.

Give it a FileMaker Database Design Report (DDR) XML export and it will parse every component, walk you through requirements discovery, recommend a tech stack, and produce a complete migration plan with SQL schema, API design, and UI spec.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- **Python 3.6+** &mdash; used by the DDR XML parser (`scripts/parse_ddr.py`)

## Installation

Copy or symlink into your Claude Code skills directory:

```bash
# Personal skills (available in all projects)
cp -r migrate-filemaker ~/.claude/skills/migrate-filemaker

# Or project-local skills
cp -r migrate-filemaker .claude/skills/migrate-filemaker
```

## Usage

From Claude Code, provide a path to your DDR export:

```
/migrate-filemaker /path/to/ddr-export/
```

The input can be:
- A single `FMPReport type="Report"` XML file
- A directory containing one or more Report XMLs (multi-file DDR)

Multi-file solutions (e.g. UI file + data file) are auto-detected. All files are parsed and merged into unified specs.

## What it does

The skill runs in four phases, each producing checkpoint files so work can resume across sessions:

### Phase 1: Parse & Understand

Runs `parse_ddr.py` on the DDR XML and extracts 9 JSON spec files:

| File | Contents |
|------|----------|
| `00_topology.json` | File inventory, cross-file references |
| `01_tables.json` | Tables with fields, calculated fields, summaries, globals |
| `02_table_occurrences.json` | Table occurrences (graph nodes) |
| `03_relationships.json` | Relationships with join predicates |
| `04_layouts.json` | Layouts with fields, portals, buttons |
| `05_scripts.json` | Scripts with parsed steps and parameters |
| `06_value_lists.json` | Value lists (custom and field-based) |
| `07_security.json` | Accounts and privilege sets |
| `08_custom_functions.json` | Custom functions with calculations |

Then analyzes the specs and produces an application summary with complexity scoring, data model overview, feature map, and red flags.

### Phase 2: Discovery

Interactive requirements gathering &mdash; asks about goals, users, UI preferences, technical constraints, and integrations. Adapts questions based on earlier answers.

### Phase 3: Recommend

Recommends a tech stack (database, backend, frontend, auth, deployment), architecture pattern, migration strategy, and feature priority order.

### Phase 4: Plan

Generates the full migration plan:

| Output | Description |
|--------|-------------|
| `03_migration_plan.md` | Phased plan with effort estimates and risk register |
| `04_database_schema.sql` | Production-ready SQL DDL |
| `05_api_design.md` | RESTful API endpoints grouped by domain |
| `06_ui_spec.md` | Frontend spec with page inventory, component mapping, form specs |

## Project structure

```
migrate-filemaker/
  SKILL.md                  # Skill definition (instructions for Claude)
  scripts/
    parse_ddr.py            # DDR XML parser (Python)
  reference/
    ddr-xml-reference.md    # DDR XML structure documentation
    filemaker-concepts.md   # FileMaker-to-modern concept mapping
    schema-translation-guide.md
    script-translation-patterns.md
    tech-stack-decision-matrix.md
  templates/
    00_app_summary.md       # Output templates for each phase
    01_discovery_answers.md
    02_recommendations.md
    03_migration_plan.md
    04_database_schema.sql
    05_api_design.md
    06_ui_spec.md
```

## DDR parser standalone usage

The parser can also be run directly outside of Claude Code:

```bash
# Parse a single file
python3 scripts/parse_ddr.py /path/to/report.xml

# Parse a directory of DDR XMLs
python3 scripts/parse_ddr.py /path/to/ddr-export/

# Specify output directory
python3 scripts/parse_ddr.py /path/to/ddr-export/ /path/to/output/
```

If no output directory is given, specs are written to a `specs/` folder next to the input.

## License

MIT
