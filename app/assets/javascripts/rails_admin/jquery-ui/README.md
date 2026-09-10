# RailsAdmin jQuery UI position security backport

RailsAdmin 3.3.0 vendors jQuery UI 1.12.1. This Sprockets override preserves
that implementation with the upstream CVE-2021-41184 fix applied: string
`of` arguments are CSS selectors, never HTML to instantiate.

Upstream fix:
https://github.com/jquery/jquery-ui/commit/effa323f1505f2ce7a324e4f429fa9032c72f280

The original MIT license header is retained. Remove this override once
RailsAdmin ships jQuery UI 1.13.0 or newer. The browser regression tests
exercise the compiled RailsAdmin bundle and its autocomplete/sortable widgets.
