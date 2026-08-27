# frozen_string_literal: true

module Payday

  # Configuration for Payday. This is a singleton, so to set the company_name you would call
  # Payday::Config.default.company_name = "Awesome Corp".
  class Config

    attr_accessor :invoice_logo, :company_name, :company_details, :date_format, :currency

    # Sets the page size to use. Accepts the names Payday has always taken, 'LETTER', 'A4'
    # and 'LEGAL', which the template maps onto the equivalent Typst paper. Anything else
    # falls back to A4.
    attr_accessor :page_size

    # Returns the default configuration instance
    def self.default
      @default ||= new
    end

    # Internal: Resets a config object back to its default settings.
    #
    # Primarily intended for use in our tests.
    def reset
      # TODO: Move into specs and make minimal configuration required (company name / details)
      self.invoice_logo = File.expand_path('assets/default_logo.png', __dir__)
      self.company_name = 'Awesome Corp'
      self.company_details = 'awesomecorp@commondream.net'
      self.date_format = '%B %e, %Y'
      self.currency = 'USD'
      self.page_size = 'LETTER'
    end

    # Internal: Contruct a new config object.
    def initialize
      reset
    end

  end

end
