require "application_system_test_case"

module Tiler
  class WidgetPaletteDropTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      5.times { create_record(@source, { status: "ok", duration: 100.0, value: 200 }) }
      @dash = create_dashboard(name: "Drop Test #{SecureRandom.hex(3)}")
      # Need an existing panel so the dashboard renders the .grid-stack branch (which carries the palette).
      create_panel(@dash, title: "Seed", widget_type: "clock",
                   x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
    end

    # For each registered widget type, assert that simulating a palette drop
    # creates a Panel with the correct widget_type and renders its preview without 5xx.
    Tiler.widgets.types.each do |widget_type|
      define_method "test_drop_#{widget_type}_creates_panel_and_renders_preview" do
        visit dashboard_path(@dash.slug)
        click_button "Add Panel"
        assert_selector "[data-tiler-palette-widget][data-widget-type='#{widget_type}']", wait: 5

        starting_count = @dash.panels.count

        # Simulate the gridstack 'dropped' event: the handler in show.html.erb expects
        # a newly added DOM node carrying data-widget-type + data-default-config.
        # Easiest reliable simulation: directly call the POST that the JS handler would send.
        klass = Tiler.widgets[widget_type]
        default_w = klass.default_size[:w] || klass.default_size["w"]
        default_h = klass.default_size[:h] || klass.default_size["h"]
        # Use evaluate_async_script so we wait for the fetch promise to resolve
        # before asserting on the DB. (execute_script returns immediately and
        # the test would race the server roundtrip.)
        status = page.evaluate_async_script(<<~JS, widget_type, klass.label, klass.default_config.to_json, default_w, default_h)
          var done = arguments[arguments.length - 1];
          var widgetType = arguments[0];
          var label = arguments[1];
          var configJson = arguments[2];
          var w = arguments[3];
          var h = arguments[4];
          var el = document.querySelector('.grid-stack');
          var fd = new FormData();
          fd.append('panel[widget_type]', widgetType);
          fd.append('panel[title]', label);
          fd.append('panel[x]', 0);
          fd.append('panel[y]', 6);
          fd.append('panel[width]', w);
          fd.append('panel[height]', h);
          fd.append('panel[config]', configJson);
          fetch(window.location.pathname + '/panels', {
            method: 'POST',
            headers: {
              'X-CSRF-Token': el.dataset.tilerCsrf,
              'Accept': 'text/vnd.turbo-stream.html'
            },
            body: fd,
            credentials: 'same-origin'
          }).then(function(res) {
            return res.text().then(function(body) { done({ status: res.status, body: body.substring(0, 500) }); });
          }).catch(function(err) { done({ status: 0, body: String(err) }); });
        JS

        @dash.reload
        assert_equal starting_count + 1, @dash.panels.count,
                     "#{widget_type} not persisted (HTTP #{status['status']}): #{status['body']}"

        new_panel = @dash.panels.where(widget_type: widget_type).order(created_at: :desc).first
        assert_not_nil new_panel, "#{widget_type} panel not found"

        # Hit the preview endpoint directly — that's what the turbo-frame loads.
        # Selenium driver doesn't expose status_code, so we sniff the rendered HTML
        # for Rails' standard 5xx error markers. Absence proves the partial rendered.
        preview_path = preview_dashboard_panel_path(@dash, new_panel)
        Capybara.using_session("preview-#{widget_type}") do
          visit preview_path
          html = page.html
          refute_match(/ActionView::Template::Error/, html, "#{widget_type} preview raised template error")
          refute_match(/We're sorry, but something went wrong/, html, "#{widget_type} preview returned 500")
          refute_match(/<title>Action Controller: Exception caught<\/title>/, html, "#{widget_type} preview hit dev exception page")
        end
      end
    end
  end
end
