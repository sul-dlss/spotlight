# frozen_string_literal: true

module Spotlight
  ##
  # Exhibit feedback form
  class ContactForm
    include ActiveModel::Model

    attr_accessor :current_exhibit, :name, :email, Spotlight::Engine.config.spambot_honeypot_email_field, :message, :current_url, :request

    validates :email, format: { with: /\A([\w.%+\-]+)@([\w\-]+\.)+(\w{2,})\z/i }

    # the spambot_honeypot_email_field field is intended to be hidden visually from the user,
    # in hope that a spam bot filling out the form will enter a value, whereas a human with a
    # browser wouldn't, allowing us to differentiate and reject likely spam messages.
    # the field must be present, since we expect real users to just submit the form as-is w/o
    # hacking what fields are present.
    validates Spotlight::Engine.config.spambot_honeypot_email_field, length: { is: 0 }

    def headers
      {
        to: to,
        subject: I18n.t(:'spotlight.contact_form.subject', application_name: application_name),
        cc: contact_emails.join(', ')
      }
    end

    private

    def application_name
      current_exhibit&.title || Spotlight::Site.instance.title || I18n.t(:'blacklight.application_name')
    end

    def to
      Spotlight::Engine.config.default_contact_email || contact_emails.first.to_s
    end

    def contact_emails
      current_exhibit&.contact_emails || []
    end
  end
end
