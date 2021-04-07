# frozen_string_literal: true

module Spotlight
  ##
  # Exhibit navbar links
  class MainNavigation < ActiveRecord::Base
    include Spotlight::Translatables

    belongs_to :exhibit, touch: true
    default_scope { order('weight ASC') }
    scope :browse, -> { find_by(nav_type: 'browse') }
    scope :about, -> { find_by(nav_type: 'about') }
    scope :curated_features, -> { find_by(nav_type: 'curated_features') }
    scope :displayable, -> { where(display: true) }
    translates :label

    def displayable?
      display?
    end

    def label_or_default
      label.presence || default_label
    end

    def default_label(**options)
      I18n.t(:"spotlight.main_navigation.#{nav_type}", **options)
    end

    private

    ##
    # Allows us to scope translations namespace.
    def slug
      ['main_navigation', nav_type].join('.')
    end
  end
end
