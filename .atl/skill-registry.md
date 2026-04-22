# Project Skill Registry

**Generated**: 2026-04-21
**Source**: User-level skills only (no project-level agents.md found)

## Available Skills

### Core SDD Skills
- **sdd-init**: Initialize Spec-Driven Development context in any project. *Trigger*: When user wants to initialize SDD in a project, or says "sdd init", "iniciar sdd", "openspec init".
- **sdd-explore**: Explore and investigate ideas before committing to a change. *Trigger*: When the orchestrator launches you to think through a feature, investigate the codebase, or clarify requirements.
- **sdd-propose**: Create a change proposal with intent, scope, and approach. *Trigger*: When the orchestrator launches you to create or update a proposal for a change.
- **sdd-spec**: Write specifications with requirements and scenarios (delta specs for changes). *Trigger*: When the orchestrator launches you to write or update specs for a change.
- **sdd-design**: Create technical design document with architecture decisions and approach. *Trigger*: When the orchestrator launches you to write or update the technical design for a change.
- **sdd-tasks**: Break down a change into an implementation task checklist. *Trigger*: When the orchestrator launches you to create or update the task breakdown for a change.
- **sdd-apply**: Implement tasks from the change, writing actual code following the specs and design. *Trigger*: When the orchestrator launches you to implement one or more tasks from a change.
- **sdd-verify**: Validate that implementation matches specs, design, and tasks. *Trigger*: When the orchestrator launches you to verify a completed (or partially completed) change.
- **sdd-archive**: Sync delta specs to main specs and archive a completed change. *Trigger*: When the orchestrator launches you to archive a change after implementation and verification.
- **sdd-onboard**: Guided end-to-end walkthrough of the SDD workflow using the real codebase. *Trigger*: When the orchestrator launches you to onboard a user through the full SDD cycle.

### Development Skills
- **branch-pr**: PR creation workflow for Agent Teams Lite following the issue-first enforcement system. *Trigger*: When creating a pull request, opening a PR, or preparing changes for review.
- **caveman**: Ultra-compressed communication mode. Cuts token usage ~75% by speaking like caveman while keeping full technical accuracy. Supports intensity levels: lite, full (default), ultra, wenyan-lite, wenyan-full, wenyan-ultra. *Trigger*: Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens", "be brief", or invokes /caveman. Also auto-triggers when token efficiency is requested.
- **go-testing**: Go testing patterns for Gentleman.Dots, including Bubbletea TUI testing. *Trigger*: When writing Go tests, using teatest, or adding test coverage.
- **issue-creation**: Issue creation workflow for Agent Teams Lite following the issue-first enforcement system. *Trigger*: When creating a GitHub issue, reporting a bug, or requesting a feature.
- **judgment-day**: Parallel adversarial review protocol that launches two independent blind judge sub-agents simultaneously to review the same target, synthesizes their findings, applies fixes, and re-judges until both pass or escalates after 2 iterations. *Trigger*: When user says "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen".
- **skill-creator**: Creates new AI agent skills following the Agent Skills spec. *Trigger*: When user asks to create a new skill, add agent instructions, or document patterns for AI.

### Utility Skills
- **find-skills**: Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. *Trigger*: This skill should be used when the user is looking for functionality that might exist as an installable skill.
- **skill-registry**: Create or update the skill registry for the current project. Scans user skills and project conventions, writes .atl/skill-registry.md, and saves to engram if available. *Trigger*: When user says "update skills", "skill registry", "actualizar skills", "update registry", or after installing/removing skills.

## Project Conventions

### Code Quality
- **Linting**: ESLint configured for frontend (TypeScript)
- **Type Checking**: TypeScript compiler for frontend
- **Formatting**: Not configured (consider Prettier)
- **Testing**: Not configured (consider Jest/Vitest + Playwright for E2E)

### Architecture Patterns
- **Frontend**: Next.js 16 with App Router, React 19, TypeScript
- **Backend**: AWS SAM with Lambda functions, API Gateway
- **Infrastructure**: Terraform for networking, SAM for application resources
- **State Management**: S3 backend with DynamoDB locking
- **Authentication**: AWS Cognito with Amplify
- **Storage**: DynamoDB for data, S3 for files

### Deployment
- **CI/CD**: GitHub Actions with OIDC authentication
- **Frontend**: Docker container on ECS Fargate
- **Backend**: SAM deployment with CloudFormation
- **Branch Strategy**: main=dev, prod=production

## Trigger Patterns

### Automatic Triggers
| Pattern | Skill | Reason |
|---------|-------|--------|
| "caveman mode", "talk like caveman", "use caveman", "less tokens", "be brief" | caveman | User requests compressed communication |
| Creating pull request, opening PR, preparing changes for review | branch-pr | PR workflow enforcement |
| Creating GitHub issue, reporting bug, requesting feature | issue-creation | Issue-first workflow |
| "judgment day", "review adversarial", "dual review" | judgment-day | Adversarial review request |
| Writing Go tests, using teatest, adding test coverage | go-testing | Go testing context |

### Manual Triggers
| Command | Skill | Context |
|---------|-------|---------|
| /sdd-init | sdd-init | Initialize SDD context |
| /sdd-explore <topic> | sdd-explore | Investigate ideas |
| /sdd-new <change> | sdd-propose | Start new change |
| /sdd-continue | Various SDD skills | Continue change workflow |
| /caveman lite/ultra | caveman | Switch intensity level |

## Compact Rules

### SDD Workflow Rules
- Follow RFC 2119 keywords (MUST, SHALL, SHOULD, MAY) in specifications
- Include rollback plan for risky changes in proposals
- Use Given/When/Then format for spec scenarios
- Group tasks by phase (infrastructure, implementation, testing)
- Use hierarchical numbering (1.1, 1.2, etc.) for tasks
- Load relevant coding skills for project stack during implementation
- Compare implementation against every spec scenario during verification

### Development Rules
- Every PR MUST link an approved issue (issue-first enforcement)
- Every PR MUST have exactly one `type:*` label
- Branch names MUST match: `^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)\/[a-z0-9._-]+$`
- Use conventional commits for all changes
- Run shellcheck on modified scripts before PR

### Communication Rules
- Drop articles, filler words, pleasantries, and hedging in caveman mode
- Use fragments and short synonyms while keeping technical accuracy
- Pattern: `[thing] [action] [reason]. [next step].`