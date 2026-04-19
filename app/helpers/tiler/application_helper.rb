module Tiler
  module ApplicationHelper
    def widget_type_options
      Tiler.widgets.options_for_select
    end
  end
end
