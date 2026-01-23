# Project Claude Configuration

This project uses global Claude Code configuration for agents, commands, skills, and rules.

## Configuration Location

**Global** (`~/.claude/`):
- `agents/` - Reusable agents (planner, architect, doc-updater, etc.)
- `commands/` - Slash commands (/plan, /code-review, /tdd, etc.)
- `skills/` - Project patterns and workflows
- `rules/` - Coding standards and guidelines

**Project** (`.claude/`):
- `settings.local.json` - Project-specific permissions and settings

## Why This Setup?

- **Reusability**: Agents and commands work across all ChildMetrix projects
- **Maintainability**: Update once in `~/.claude/`, applies everywhere
- **Cleaner Repo**: Project repo focuses on project-specific configuration

## Updating Configuration

Global configuration comes from [everything-claude-code](https://github.com/affaan-m/everything-claude-code):

```bash
cd ~/.claude
git pull  # Update global configuration
```

Project-specific settings stay in this folder.
