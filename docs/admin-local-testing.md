# Local admin testing

The custom Tailwind admin replaces RailsAdmin at `/admin` on
`codex/tailwind-admin-refactor`. Run it against your normal local development
database. This change requires no schema migrations or production configuration
changes.

## Start the application

```sh
bundle install
bin/dev
```

Open <http://localhost:3000/admin> and sign in with the configured staff Google
account. The existing OAuth configuration and administrator bootstrap procedure
in the README still apply. No development authentication bypass was added.

`bin/dev` starts the Rails server and Tailwind watcher. The admin uses importmap
and locally vendored Chart.js, so it needs no Node package installation or CDN
connection for its styles, icons, or charts.

## Review workflows

Use synthetic local records for deletion and permission testing.

1. **Overview:** inspect live status, follow a hostname to heartbeat/log details,
   change kiosk groups and date presets, enter custom dates, expand report
   groups, and compare session counts, durations, and utilization with familiar
   data. Empty and missing-fallback states should remain useful.
2. **Slides:** upload a 1920 by 1080 image, leave the title or duration blank to
   check defaults, assign kiosks, change dates, replace an image, and preview the
   original. Try an incorrect image size and an invalid date range. A failed
   save must preserve the original image and saved assignments; choose the file
   again when retrying an upload.
3. **Kiosks and groups:** edit metadata and content, filter assignment choices,
   move a kiosk between groups, check slide counts, and open a public screensaver
   preview. Changing kiosk slugs or hostnames has the same historical-linking
   implications as before.
4. **Staff access:** review existing role records and their direct kiosk/group
   grants. Check the UI with a scoped staff account as well as an administrator.
   Direct access must not expand to the whole group, shared slides must remain
   read only where appropriate, and global fallback changes must remain
   administrator-controlled.
5. **Lists and exports:** search, use resource filters or a field comparison,
   change sorting, and page through records. Export all filtered results or
   selected records in CSV, JSON, and XML. The full-results export lets you choose
   scalar and association columns. Nested exports respect content access.
6. **Deletion:** check cancellation and confirmation on synthetic records.
   If one selected record has a protected reference, bulk deletion keeps the
   whole selection. Deleting a host preserves historical usage.
7. **Screensaver:** verify active, future, expired, fallback, and empty content;
   wake to the catalog; check `/home` navigation and usage recording. Browser
   refresh and empty-screen recovery remain part of the public player.
8. **Narrow screens and keyboard:** try the collapsible navigation, horizontal
   table scrolling, assignment search, focus indicators, and chart data tables.

## Access management behavior

User managers now see the workflows already authorized by `Ability`; the former
menu checked a broader action and could hide them. Existing restrictions on
editing your own permissions or administrator permissions remain enforced in
the controller and model.

The interface edits existing user-permission records. Creating additional role
records remains disabled, as it was in the previous admin. New accounts still
receive their initial staff permission through Google sign-in.

Legacy singular list, detail, and edit URLs redirect to their new equivalents.
The host-details JSON endpoint remains at `/admin/kiosk_hosts/:host.json`, with
its existing authentication and kiosk-scope rules.

## Automated verification

On October 23, 2026, the development branch passed 89 application tests
(317 assertions), 7 browser tests, production-mode eager loading
and asset compilation, Brakeman with no warnings, and the updated dependency
audit with no known vulnerabilities. Browser tests also passed after removing
precompiled assets, exercising the asset pipeline used by local development.

The test suite covers permissions and crafted requests, transactional assignment
changes, image replacement failures, export filtering and injection protection,
host history, report scoping, and browser workflows. Browser tests use synthetic
authentication data only inside the test process.

```sh
bin/rails test
bin/rails test:system
bin/rails zeitwerk:check
bin/rails assets:precompile
bundle exec brakeman -q --no-pager
bundle exec bundle-audit check --update
```

Automated local checks do not validate real Google OAuth, physical kiosk clients,
or production location-feed responses. Those integrations should be included in
your local acceptance checks where available. Production deployment is separate
from committing and pushing this development branch.

## Refreshing the Help screenshots

The account menu links to `/admin/help`. Its slide-upload guide uses four real
browser screenshots with synthetic staff, kiosk, and event records. The
RailsAdmin comparison was checked against the former application configuration
and RailsAdmin 3.3.1's picker and save controls.

Use an isolated local test database to regenerate the images. Rails loads test
fixtures into that database; never point this command at development data or a
production copy. The capture mode requires a loopback database host and a
database name ending in `_test`.

```sh
env RAILS_ENV=test \
  DATABASE_URL=postgresql://127.0.0.1:5432/kiosk_screensaver_test \
  LOCATION_DATA_URL=http://127.0.0.1:9/locations \
  GOOGLE_CLIENT_ID= GOOGLE_CLIENT_SECRET= GOOGLE_DOMAIN=example.com \
  PARALLEL_WORKERS=1 CAPTURE_ADMIN_HELP=1 \
  bin/rails test:system -i /staff_can_add/
```

The workflow test writes the four PNGs into `app/assets/images/help/` only when
`CAPTURE_ADMIN_HELP=1` is set. Ordinary test runs do not modify them. The sample
poster is drawn from SVG in the browser; no real uploads or external images are
used. Review every screenshot before committing, and update the image width
and height attributes in the Help template if the capture dimensions change.
