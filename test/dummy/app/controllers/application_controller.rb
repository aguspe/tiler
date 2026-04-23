class ApplicationController < ActionController::Base
  # No allow_browser gating — the Tiler dummy app is the test/example surface and
  # must respond to any Accept/User-Agent (Cypress, Selenium, Playwright, curl).
end
