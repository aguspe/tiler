require "tiler/presets"

namespace :tiler do
  desc "Seed the default Tiler dashboard (alias for tiler:preset:default)"
  task seed: :environment do
    Tiler::Presets.run!(:default)
  end

  desc "List available Tiler presets"
  task preset: :environment do
    puts "Available Tiler presets:"
    Tiler::Presets.names.each do |n|
      puts "  - bin/rails tiler:preset:#{n}"
    end
  end

  namespace :preset do
    desc "Default preset — generic demo dashboard touching every widget"
    task default: :environment do
      Tiler::Presets.run!(:default)
    end

    desc "Test-automation preset (Allure-style) — pass rate, suites, failures, trends"
    task test_automation: :environment do
      Tiler::Presets.run!(:test_automation)
    end

    desc "Commerce preset — revenue, orders, AOV, conversion, top products"
    task commerce: :environment do
      Tiler::Presets.run!(:commerce)
    end
  end
end
