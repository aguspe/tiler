require_relative "lib/tiler/version"

Gem::Specification.new do |spec|
  spec.name        = "tiler"
  spec.version     = Tiler::VERSION
  spec.authors     = [ "Augustin Gottlieb" ]
  spec.email       = [ "augustin.gottlieb@merkle.com" ]
  spec.homepage    = "https://github.com/aguspe/tiler"
  spec.summary     = "Plug-and-play dashboards for Rails apps."
  spec.description = "Tiler is a mountable Rails engine that gives any Rails app configurable " \
                     "dashboards with pluggable widgets, JSON data sources, webhook ingestion, " \
                     "and Turbo-powered live panels. Inspired by Smashing."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "turbo-rails", ">= 2.0"
  spec.add_dependency "stimulus-rails", ">= 1.3"
end
