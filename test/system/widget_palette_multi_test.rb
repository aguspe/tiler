require "application_system_test_case"

module Tiler
  class WidgetPaletteMultiTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      5.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard(name: "Multi Drop #{SecureRandom.hex(3)}")
      create_panel(@dash, title: "Seed", widget_type: "clock",
                   x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
    end

    # Mirrors the production drop handler in show.html.erb: POST to panels#create,
    # render the turbo_stream response so the new .grid-stack-item appears in DOM,
    # then ask gridstack to hydrate it (so subsequent move events fire PATCH layout).
    def drop_widget(widget_type, x:, y:, hydrate: false)
      klass = Tiler.widgets[widget_type]
      w = klass.default_size[:w] || klass.default_size["w"]
      h = klass.default_size[:h] || klass.default_size["h"]
      cfg = klass.default_config.to_json
      label = klass.label
      script = <<~JS
        var done = arguments[arguments.length - 1];
        var hydrate = #{hydrate};
        var el = document.querySelector('.grid-stack');
        var fd = new FormData();
        fd.append('panel[widget_type]', #{widget_type.to_json});
        fd.append('panel[title]', #{label.to_json});
        fd.append('panel[x]', #{x});
        fd.append('panel[y]', #{y});
        fd.append('panel[width]', #{w});
        fd.append('panel[height]', #{h});
        fd.append('panel[config]', #{cfg.to_json});
        fetch(window.location.pathname + '/panels', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': el.dataset.tilerCsrf,
            'Accept': 'text/vnd.turbo-stream.html'
          },
          body: fd,
          credentials: 'same-origin'
        }).then(function(res) {
          if (!hydrate) { done(res.status); return; }
          return res.text().then(function(html) {
            if (typeof Turbo !== 'undefined' && Turbo.renderStreamMessage) {
              Turbo.renderStreamMessage(html);
            }
            // Mirror show.html.erb's hydration pass so the new tile becomes a gridstack node.
            setTimeout(function() {
              var grid = el.gridstack;
              var items = el.querySelectorAll('.grid-stack-item');
              items.forEach(function(item) {
                if (!item.gridstackNode) { grid.makeWidget(item); }
              });
              done(res.status);
            }, 150);
          });
        });
      JS
      page.evaluate_async_script(script)
    end

    test "two palette drops in sequence both persist with distinct ids" do
      visit dashboard_path(@dash.slug)
      click_button "Add Panel"
      assert_selector "[data-tiler-palette-widget]", wait: 5
      starting_count = @dash.panels.count

      drop_widget("clock", x: 4, y: 0)
      drop_widget("text",  x: 8, y: 0)

      sleep 0.5
      @dash.reload
      assert_equal starting_count + 2, @dash.panels.count
      types = @dash.panels.pluck(:widget_type).sort
      assert_includes types, "clock"
      assert_includes types, "text"
    end

    test "drop-then-move: dropped panel can be moved and PATCH layout persists new coords" do
      visit dashboard_path(@dash.slug)
      click_button "Add Panel"
      assert_selector "[data-tiler-palette-widget]", wait: 5

      drop_widget("text", x: 0, y: 4, hydrate: true)
      @dash.reload

      new_panel = @dash.panels.where(widget_type: "text").order(created_at: :desc).first
      assert_not_nil new_panel
      assert_equal 0, new_panel.x
      assert_equal 4, new_panel.y

      # Wait for the new tile to appear in DOM via Turbo Stream + gridstack hydration.
      assert_selector "[gs-id='#{new_panel.id}']", wait: 5

      # Move it via gridstack JS API (mirroring dashboard_flow_test.rb pattern).
      page.execute_script(<<~JS, new_panel.id)
        var id = arguments[0];
        var grid = document.querySelector('.grid-stack').gridstack;
        var widget = grid.engine.nodes.find(function(n) { return n.el.getAttribute('gs-id') == String(id); });
        if (widget) grid.update(widget.el, { x: 6, y: 5 });
      JS

      # Wait for PATCH layout to persist.
      deadline = Time.now + 5
      loop do
        new_panel.reload
        break if new_panel.x == 6 && new_panel.y == 5
        raise "PATCH layout never persisted (x=#{new_panel.x}, y=#{new_panel.y})" if Time.now > deadline
        sleep 0.1
      end

      assert_equal 6, new_panel.x
      assert_equal 5, new_panel.y
    end
  end
end
