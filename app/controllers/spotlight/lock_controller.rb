# frozen_string_literal: true

module Spotlight
  ##
  # Locking mechanism for page-level locks
  class LockController < Spotlight::ApplicationController
    load_and_authorize_resource

    # DELETE /locks/1
    def destroy
      @lock.destroy

      render plain: '', status: :no_content
    end
  end
end
