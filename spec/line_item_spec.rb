require 'spec_helper'

module Payday
  describe LineItem do
    it 'is able to be initialized with a price' do
      li = described_class.new(price: BigDecimal('20'))
      expect(li.price).to eq(BigDecimal('20'))
    end

    it 'is able to be initialized with a quantity' do
      li = described_class.new(quantity: 30)
      expect(li.quantity).to eq(BigDecimal('30'))
    end

    it 'is able to be initialized with a description' do
      li = described_class.new(description: '12 Pairs of Pants')
      expect(li.description).to eq('12 Pairs of Pants')
    end

    it 'returns the correct amount' do
      li = described_class.new(price: 10, quantity: 12)
      expect(li.amount).to eq(BigDecimal('120'))
    end

    it 'returns the correct amount when using a predefined amount' do
      li = described_class.new(predefined_amount: 244)
      expect(li.amount).to eq(BigDecimal('244'))
    end
  end
end
