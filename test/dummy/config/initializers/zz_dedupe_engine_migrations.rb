# Ensure engine migrations are discoverable AND not duplicated.
#
# Two boot paths matter:
#   1. `bin/rails ...` from the engine root — sets ENGINE_PATH, so the engine railtie
#      auto-appends the engine's migrations to the dummy app's paths.
#   2. `bundle exec rails ...` from test/dummy — engine railtie does NOT auto-append.
#
# Path 1 doubles up if we manually append, causing "Duplicate migration" errors at
# schema load time. Path 2 leaves the dummy app blind to engine migrations.
#
# This initializer adds the path if missing and always dedupes.

engine_migrate_path = Tiler::Engine.root.join("db/migrate").to_s
paths               = Rails.application.config.paths["db/migrate"]
list                = paths.to_a
list << engine_migrate_path unless list.include?(engine_migrate_path)
list.uniq!
paths.instance_variable_set(:@paths, list)

# Belt-and-suspenders: the engine railtie can also inject migration paths via
# `ActiveRecord::Migrator.migrations_paths` (set on the connection pool's
# migration context). Patch `assume_migrated_upto_version` to dedupe the
# `inserting` array before the duplicate check fires. This protects against
# `db:test:prepare` and `maintain_test_schema!` which use a fresh AR pool
# whose migration_context can resolve the engine path twice.
ActiveSupport.on_load(:active_record) do
  module ActiveRecord
    module ConnectionAdapters
      module SchemaStatements
        unless method_defined?(:assume_migrated_upto_version_without_dedupe)
          alias_method :assume_migrated_upto_version_without_dedupe, :assume_migrated_upto_version

          def assume_migrated_upto_version(version)
            version = version.to_i
            sm_table = quote_table_name(pool.schema_migration.table_name)
            migration_context = pool.migration_context
            migrated = migration_context.get_all_versions
            versions = migration_context.migrations.map(&:version).uniq

            unless migrated.include?(version)
              execute "INSERT INTO #{sm_table} (version) VALUES (#{quote(version)})"
            end

            inserting = (versions - migrated).select { |v| v < version }
            execute insert_versions_sql(inserting) if inserting.any?
          end
        end
      end
    end
  end
end
