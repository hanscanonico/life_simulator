# Life Simulator

simulator-life.com — a research instrument for the spontaneous emergence of
self-replicators, and the public site around it. Read `docs/DESIGN.md` first: it is the
design of record (substrate, observables, sweeps, architecture, deployment). Locked
decisions change only through an entry in `docs/design_record.md`.

Layout: `engine/` is a Rust workspace (the simulation: lib, `runner` bin, wasm crate);
the Rails app is the site and the lab database; `deploy/` is the mini-pc compose stack.
Gate: `make verify` (Rails specs, RuboCop, Brakeman, cargo test/clippy/fmt, wasm build).
Rust toolchain: `export PATH="$HOME/.cargo/bin:$PATH"` (rustup via Homebrew).

### Model roles

Fable orchestrates and does not implement, research or review a PR itself. Workers are the
Opus agents in `.claude/agents/`, effort set by role: `scout` low, `implementer` medium (the
`improve` workflow retries once at high on a red gate or a reject), `reviewer` high, `qa` low.
`/improve` and `/orchestrate` carry the full loop.

# Rails Project Guide

## Commands
- Setup: `bin/setup`
- Run App: `bin/dev`
- Tests: `bundle exec rspec` (or `bin/rspec` — bare `rspec` can activate the wrong json gem and fail to boot)
- Single spec: `bundle exec rspec spec/path/to_spec.rb:42`
- Specs for changed files only: `bin/rspec-auto`
- Coverage: `COVERAGE=1 bundle exec rspec` (SimpleCov)
- Linting: `bundle exec rubocop -A`
- Security scan: `bundle exec brakeman`

## Standards & Conventions
- **Ruby Version**: 3.3+
- **Rails Version**: 8.0+
- **Database**: PostgreSQL
- **Views**: Hotwire (Turbo/Stimulus). Avoid custom JS unless necessary.
- **CSS**: Native CSS with utility-first design system (see CSS Architecture below)
- **Pagination**: Use `Pagy` - `@pagy, @records = pagy(scope)`

## Code Organization
- **Services** (`app/services/`): Business logic with `self.call` pattern, organized in domain namespaces (e.g. `Billing::`, `Reports::`)
- **Presenters** (`app/presenters/`): Read-side view models that assemble everything a single controller action's view needs (see Presenter Pattern below)
- **Models** (`app/models/`): ActiveRecord models and plain Ruby domain objects (value objects, config structs)
- **Concerns**: Model concerns in `app/models/concerns/`, service concerns in `app/services/concerns/`, job concerns in `app/jobs/concerns/`

### Service Pattern
The `Callable` concern (`app/services/concerns/callable.rb`) provides `self.call(...)` → `new(...).call`:

```ruby
class MyService
  include Callable

  def initialize(args)
    @args = args
  end

  def call
    # return result
  end
end
```

**Naming**: Every service class must end in `Service` (e.g. `Billing::SubscriptionHandlerService`). Enforced by the custom `Rails/ServiceClassSuffix` RuboCop cop. Concerns in `app/services/concerns/` are exempt. Plain Ruby domain objects (value objects, config structs) belong in `app/models/`, not `app/services/`.

### Presenter Pattern
Use a **presenter** (view model) when a controller action needs to assemble a lot of read-side data for its view — params + current user's abilities in, a single object the view reads from out. Presenters orchestrate services and queries but **perform no writes or side effects**; that distinction is what separates them from services.

- Location: `app/presenters/`, in domain namespaces (e.g. `app/presenters/orders/show_page.rb` → `Orders::ShowPage`)
- Entry point: `self.build(...)` returning a presenter instance the view reads via methods/attributes
- The controller assigns one ivar (`@show = Orders::ShowPage.build(...)`) and the view reads `@show.x` — avoid fanning many ivars out of the presenter
- Do **not** suffix with `Service` and do **not** place in `app/services/`; presenters are read-side view models, not business-logic services
- Authorization gating that only shapes what the view displays belongs in the presenter, fed by the passed-in `Ability`

```ruby
class Orders::ShowPage
  def self.build(params:, ability:)
    new(params: params, ability: ability)
  end

  def initialize(params:, ability:)
    @params = params
    @ability = ability
  end

  # expose computed/assembled values as methods the view reads
  def chart_data = @chart_data ||= Charts::DataBuilderService.call(...)
end
```

## Authentication & Authorization
When the app needs auth, use the standard stack:
- **Devise** for authentication (with confirmable)
- **CanCanCan** for authorization
- User roles: `user` (default), `admin`
- Admin controllers inherit from `Admin::BaseController`

## Background Jobs
- **SolidQueue** (database-backed; can run inside Puma in production via `SOLID_QUEUE_IN_PUMA`)
- Jobs in `app/jobs/`
- Route every job with `queue_as`; define named lanes in `config/queue.yml` when job classes have different urgency (e.g. `critical`, `notifications`, `default`) so slow bulk work can never delay time-sensitive work
- In development, jobs run inline via `:async` adapter — no separate process needed

## Testing Rules
- Use **RSpec** for all tests
- Use **FactoryBot** for test data (with **Faker** for values), **shoulda-matchers** for model specs
- New features need corresponding System Specs (`js: true` runs headless Chrome via `spec/support/capybara.rb`)
- Shared example groups live in `spec/support/shared_examples/` (auto-loaded)
- Any new Stimulus controller must ship with a `js: true` system spec covering its user-visible behavior
- Never use "when" in `it` descriptions — move the condition into a wrapping `context` block instead (enforced by the custom `RSpec/NoWhenInIt` cop)

## Hotwire Architecture

### Decision Hierarchy
Always prefer the simplest tool that solves the problem:

**HTML → CSS → Turbo Drive → Turbo Frames → Turbo Streams → Stimulus → Custom JS**

Never jump to a complex solution when a simpler one works.

### Turbo Drive
- Automatically converts link clicks and form submissions into AJAX requests — zero config needed
- Provides SPA-like speed for free; rely on it by default

### Turbo Frames
Use for **isolated, self-contained** page regions:
- Inline edit forms, comment forms, modal triggers
- Lazy loading sections: `<turbo-frame id="..." loading="lazy" src="...">`
- Each frame should map to its own resourceful controller action
- Frames degrade gracefully (full page load without JS)

```erb
<%# Lazy-loaded frame %>
<turbo-frame id="stats" loading="lazy" src="<%= stats_path %>">
  <p>Loading...</p>
</turbo-frame>
```

### Turbo Streams
Use when **multiple page regions** need simultaneous updates, or for **real-time** via ActionCable:

```ruby
# HTTP response (after form submit)
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to @record }
end
```

```erb
<%# app/views/records/create.turbo_stream.erb %>
<%= turbo_stream.append "records", @record %>
<%= turbo_stream.replace "flash", partial: "shared/flash" %>
```

**ActionCable broadcasts** (real-time, multi-user):
```ruby
# Model
after_create_commit -> { broadcast_append_to "feed" }

# Or with Turbo 8 morphing
broadcasts_refreshes
```

```erb
<%# View %>
<%= turbo_stream_from "feed" %>
```

### Turbo 8 Morphing (Rails 8+)
- `broadcasts_refreshes` on model triggers automatic morph on create/update/destroy
- Use `data-turbo-permanent` on elements that should not be re-rendered (dropdowns, open forms)
- After morphing, Stimulus controllers may lose state — reconnect with `data-action="turbo:morph@window->controller#connect"`
- Not ideal for search filters, query-param-driven pages, or infinite scroll — use Frames/Streams there

### Stimulus
Use Stimulus only for **client-side behavior** that doesn't need a server round-trip:
- Integrating third-party JS libraries (datepickers, charts, tooltips)
- Small DOM interactions: character counters, toggling classes, clipboard copy
- Wiring Turbo components together (triggering a frame refresh on a timer or input event)
- Use lifecycle callbacks (`connect`, `disconnect`, `targetConnected`) to initialize/teardown libs

**Stimulus controllers must stay small and focused** — one responsibility per controller.

```js
// Good: focused, reusable
export default class extends Controller {
  static targets = ["count"]
  update() { this.countTarget.textContent = this.inputTarget.value.length }
}
```

### Anti-Patterns to Avoid

| Anti-Pattern | Why Bad | Do Instead |
|---|---|---|
| **Turbo Stream soup** | Many streams in one response → race conditions, hard to maintain | Use a single `redirect_to` + morph refresh, or one Turbo Frame |
| **Stimulus for templating** | Building HTML strings in JS breaks server-rendering model | Use Turbo Frames with a real controller action |
| **innerHTML in Stimulus** | Bypasses Turbo's DOM management, causes bugs with reconnection | Use `textContent`, `classList`, or `insertAdjacentHTML` carefully |
| **Client-side validation only** | Server validation is always required anyway | Add a Turbo Frame round-trip for validation feedback |
| **Hall-monitor Stimulus controllers** | God controllers watching the whole page break reusability | Keep controllers scoped to their element |
| **Skipping Turbo Drive for SPA feel** | Turbo Drive already gives you that for free | Let it work; only opt-out with `data-turbo="false"` when needed |

### Combining Tools
Complex features often combine tools:
- **Search/filter**: form submits via Turbo Frame (`data-turbo-frame="results"`) — no Stimulus needed
- **Modals**: Turbo Frame as overlay + Stimulus to close on backdrop click
- **Live notifications**: ActionCable broadcast → `turbo_stream.append` to notification list
- **Inline edit**: Turbo Frame wrapping both display and form views

## Comments
Comments are a last resort, not a default. The codebase should read cleanly without them: prefer a better name, a smaller method, or an extracted object over a comment that explains a mess.

**Write a comment only when it carries information the code cannot:**
- A non-obvious constraint or invariant (`must exceed FULL_IMPORT_TIMEOUT or the semaphore expires mid-import`)
- A cross-file coupling the reader would otherwise miss (`keep in sync with --color-* in app-tokens.css`)
- A deliberate choice that looks like a bug (`population variance (÷N), not sample`)
- A domain fact with no home in the code (a formula's source, a provider quirk)

**Never write a comment that:**
- Restates the next line (`# Create new record` above `Model.create!`)
- Labels an obvious step (`# Progress indicator`, `# Default values`)
- Divides a file into sections (`# --- Parsed inputs ---`) — that's a signal the class does too much
- Talks to the reviewer or narrates history (`# Alias for backward compatibility`, `# standardized to use call`) — that belongs in the commit message or PR, not the file
- Documents a self-evident signature (`# Returns the number of snapshots written` above `def call` returning a count)

Class-level docs are welcome where they explain *why the object exists* and how it fits the system — not where they paraphrase the class name. Keep them to a few lines.

## Important Notes
- **Never silence RuboCop** with `# rubocop:disable` — an offense means the code needs changing, not the cop. Restructure until it passes cleanly. If a cop is genuinely wrong for this codebase, turn it off in `.rubocop.yml` with a rationale rather than scattering inline disables.
- **Strong Parameters** strictly enforced - never use `permit!`
- **Frozen string literals** in all files
- Prefer native Ruby over adding gems
- When making technical decisions, do not give much weight to development cost — prioritize the right long-term solution

## CSS Architecture

### File Structure (Load Order)
CSS files in `app/assets/stylesheets/` are numbered for explicit load order
(propshaft loads them alphabetically). The numbered core (`00`–`05`) is the
shared design system, **vendored from `~/Projets/rails_template`** — improve it
here, then port the change back to that repo (and vice versa). App-specific
styles are never vendored.

| File | Purpose |
|------|---------|
| `00-tokens-brand.css` | Brand layer: colors, font stacks, wordmark — swap this file to rebrand (alternate themes in `~/Projets/rails_template/themes/`) |
| `00-tokens-structural.css` | Structural layer: type scale, spacing, radii, shadows, motion, component tokens |
| `01-buttons.css` | Button styles |
| `02-forms.css` | Form elements (inputs, selects, buttons, labels) |
| `03-layout.css` | Layout utilities (containers, grid, flex, spacing) |
| `04-components.css` | Small reusable UI components (badges, alerts, spinners) |
| `05-typography.css` | Typography utilities (font sizes, weights, text transforms) |
| `application.css` | Body reset + app entry point |
| `*.css` | App-specific component styles and tokens (never edit domain styling into the numbered core) |

### Utility Classes

**Layout (`03-layout.css`)**
- Containers: `.container`, `.container-narrow`, `.container-wide`
- Grid: `.grid`, `.grid-2`, `.grid-3`, `.grid-4`, `.grid-auto`
- Flex: `.flex`, `.flex-center`, `.flex-between`, `.flex-wrap`, `.flex-col`, `.inline-flex`
- Gap: `.gap-1` through `.gap-8`
- Spacing: `.m-0`–`.m-8`, `.mt-*`, `.mb-*`, `.ml-*`, `.mr-*`, `.mx-*`, `.my-*` (same for padding with `.p-*`)
- Display: `.hidden`, `.block`, `.inline-block`, `.hidden-mobile`, `.hidden-desktop`
- Text alignment: `.text-left`, `.text-center`, `.text-right`

**Typography (`05-typography.css`)**
- Sizes: `.text-xs`, `.text-sm`, `.text-base`, `.text-lg`, `.text-xl`, `.text-2xl`, `.text-3xl`, `.text-4xl`
- Weights: `.font-normal`, `.font-medium`, `.font-semibold`, `.font-bold`
- Line heights: `.leading-tight`, `.leading-normal`, `.leading-relaxed`
- Transforms: `.uppercase`, `.lowercase`, `.capitalize`, `.normal-case`
- Spacing: `.tracking-tight`, `.tracking-normal`, `.tracking-wide`
- Truncation: `.truncate`, `.line-clamp-2`, `.line-clamp-3`
- Colors: `.text-primary`, `.text-secondary`, `.text-muted`, `.text-success`, `.text-error`, `.text-warning`

**Components (`04-components.css`)**
- Badges: `.badge`, `.badge-success`, `.badge-warning`, `.badge-error`, `.badge-info`
- Alerts: `.alert`, `.alert-success`, `.alert-warning`, `.alert-error`, `.alert-info`
- Dividers: `.divider`, `.divider-vertical`
- Code: `.code`, `.code-block`
- Loading: `.spinner`, `.progress-bar`
- Tooltips: `.tooltip`

### When to Use What

**Use utility classes for:**
- Common layout patterns (flex, grid, spacing)
- Typography adjustments
- Simple visual states (badges, alerts)
- One-off styling that doesn't warrant a component

**Keep component CSS for:**
- Complex, multi-element components (cards, tables, forms)
- Components with hover/focus/active states
- Responsive behavior specific to a component
- Domain-specific styling

### Design Tokens
Always use CSS custom properties from the token files (`00-tokens-brand.css`, `00-tokens-structural.css`):
```css
/* Good */
color: var(--ink);
padding: var(--space-4);
border-radius: var(--radius-default);

/* Bad */
color: #333;
padding: 16px;
border-radius: 8px;
```

## Agent skills

### Issue tracker

Issues live in GitHub Issues for `hanscanonico/life_simulator`, driven through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage labels, used verbatim: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root, alongside the existing `docs/DESIGN.md` and `docs/design_record.md`. See `docs/agents/domain.md`.
