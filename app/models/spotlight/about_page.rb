# frozen_string_literal: true

module Spotlight
  ##
  # About pages
  class AboutPage < Spotlight::Page
    extend FriendlyId
    friendly_id :title, use: %i[slugged scoped finders history], scope: %i[exhibit locale type]
  end
end
