require "test_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium/webdriver"
require "axe-capybara"
require "axe/matchers"

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  include Axe::Matchers

  # Minitest-friendly wrapper around the Axe::Matchers::BeAccessible matcher.
  # Runs axe-core in the browser via the gem's BeAccessible matcher; on failure,
  # fails the test with the axe-generated failure_message (list of violations).
  def assert_accessible(page, matcher: be_accessible)
    assert matcher.matches?(page), matcher.failure_message
  end
end
