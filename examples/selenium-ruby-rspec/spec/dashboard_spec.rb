require_relative "spec_helper"

RSpec.describe "Tiler dashboard" do
  it "renders the grid with at least one panel" do
    visit_dashboard

    @wait.until { @driver.find_element(css: ".grid-stack-item") }
    panels = @driver.find_elements(css: ".grid-stack-item")
    expect(panels.length).to be >= 1
  end

  it "renders the clock widget with a current time" do
    visit_dashboard

    # Clock is one of the seeded panels in the dummy app.
    clock_time = @wait.until { @driver.find_element(css: ".tiler-clock-time") }
    # Format is HH:MM:SS (24h) or H:MM:SS AM/PM (12h)
    expect(clock_time.text).to match(/\d{1,2}:\d{2}:\d{2}/)
  end

  it "drives a panel move via the gridstack JS API and persists via PATCH" do
    visit_dashboard

    # Wait for at least one tile, then enter edit mode.
    @wait.until { @driver.find_element(css: ".grid-stack-item[gs-id]") }
    @driver.find_element(css: "[data-tiler-toggle-edit]").click

    # Capture the first panel's id; move it to a non-overlapping slot.
    panel_id = @driver.find_element(css: ".grid-stack-item[gs-id]").attribute("gs-id")
    new_x, new_y = 4, 8

    @driver.execute_script(<<~JS, panel_id, new_x, new_y)
      const id = arguments[0];
      const x  = arguments[1];
      const y  = arguments[2];
      const grid = document.querySelector('.grid-stack').gridstack;
      const node = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
      grid.update(node.el, { x: x, y: y });
    JS

    # Poll the DOM (gs-x / gs-y reflect the persisted state once gridstack updates).
    @wait.until do
      el = @driver.find_element(css: ".grid-stack-item[gs-id='#{panel_id}']")
      el.attribute("gs-x") == new_x.to_s && el.attribute("gs-y") == new_y.to_s
    end

    # Reload the page; if PATCH layout fired and persisted, the new coords survive.
    @driver.navigate.refresh
    @wait.until { @driver.find_element(css: ".grid-stack-item[gs-id='#{panel_id}']") }
    el = @driver.find_element(css: ".grid-stack-item[gs-id='#{panel_id}']")
    expect(el.attribute("gs-x")).to eq new_x.to_s
    expect(el.attribute("gs-y")).to eq new_y.to_s
  end
end
