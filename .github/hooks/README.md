# Hooks

Hooks are session-triggered automations for GitHub Copilot workflows.

Add your hooks here. Each hook should have an `apm.yml` metadata file and accompanying markdown documentation.

## Structure

```
hooks/
  my-hook/
    apm.yml              # Hook metadata
    my-hook.md          # Hook implementation and documentation
```

## Next Steps

- See [CONTRIBUTING.md](../CONTRIBUTING.md) for instructions on adding a new hook
- See [catalog.template.yml](../catalog.template.yml) for the schema
