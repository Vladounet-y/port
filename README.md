# Expense Review

Application boot files, server configuration, demo seeds, and CI tooling are intentionally omitted. This repository is a feature slice, not a standalone runnable Rails application. The Gemfile records the feature and spec dependencies.

## Review guide

1. [ExpensesController](app/controllers/expenses_controller.rb) — strong parameters, action-specific error handling, and HTTP responses.
2. [Review](app/services/expenses/review.rb) — authorization, state transition, and an atomic audit transaction.
3. [ExpensePolicy](app/policies/expense_policy.rb) — record visibility and review permissions.
4. [ReviewQueue](app/queries/expenses/review_queue.rb) — filtering, eager loading, stable ordering, and frontend limits.
5. [Submit](app/services/expenses/submit.rb) — exact decimal conversion and submission.
6. [ExpenseSerializer](app/serializers/expense_serializer.rb) — an explicit hash of public response fields.

[ApplicationController](app/controllers/application_controller.rb) authenticates through [Warden](config/initializers/warden.rb). [Routes](config/routes.rb) describe the HTTP interface.

Each table has its own migration: [users](db/migrate/20261013000001_create_users.rb), [expenses](db/migrate/20261013000002_create_expenses.rb), and [expense decisions](db/migrate/20261013000003_create_expense_decisions.rb). They retain foreign keys and unique indexes. Models validate allowed states, currencies, monetary ranges, and rejection reasons.

## Feature contract

| Endpoint | Purpose |
| --- | --- |
| GET /expenses?status=pending&limit=20 | List requests visible to the authenticated user |
| POST /expenses | Submit a pending request |
| POST /expenses/:id/review | Approve or reject a request |

Submission body:

```json
{"expense":{"description":"Client meeting travel","amount":"42.50","currency":"EUR"}}
```

Review body:

```json
{"review":{"outcome":"rejected","reason":"Receipt is missing"}}
```

Employees see their own requests. Managers see all requests and cannot review their own. Requests start pending and receive one final decision. Rejection requires a reason.

## Specs

[Feature specs](spec/expense_review_spec.rb) cover submission, review, authorization, rollback, concurrency, audit protection, and queries. [Request specs](spec/requests/expenses_spec.rb) cover authentication, scoping, strong parameters, serialization, and HTTP behavior. [Serializer specs](spec/serializers/expense_serializer_spec.rb) check public fields and exclusion of private user data.

RSpec uses transactional fixtures and FactoryBot [factories](spec/factories). Traits provide managers and reviewed expenses with matching audit records. Factories supply existing entities; RSpec subjects exercise services. Input collections live in named let declarations.

The specs document the testing approach. Executing them requires a host Rails application's boot files, database configuration, and test environment; those are outside this review-only sample.
