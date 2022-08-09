# frozen_string_literal: true

# Include this module into your line item implementation to make sure that Payday stays happy
# with it, or just make sure that your line item implements the amount method.
module Payday
  module LineItemable # rubocop:todo Style/Documentation
    # Returns the total amount for this {LineItemable}, or +price * quantity+
    def amount
      return predefined_amount if predefined_amount

      price * quantity
    end
  end
end
