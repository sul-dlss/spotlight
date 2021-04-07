# frozen_string_literal: true

module Spotlight
  ##
  # Exhibit authorization roles
  class Role < ActiveRecord::Base
    belongs_to :resource, polymorphic: true, optional: true
    belongs_to :user, class_name: Spotlight::Engine.config.user_class, autosave: true, optional: false

    validates :role, inclusion: { in: Spotlight::Engine.config.exhibit_roles }
    validate :user_must_be_unique, if: :user

    def user_key
      if user
        @user_key = user.user_key
      else
        @user_key
      end
    end

    # setting user key causes the user to get set
    def user_key=(key)
      @user_key = key
      self.user ||= Spotlight::Engine.user_class.find_by(user_key: key)
      self.user ||= Spotlight::Engine.user_class.invite!(email: user_key, skip_invitation: true)
      user.user_key = key
    end

    protected

    # This is just like
    #    validates :user, uniqueness: { scope: :exhibit}
    # but it puts the error message on the user_key instead of user so that the form will render correctly
    def user_must_be_unique
      errors.add(:user_key, 'already a member of this exhibit') if Spotlight::Role.where(resource: resource, user: user).where.not(id: id).any?
    end
  end
end
