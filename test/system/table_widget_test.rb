require "application_system_test_case"

# End-to-end checks for the structured Table widget — sticky header on scroll
# and numeric column alignment.
module Tiler
  class TableWidgetTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Table #{SecureRandom.hex(3)}")
      preview = {
        "_preview" => {
          "columns" => [
            { "label" => "Endpoint", "num" => false },
            { "label" => "p50",      "num" => true  },
            { "label" => "p95",      "num" => true  },
            { "label" => "rpm",      "num" => true  }
          ],
          "rows" => 30.times.map do |i|
            [ "/api/r#{i}", "#{20 + i}ms", "#{100 + i * 4}ms", "#{900 - i * 10}" ]
          end,
          "total" => 30, "limit" => 30
        }
      }
      @panel = create_panel(@dash, title: "Endpoints", widget_type: "table",
                            data_source: nil,
                            x: 0, y: 0, width: 6, height: 3,
                            config: preview.to_json)
    end

    test "header is sticky inside the scroll container" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@panel.id} .tiler-table thead th", wait: 5
      pos = page.evaluate_script(<<~JS)
        (function() {
          var th = document.querySelector("turbo-frame#tiler_panel_#{@panel.id} thead th");
          return window.getComputedStyle(th).position;
        })();
      JS
      assert_equal "sticky", pos, "table header must be position:sticky"
    end

    test "numeric columns get right-aligned with mono numerals" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@panel.id} .tiler-table-num", wait: 5
      style = page.evaluate_script(<<~JS)
        (function() {
          var td = document.querySelector("turbo-frame#tiler_panel_#{@panel.id} tbody .tiler-table-num");
          var s = window.getComputedStyle(td);
          return { align: s.textAlign, font: s.fontFamily, numeric: s.fontVariantNumeric };
        })();
      JS
      assert_equal "right", style["align"], "numeric cells should be right-aligned"
      assert_match(/mono/i, style["font"], "numeric cells should use mono font (#{style.inspect})")
      assert_match(/tabular/i, style["numeric"], "numeric cells should use tabular-nums (#{style.inspect})")
    end

    test "non-numeric (group) cell stays left-aligned" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@panel.id} tbody tr td", wait: 5
      align = page.evaluate_script(<<~JS)
        (function() {
          var td = document.querySelector("turbo-frame#tiler_panel_#{@panel.id} tbody tr td:first-child");
          if (!td) return null;
          return { align: window.getComputedStyle(td).textAlign,
                   hasNum: td.classList.contains("tiler-table-num") };
        })();
      JS
      refute_nil align, "first cell of first row should exist"
      refute align["hasNum"], "group cell must NOT carry tiler-table-num class"
      assert_equal "left", align["align"]
    end
  end
end
