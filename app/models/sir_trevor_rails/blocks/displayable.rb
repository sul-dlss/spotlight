# frozen_string_literal: true

module SirTrevorRails
  module Blocks
    ##
    # Mixin for blocks that display text
    module Displayable
      def items
        item_values.select { |x| x[:display] == 'true' }
      end

      def item_ids
        items.pluck(:id)
      end

      def ordered_items
        items.sort_by { |x| x[:weight] }.pluck(:id)
      end

      private

      def item_values
        Array((item.values if item.present?))
      end
    end
  end
end
