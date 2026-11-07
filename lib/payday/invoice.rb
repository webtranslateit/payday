# frozen_string_literal: true

module Payday

  # Basically just an invoice. Stick a ton of line items in it, add some details, and then render it out!
  class Invoice

    include Payday::Invoiceable

    attr_accessor :invoice_number, :bill_to, :ship_to, :notes, :line_items, :shipping_description,
                  :tax_description, :retention_description, :due_at, :paid_at, :refunded_at, :currency,
                  :invoice_details, :invoice_date, :qr_code

    attr_reader :tax_rate, :shipping_rate, :retention_rate

    # Options assigned as given; a missing one is nil, which the rate setters turn into 0.
    OPTIONS = %i[invoice_number bill_to ship_to notes shipping_rate shipping_description tax_rate
                 tax_description retention_rate retention_description due_at paid_at refunded_at
                 currency invoice_date qr_code].freeze

    def initialize(options = {})
      OPTIONS.each { |name| public_send(:"#{name}=", options[name]) }
      self.line_items = options[:line_items] || []
      self.invoice_details = options[:invoice_details] || []
    end

    # The tax rate that we're applying, as a BigDecimal
    def tax_rate=(value)
      @tax_rate = to_rate(value)
    end

    # Shipping rate
    def shipping_rate=(value)
      @shipping_rate = to_rate(value)
    end

    # Retention rate (e.g. IRPF). Applied as a percentage of the subtotal and deducted from the total.
    def retention_rate=(value)
      @retention_rate = to_rate(value)
    end

    # Adds a line item
    def add_line_item(options = {})
      line_items << Payday::LineItem.new(options)
    end

    private

    # A blank rate (nil, "", "  ") is 0.
    def to_rate(value)
      BigDecimal(value.to_s.presence || 0)
    end

  end

end
