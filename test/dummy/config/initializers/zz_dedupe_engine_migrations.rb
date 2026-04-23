# Add the engine's db/migrate path if it isn't already present, then dedupe.
#
# Two boot paths matter:
#   1. `bin/rails ...` from the engine root — sets ENGINE_PATH, so the engine railtie
#      auto-appends the engine's migrations to the dummy app's paths.
#   2. `bundle exec rails ...` from test/dummy — engine railtie does NOT auto-append.
#
# Path 1 doubles up if we manually append, causing "Duplicate migration" errors at
# schema load time. Path 2 leaves the dummy app blind to engine migrations.
#
# This initializer runs AFTER all railties, so it can both add (for path 2) and
# dedupe (for path 1) safely.

engine_migrate_path = Tiler::Engine.root.join("db/migrate").to_s
paths               = Rails.application.config.paths["db/migrate"]
list                = paths.to_a
list << engine_migrate_path unless list.include?(engine_migrate_path)
list.uniq!
paths.instance_variable_set(:@paths, list)
