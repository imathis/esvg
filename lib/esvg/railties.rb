module Esvg
  class Railtie < ::Rails::Railtie
    initializer "my_gem.configure_view_controller" do |app|
      ActiveSupport.on_load :action_view do
        include Esvg::Helpers
      end
    end
  end
end
