module Esvg
  class Railtie < ::Rails::Railtie
    initializer "esvg.configure_view_controller" do |app|
      ActiveSupport.on_load :action_view do
        include Esvg::Helpers
      end
    end
  end
end
