# Spring Boot 2 to 3 Upgrade Skill

An AI agent skill that automates Spring Boot 2.7.x → 3.x migration using OpenRewrite recipes, including baseline checks, recipe migration, manual compatibility fixes, and upgrade reports.

## What the skill does

- **Automated migration**: OpenRewrite recipes handle Boot 2.7 → 3, Java upgrade, javax→jakarta, dependency and configuration property changes.
- **Target versions**: Migrate to **Spring Boot 3.5.x** and **Java 21** (or 17); API docs move from Springfox to **springdoc-openapi 2.8.x** (do not use 3.0.0 with Boot 3.5).
- **Safe and reversible**: The **current branch** stays unchanged as the rollback anchor; the agent creates only a **working branch** for the migration (no separate backup branch).
- **Validation and output**: Compile, test, and audit script before/after; generate an upgrade report under `docs/`.
- **On failure**: The agent will **rollback** to a safe state (e.g. original branch or last good commit) and write a **failure report** in `docs/` (e.g. `docs/<yyyymmdd>-upgrade-failure.md`) with the failing stage, error summary, and suggested next actions. The repo is not left broken without a report.

## Migration scenarios

The skill and OpenRewrite recipes handle these typical 2.7 → 3 migration areas:

| Area | What changes |
|------|----------------|
| **javax → jakarta** | `javax.persistence.*`, `javax.servlet.*`, `javax.validation.*` → `jakarta.*` (packages and dependencies). |
| **Spring Security** | `WebSecurityConfigurerAdapter` → `SecurityFilterChain` bean(s) and related config. |
| **Spring MVC / Web** | `@RequestMapping(method=)`, `@PathVariable("id")`, `HttpStatus`, `APPLICATION_JSON_UTF8_VALUE` → Boot 3–compatible usage; `WebMvcConfigurerAdapter` / `HandlerInterceptorAdapter` → interface-based config. |
| **Validation** | `javax.validation` → `jakarta.validation`; ensure `@Valid` / `@RequestBody` and binding work as expected after migration. |
| **Async** | `AsyncConfigurerSupport` → equivalent config without the deprecated base class. |
| **Tests** | JUnit 4 (`@RunWith`, `@Before`, `public @Test`) → JUnit 5; Boot 3 test dependencies and `@SpringBootTest` / `@WebMvcTest`. |
| **Config properties** | Legacy names (e.g. `spring.datasource.initialization-mode`, `management.context-path`) → current property names. |
| **API docs** | Springfox → **springdoc-openapi 2.8.x** (do not use 3.0.0 with Boot 3.5). |
| **Build & runtime** | Java 11 → 17 or 21 in `pom.xml`/Gradle and in Docker/CI base images. |

## Directory layout

```
spring-boot-2-to-3/
├── README.md           # This file
├── SKILL.md            # Skill body: workflow, rules, output contract
├── references/
│   ├── openrewrite-recipes.md   # Maven/Gradle recipes and commands
│   └── manual-fix-checklist.md  # Post-rewrite manual fix checklist
├── scripts/
│   └── check.sh                # Pre/post check (Boot version, javax, Springfox)
└── agents/             # Optional agent configs
```

## When to use it

Use this skill when:

- The project is **already on Spring Boot 2.7.x** and you want to upgrade to 3.x
- You need to migrate `pom.xml` / `build.gradle`, javax→jakarta, Spring Security or Spring MVC config, dependencies, or the Dockerfile Java base image for Boot 3

**Do not use** for projects on Boot 2.6 or earlier—upgrade to 2.7.x first, then run this skill.

## How to use it

1. **Make the skill available** to your AI assistant in whatever way your platform supports (e.g. open this repo, add this directory to the project, or load it as a skill). The assistant needs access to [SKILL.md](SKILL.md) and, when running the workflow, to the files under `references/` and `scripts/`.

2. **Invoke the workflow**: Ask the assistant to upgrade your project to Spring Boot 3 using the spring-boot-2-to-3 skill (e.g. "Use the spring-boot-2-to-3 skill to upgrade this project to Spring Boot 3" or "Upgrade `./my-app` to Spring Boot 3 with the spring-boot-2-to-3 skill"). The agent will follow the workflow in [SKILL.md](SKILL.md): baseline verification, create working branch, run OpenRewrite, apply manual fixes, validate, and write the report under `docs/`. All git operations (branch, commit) are performed by the agent.

3. **Scope**: The agent runs in the target project directory: baseline checks, `check.sh`, OpenRewrite, manual fixes, tests, and report generation.

**Try the skill:** You can test this skill against the [spring-boot-2-to-3-demo](https://github.com/chensoul/spring-boot-2-to-3-demo) repository—a Maven sample on Spring Boot 2.7.18 that covers the main migration scenarios (javax→jakarta, Spring Security, Spring MVC, JUnit 4, legacy config, springdoc, etc.). Clone the demo, point the agent at it, and run the upgrade workflow.

## Prerequisites

- **Spring Boot 2.7.x**: The project must be on 2.7.x. This skill does not support 2.6 or earlier; upgrade to 2.7.x first or the migration may fail.
- **JDK 17+** is required to run OpenRewrite; if the target is Java 21, the host and CI/image must support Java 21.
- The check script `scripts/check.sh` uses only common shell tools (grep, find, sed, awk); no extra dependencies.

## References

- **Skill body and workflow**: [SKILL.md](SKILL.md)
- **OpenRewrite recipes and commands**: [references/openrewrite-recipes.md](references/openrewrite-recipes.md)
- **Manual fix checklist**: [references/manual-fix-checklist.md](references/manual-fix-checklist.md)
