# frozen_string_literal: true

module Payday

  # Basically just an invoice. Stick a ton of line items in it, add some details, and then render it out!
  class Invoice

    include Payday::Invoiceable

    attr_accessor :invoice_number, :bill_to, :ship_to, :notes, :line_items, :shipping_description,
                  :tax_description, :retention_description, :due_at, :paid_at, :refunded_at, :currency,
                  :invoice_details, :invoice_date, :qr_code

    attr_reader :tax_rate, :shipping_rate, :retention_rate

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def initialize(options = {}) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      self.invoice_number = options[:invoice_number] || nil
      self.bill_to = options[:bill_to] || nil
      self.ship_to = options[:ship_to] || nil
      self.notes = options[:notes] || nil
      self.line_items = options[:line_items] || []
      self.shipping_rate = options[:shipping_rate] || nil
      self.shipping_description = options[:shipping_description] || nil
      self.tax_rate = options[:tax_rate] || nil
      self.tax_description = options[:tax_description] || nil
      self.retention_rate = options[:retention_rate] || nil
      self.retention_description = options[:retention_description] || nil
      self.due_at = options[:due_at] || nil
      self.paid_at = options[:paid_at] || nil
      self.refunded_at = options[:refunded_at] || nil
      self.currency = options[:currency] || nil
      self.invoice_details = options[:invoice_details] || []
      self.invoice_date = options[:invoice_date] || nil
      self.qr_code = options[:qr_code] || nil
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # The tax rate that we're applying, as a BigDecimal
    def tax_rate=(value)
      value = 0 if value.to_s.blank?
      @tax_rate = BigDecimal(value.to_s)
    end

    # Shipping rate
    def shipping_rate=(value)
      value = 0 if value.to_s.blank?
      @shipping_rate = BigDecimal(value.to_s)
    end

    # Retention rate (e.g. IRPF). Applied as a percentage of the subtotal and deducted from the total.
    def retention_rate=(value)
      value = 0 if value.to_s.blank?
      @retention_rate = BigDecimal(value.to_s)
    end

    # Adds a line item
    def add_line_item(options = {})
      line_items << Payday::LineItem.new(options)
    end

  end

end
