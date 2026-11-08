# frozen_string_literal: true

module Payday

  # Represents a line item in an invoice.
  #
  # +quantity+ and +price+ are written to be pretty picky, primarily because if we're not picky about what
  # values are set to them your invoice math could get pretty messed up. It's recommended that both values be
  # set to +BigDecimal+ values. Otherwise, we'll do our best to convert the set values to a +BigDecimal+.
  class LineItem

    include LineItemable

    attr_accessor :description, :display_quantity, :display_price
    attr_reader :quantity, :price, :predefined_amount

    # Initializes a new LineItem
    def initialize(options = {})
      if options[:predefined_amount]
        self.predefined_amount = options[:predefined_amount]
      else
        self.quantity = options[:quantity] || '1'
        self.display_quantity = options[:display_quantity]
        self.display_price = options[:display_price]
        self.price = options[:price] || '0.00'
      end
      self.description = options[:description] || ''
    end

    # Sets the quantity of this {LineItem}
    def quantity=(value)
      @quantity = Payday.to_decimal(value)
    end

    # Sets the price for this {LineItem}
    def price=(value)
      @price = Payday.to_decimal(value)
    end

    # Sets the predefined_amount for this {LineItem}
    def predefined_amount=(value)
      @predefined_amount = Payday.to_decimal(value)
    end

  end

end
