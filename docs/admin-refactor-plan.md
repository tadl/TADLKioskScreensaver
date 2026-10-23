# Custom Tailwind admin refactor plan

Replace RailsAdmin with an application-owned Rails admin interface styled with
Tailwind. Preserve the screensaver, kiosk integrations, stored data, permission
boundaries, and staff workflows. Refactor supporting code where it makes those
behaviors easier to understand and test.

Development branch: `codex/tailwind-admin-refactor`.
Initial baseline: `3e3153d`, reviewed October 23, 2026.

## Implementation status

The custom admin now runs at `/admin` on the development branch. It includes
content management, host inventory and diagnostics, user-permission editing,
permission definitions, live status, usage reports, field filters, sorting,
pagination, CSV/JSON/XML exports, and selected-record actions.

RailsAdmin, its overrides and patches, jQuery UI, and SassC have been removed.
Chart.js is served locally. The database schema, screensaver routes, telemetry
API, stored uploads, and maintenance tasks retain their existing contracts.
The temporary `/admin-next` route proposed below was not needed for the finished
development branch; local review uses `/admin` directly.

The implementation makes these deliberate corrections:

- User managers can see the access-management screens their existing abilities
  authorize. Self-elevation and administrator-role restrictions still apply.
- Association writes roll back when validation fails. Bulk deletion is atomic
  when a selected record cannot be deleted.
- Invalid image replacement preserves the original saved image.
- Exports use explicit scalar/association allowlists, scope related content,
  exclude sensitive account fields, and guard CSV formula cells.
- A slide edit that removes the actor's last kiosk assignment returns to the
  list instead of redirecting to an inaccessible detail page.

New user-permission record creation remains unavailable, matching the old admin.
Accounts are still provisioned by Google sign-in and existing role records can
be edited. Useful legacy list/detail/edit GET bookmarks redirect to the new UI.
Legacy mutation requests are not forwarded.

Use the [local testing guide](admin-local-testing.md) to review the real staff
workflows and provide feedback. The architecture and delivery sequence below
retain the original planning context; production release still requires local
acceptance and separate deployment authorization.

## Recommended direction

Keep Rails, PostgreSQL, Active Storage, Google OAuth, CanCanCan, importmap,
Turbo, and Stimulus. Build ordinary namespaced controllers, ERB views, partials,
and Rails forms. The app already has Tailwind 4 and its build process; a separate
frontend framework or JavaScript build system is unnecessary for this work.

Replace the complete RailsAdmin integration, including its generated workflows,
dashboard overrides, asset dependencies, and patches. Build and test the new
admin alongside the existing interface before switching `/admin` over. Keep the
database schema and kiosk contracts stable during that replacement.

The current application already has useful domain boundaries, including
`ScreensaverSlideDeck`, `KioskLogIngestor`, `Admin::KioskHostDetails`, and session
duration calculations. Retain these and their tests. A complete admin replacement
does not require rewriting working kiosk behavior.

RailsAdmin has recent release activity: RubyGems lists 3.3.1 and 4.0 beta2 dated
October 5, 2026. The reason for replacing it is control over workflows, design,
and application code rather than a confirmed upstream abandonment.
Sources: [RailsAdmin versions](https://rubygems.org/gems/rails_admin/versions),
[upstream project](https://github.com/railsadminteam/rails_admin).

## Existing functionality to preserve

| Area | Required behavior | Current owning code |
| --- | --- | --- |
| Sign in | Google domain restriction, account provisioning, profile refresh, initial staff permission, login failure handling, and logout | `app/controllers/sessions_controller.rb`, `app/models/user.rb`, OAuth initializers |
| Admin access | Login requirement, CanCanCan record access, kiosk and group scopes, and restricted form fields | `app/models/ability.rb`, `app/models/user.rb`, `config/initializers/rails_admin.rb` |
| Slides | List, inspect, upload, replace images, edit, and authorized deletion; thumbnails and original-image links; filename title default; 10-second duration default; positive integer durations; start-date default and inclusive display dates | `app/models/slide.rb`, RailsAdmin slide configuration |
| Image validation | Exactly 1920 by 1080, missing or unreadable image errors, dimension metadata, and thumbnails that preserve the original | `app/models/slide.rb`, Active Storage configuration |
| Assignments | Slides assigned to multiple kiosks; only eligible images offered by the kiosk form; scoped choices; existing assignments outside an actor's scope preserved | `Slide#kiosk_ids=`, RailsAdmin association scopes |
| Shared content | Scoped staff can read assigned shared slides but cannot edit slides affecting inaccessible kiosks; global fallback changes remain administrator-controlled | `User#readable_slide_ids`, `User#editable_slide_ids`, `Ability`, slide validation |
| Kiosks | Name, slug, catalog URL, location, optional group, assigned slides, slide counts, and links to the public screensaver | `app/models/kiosk.rb`, RailsAdmin kiosk configuration |
| Groups | Name, slug, location feed shortname, kiosk membership, and scoped visibility | `app/models/kiosk_group.rb`, RailsAdmin group configuration |
| Hosts | Name, location, active flag, notes, status/session associations; deleting a host clears live status and preserves usage history | `app/models/host.rb`, RailsAdmin host configuration |
| Users and permissions | OAuth-created accounts, existing permission definitions, user-role records, direct kiosk and group assignments, self-elevation restrictions, and admin flag synchronization | `User`, `UserPermission`, `Permission`, `Ability`, RailsAdmin configuration |
| Dashboard | Content shortcuts, missing active fallback warning, scoped live status grouped by kiosk, OPAC/screensaver state, and elapsed state duration | `app/views/rails_admin/main/dashboard.html.erb`, `_kiosk_status_grid.html.erb` |
| Host diagnostics | Authenticated details, latest host-to-kiosk authorization, heartbeat freshness, uptime, service status, Chromium/DevTools and WireGuard details, recent logs and stack traces, and dotted hostnames | `Admin::KioskHostsController`, `Admin::KioskHostDetails`, `rails_admin_kiosks.js` |
| Usage reporting | Group filters, all-accessible-kiosks selection, eight date presets, custom ranges capped at 366 days, charts, and tables with session counts, first/last session, average/total duration, and utilization | Dashboard template, usage partials, `ApplicationHelper`, `KioskSession` |
| Generated admin tools | Authorized search, sorting, filtering, pagination, exports, selected-record exports, bulk deletion, confirmation, validation errors, and useful success/failure messages | RailsAdmin actions and generated views |
| Public screensaver | Existing kiosk/host parameters, scheduled slides and global fallbacks, random playback, duration limits, wake input, refresh every 30 minutes, empty-screen recovery, image-error handling, and stall recovery | `ScreensaverController`, `ScreensaverSlideDeck`, `app/views/screensaver/` |
| Catalog navigation | `/exit` starts usage and records OPAC state; `/home` redirects without resetting usage or state; returning to the screensaver closes usage; stale sessions retain the 12-hour cap | `ScreensaverController`, `KioskStatus`, `KioskSession` |
| Kiosk API | Existing heartbeat/log routes, headers, identifiers, authentication, accepted payloads, limits, timestamp handling, responses, and ingestion | `Api::KiosksController`, `KioskLogIngestor` |
| Maintenance | Slide expiration unassigns content; later deletion purges images; log retention rejects invalid settings; stale-session cleanup remains available | `lib/tasks/` |
| Operations | `/up`, existing error responses, asset compilation, local/persistent upload storage, production process configuration, and CI checks | Routes, environment configuration, process files, CI workflow |

RailsAdmin makes some behavior implicit. Before replacing each resource, record
its actual available actions, field visibility, filters, sorts, export fields,
association choices, and validation responses using synthetic data. The table
is the inventory; those acceptance cases establish the detailed contract.

### Permission details that require particular care

- A direct kiosk grant must not grant neighboring kiosks in the same group.
- Group grants include every kiosk in that group. The existing global management
  permissions have broader scopes than ordinary slide management.
- A staff account can reach the dashboard without permission to change content.
  Dashboard scopes and resource editing permissions are distinct.
- Scope both the records being edited and the associations submitted with them.
  Filtering a select menu is insufficient protection against a crafted request.
- Enforce field restrictions in server-side parameter handling. Kiosk slug,
  identity, location, group, slide assignments, and fallback fields have different
  rules depending on the actor and action.
- Apply the same record and association restrictions to exports, bulk actions,
  diagnostics, and direct requests as to the visible interface.
- Keep `Current.user` set for admin writes; existing model safeguards depend on
  the actor being available.
- Preserve admin bootstrap behavior and the synchronization of admin-role
  changes. Do not create a second role system.

## Proposed admin experience

Use a restrained TADL-branded interface with a persistent desktop sidebar,
compact mobile navigation, clear page titles, and prominent primary actions.
Use neutral surfaces, readable tables, consistent spacing, and a small set of
accent and status colors. Reuse the existing logo and mascot where helpful.
Keep status text and icons alongside color.

| Navigation | Main workflows |
| --- | --- |
| Overview | Existing live status and usage reporting, fallback warning, upload shortcut, and host details |
| Slides | Thumbnail list or grid, search and schedule filters, preview, upload/edit form, kiosk selection, exports, and permitted deletion |
| Kiosks | Searchable list, group filter, assigned-slide previews, public screensaver link, and permitted editing |
| Kiosk groups | Membership, location shortname, and permitted editing |
| Hosts | Inventory and permitted editing, with access to existing diagnostics |
| Users and access | Existing role records and kiosk/group grants, with explicit explanations of inherited scope |
| Permissions | Existing definitions and authorized maintenance |

Show navigation and actions according to the actor's permissions. Staff should
see their accessible content and understand why shared content is read-only.
Preserve all existing report controls on Overview initially; splitting them into
separate pages can be considered after parity.

Use ordinary labelled controls and searchable checkbox lists for assignments
before introducing custom combobox widgets. Include selected counts and clear
group labels. Explain shared-slide restrictions and the global effect of
fallback content close to the relevant controls.

Forms should show an error summary plus field errors, preserve submitted values
after validation failure, and clearly distinguish saving from cancelling. Image
replacement needs explicit tests proving an invalid replacement does not lose
the current image or create unintended kiosk assignment changes.

Keyboard navigation, visible focus, semantic tables/headings, responsive layouts,
and legible contrast are part of each screen. Host details can use a native
dialog with focus restoration or a linked details page; retain an accessible
table alongside usage charts. Verify empty, loading, denied, failed, and populated
states as well as the usual success path.

## Implementation structure

- Introduce `Admin::BaseController < ApplicationController` for authenticated
  HTML admin pages and the admin layout. Keep action-specific authorization
  explicit and reuse `Ability` and existing scope rules.
- Use dedicated controllers for the dashboard, slides, kiosks, groups, hosts,
  permission definitions, and user permissions. Keep user-permission writes
  attached to `UserPermission`, even if the interface presents them by user.
- Use shared partials and helpers for navigation, forms, filters, pagination,
  status badges, empty states, and confirmation. Add a component dependency only
  if actual repetition justifies it.
- Move dashboard querying and aggregation out of ERB into a focused report/query
  object. Retain the existing duration and location-feed rules first, then
  improve query behavior with regression tests and representative synthetic data.
- Reuse `Admin::KioskHostDetails` and its JSON contract. Preserve the existing
  endpoint's 401/403/404 responses independently of HTML login redirects.
- Use small Stimulus controllers for interactions such as assignment search,
  date presets, host details, and chart lifecycle. Clean up event listeners,
  requests, and chart instances when Turbo disconnects or caches a page.
- Keep charts with equivalent data and presentation. Prefer a pinned local chart
  asset through the existing asset pipeline; do not replace Chart.js merely
  to change the styling. The new admin should not require Bootstrap, jQuery,
  RailsAdmin widgets, or remote font/icon assets.
- Keep pagination explicit. If the replacement uses Kaminari, declare it as a
  direct dependency; RailsAdmin currently brings it in transitively. Simple
  bounded Active Record pagination is also sufficient for these resource lists.
- Implement exports with explicit field and association allowlists. Preserve
  existing CSV, JSON, and XML capabilities and characterize their selected-record
  and filtering behavior. Never accept arbitrary Ruby methods from export input.

Keep Rails framework defaults at their current 7.1 settings during the admin
replacement, even though the app runs Rails 8.1. Reviewing newer defaults is
a separate compatibility change. Likewise, keep Sprockets and image processing
in place until dependency removal proves whether anything else is needed.

## Delivery sequence

### 1 Capture behavior and fill test gaps

Add request and browser tests covering actual staff workflows and the permission
matrix before replacing the corresponding RailsAdmin behavior. Use synthetic
actors with admin, each management permission, direct grants, group grants,
combined grants, and no assigned kiosks.

Cover successful writes, invalid uploads, unauthorized fields/associations,
shared content, direct URL access, and permitted/denied export and bulk actions.
Add dashboard/report cases for all presets, range boundaries, cross-midnight
sessions, missing groups, location-feed failures, and the existing utilization
formula. Preserve that formula while moving it out of templates.

The current browser tests cover RailsAdmin widgets and empty screensaver
recovery; they do not cover the full authenticated staff workflow. Add a test-only
OAuth strategy or stub for real login navigation without adding an application
authentication bypass. Add missing `/home` and populated-player coverage where
needed to protect public behavior during shared asset changes.

Completion: the inventory has acceptance cases and permission expectations,
and the current implementation passes them or has a separately recorded defect.

### 2 Build the admin shell and first reviewable screens

Add the custom layout, authenticated controllers, navigation, shared form/table
patterns, and responsive styles. Mount the replacement at `/admin-next` during
development, with the existing host-details endpoint retained at its current
path. Keep RailsAdmin at `/admin` until the replacement is complete.

Build a read-only overview and slide listing with synthetic data for visual
review. Exercise admin, scoped staff, empty, and denied states. Keep the current
post-login destination until final cutover.

Completion: the design and navigation work in a real Rails page, access is
enforced, and new styling does not affect the public screensaver or old admin.

### 3 Replace content management

Implement slides, kiosks, and kiosk groups, including previews, uploads,
replacement validation, schedule controls, scoped association choices, field
restrictions, search, sorting, filtering, and pagination. Preserve shared-slide
rules and hidden assignments in both directions of association editing.

Completion: staff can complete existing content tasks through the new UI;
request and browser tests verify persistence, failure states, and permissions.

### 4 Replace monitoring and reporting

Move the live status display, host diagnostics, usage filters, charts, and host
statistics into application-owned views and query code. Preserve the existing
fallback warning, date presets, location-feed caching/failure behavior, and
session calculations. Avoid changing the meaning of a session or utilization.

Completion: old and new views produce equivalent metrics for the same synthetic
data; diagnostics remain scoped and browser interactions work without Bootstrap.

### 5 Replace access management and generated admin actions

Implement host inventory, permission definitions, and user-permission editing.
Complete exports, selected-record actions, deletion confirmations, and bulk
deletion wherever currently authorized. Retain callback and attachment cleanup
semantics rather than bypassing them with direct database deletion.

Completion: every authorized action in the inventory has a tested replacement,
including records with protected associations and bulk actions with failures.

### 6 Switch routes and retire RailsAdmin

Move the new admin to `/admin`, update OAuth redirects and application links,
and remove the engine. Map useful existing GET bookmarks to equivalent pages;
do not redirect old mutation requests into new writes.

Remove the RailsAdmin initializer, HABTM sorting patch, Turbo format patch,
layout/dashboard overrides, legacy admin JavaScript, vendored jQuery UI override,
and obsolete asset manifest entries. Rename presentation helpers such as
`rails_admin_label` where they still have an application purpose.

Remove `rails_admin` and dependencies used only by it. Audit `sassc-rails`,
`nested_form`, export serializers, pagination, and legacy styles individually;
retain or declare anything still used by the custom interface. Remove obsolete
widget tests only when equivalent application behavior and injection protections
have appropriate replacement coverage.

Completion: no runtime RailsAdmin references or engine routes remain; all
existing app, build, security, and browser checks pass on the new admin.

### 7 Review the affected application code and prepare release

Review controllers, models, helpers, queries, upload handling, and JavaScript for
measurable maintainability improvements after parity. Prioritize clear permission
boundaries, duplicated calculations, excessive queries, and predictable failures.
Keep each additional improvement small and covered by behavior tests. Record
unrelated dependency upgrades, schema redesigns, or new features separately.

Prepare the final workflow checklist, deployment instructions, and rollback
reference. With a stable schema and storage contract, an application rollback
should not require converting data. Verify this assumption before release.
Production deployment remains a separate explicitly authorized operation.

## Details to settle during characterization

1. **User management visibility:** `Ability` grants `manage_users` holders read,
   update, and destroy access to eligible user-permission records, while the
   RailsAdmin menu checks `:manage`; creation is disabled for `UserPermission`.
   Verify actual access through both navigation and direct URLs before choosing
   the replacement's visible actions. Treat a change here as an explicit behavior
   correction, not an incidental UI redesign.
2. **Permission administration:** permission names drive authorization logic.
   Verify current edit/delete effects and dependent role cleanup before building
   a friendlier editor. Do not silently reinterpret or rename permission values.
3. **Exports and bookmarks:** capture actual field/association selection, output
   formats, filters, selected IDs, and useful legacy GET links with synthetic
   records. Preserve capability without copying RailsAdmin's internal API.
4. **Destructive and association actions:** verify group deletion with members,
   kiosk deletion with statuses/slides, permission deletion, host renaming, and
   bulk partial failure. Preserve history and show actionable constraint errors.
5. **Slide link data:** `Slide#link` exists and is shown on the current detail
   page, but is absent from current create/edit forms and playback payloads.
   Preserve stored values and display; new editing or click-through behavior
   would be a separate feature decision.

These details can be investigated while the read-only shell is built. A discovered
bug should have a focused regression test and a clearly documented correction;
feature parity does not require preserving a security vulnerability.

## Verification and release criteria

Baseline checks on October 23, 2026, using Ruby 3.4.11 and the committed lockfile:

| Check | Initial result |
| --- | --- |
| `bundle check` | Passed |
| `bin/rails test` | 64 tests, 224 assertions; no failures, errors, or skips |
| `bin/rails test:system` | 5 tests, 14 assertions; no failures, errors, or skips |
| `bin/rails zeitwerk:check` | Passed |
| `bin/rails assets:precompile` | Passed in the test environment |
| `bundle exec brakeman -q --no-pager` | No warnings |
| `bundle exec bundle-audit check --update` | No known vulnerabilities reported |

The baseline used a separate local PostgreSQL test database named
`kiosk_screensaver_refactor_test`, test storage, disabled Google client credentials,
and a loopback location-feed URL. It did not exercise production, real OAuth, or
physical kiosks. Existing checks are a starting point, not proof of full parity.

Before release, require:

- Completed acceptance cases for every inventory area and each relevant actor.
- Browser verification of authenticated upload/edit/assignment, permissions,
  diagnostics, reports, export, and deletion workflows.
- Verified keyboard/focus behavior and desktop/narrow viewport layouts.
- Equivalent screensaver routes, JSON payloads, API behavior, session history,
  maintenance tasks, and Active Storage access.
- Passing CI, production-mode asset verification, and an eager-loading check
  after RailsAdmin and its transitive dependencies have been removed.
- A final dependency/reference audit and a documented application rollback.
- A user review of the new admin before any separately authorized deployment.

The first implementation slice is characterization tests plus the read-only
admin shell and slide listing. This gives a concrete design to review while the
existing editing interface remains available throughout development.
