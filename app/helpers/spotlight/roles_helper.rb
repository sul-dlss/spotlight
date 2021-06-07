# frozen_string_literal: true

module Spotlight
  ##
  # Exhibit roles helpers
  module RolesHelper
    ##
    # Format the available roles for a select_tag
    def roles_for_select
      Spotlight::Engine.config.exhibit_roles.index_by do |key|
        t("spotlight.role.#{key}")
      end
    end
  end
end
