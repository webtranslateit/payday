# frozen_string_literal: true

require 'spec_helper'

module Payday # rubocop:todo Metrics/ModuleLength

  describe InvoicePresenter do
    before { Payday::Config.default.reset }

    let(:invoice) { Invoice.new(invoice_number: 12, bill_to: "Acme\nSpain", currency: 'EUR') }
    let(:presented) { described_class.new(invoice).to_h }

    it 'carries the configured company name' do
      expect(presented[:company_name]).to eq('Awesome Corp')
    end

    it 'carries the configured company details' do
      expect(presented[:company_details]).to eq('awesomecorp@commondream.net')
    end

    it 'carries the page size' do
      expect(presented[:page_size]).to eq('LETTER')
    end

    it 'passes bill_to through as a literal string' do
      expect(presented[:bill_to]).to eq("Acme\nSpain")
    end

    it 'omits ship_to when absent' do
      expect(presented[:ship_to]).to be_nil
    end

    it 'has no stamp for an open invoice' do
      expect(presented[:stamp]).to be_nil
    end

    it 'stamps a paid invoice' do
      invoice.paid_at = Date.new(2026, 1, 1)
      expect(presented[:stamp]).to eq('PAID')
    end

    it 'stamps a refunded invoice' do
      invoice.refunded_at = Date.new(2026, 1, 1)
      expect(presented[:stamp]).to eq('REFUNDED')
    end

    it 'stamps an overdue invoice' do
      invoice.due_at = Date.new(2020, 1, 1)
      expect(presented[:stamp]).to eq('OVERDUE')
    end

    it 'labels an unpaid invoice with the invoice number' do
      expect(presented[:details]).to include(['Invoice number:', '12'])
    end

    it 'labels a paid invoice with the receipt number' do
      invoice.paid_at = Date.new(2026, 1, 1)
      expect(presented[:details]).to include(['Receipt number:', '12'])
    end

    it 'formats the due date with the configured format' do
      invoice.due_at = Date.new(2026, 3, 2)
      expect(presented[:details]).to include(['Due Date:', 'March  2, 2026'])
    end

    it 'appends custom invoice details' do
      invoice.invoice_details = [['E-mail:', 'finance@example.com']]
      expect(presented[:details]).to include(['E-mail:', 'finance@example.com'])
    end

    it 'exposes the translated table labels' do
      expect(presented[:labels]).to include(bill_to: 'Bill To', description: 'Description')
    end

    describe 'line items' do
      before { invoice.add_line_item(price: 10, quantity: 2, description: 'Widget') }

      it 'formats price, quantity and amount in the invoice currency' do
        expect(presented[:line_items].first).to eq(
          {description: [{text: 'Widget'}], price: '€10,00', quantity: '2.0', amount: '€20,00'}
        )
      end

      it 'blanks price and quantity for a predefined amount' do
        invoice.line_items.clear
        invoice.add_line_item(predefined_amount: 5, description: 'Overage')
        expect(presented[:line_items].first).to eq(
          {description: [{text: 'Overage'}], price: '', quantity: '', amount: '€5,00'}
        )
      end

      it 'converts markup in the description into runs' do
        invoice.line_items.clear
        invoice.add_line_item(price: 1, quantity: 1, description: "W<color rgb='777777'>x</color>")
        expect(presented[:line_items].first[:description]).to eq(
          [{text: 'W'}, {text: 'x', color: '777777'}]
        )
      end
    end

    describe 'totals' do
      before { invoice.add_line_item(price: 100, quantity: 1, description: 'Plan') }

      it 'always lists subtotal, tax and total' do
        expect(presented[:totals].map(&:first)).to eq(['Subtotal:', 'Tax:', 'Total:'])
      end

      it 'uses the custom tax description when given' do
        invoice.tax_description = 'VAT (21%)'
        expect(presented[:totals].map(&:first)).to include('VAT (21%)')
      end

      it 'includes shipping only when the rate is positive' do
        invoice.shipping_rate = 5
        expect(presented[:totals]).to include(['Shipping:', '€5,00', false])
      end

      it 'renders retention as a negative amount' do
        invoice.retention_rate = 10
        expect(presented[:totals]).to include(['Retention:', '€-10,00', false])
      end

      it 'emphasises the total row' do
        expect(presented[:totals].last).to eq(['Total:', '€100,00', true])
      end
    end

    describe 'notes' do
      it 'is nil when absent' do
        expect(presented[:notes]).to be_nil
      end

      it 'is converted into runs' do
        invoice.notes = '<b>Thanks</b>'
        expect(presented[:notes]).to eq([{text: 'Thanks', bold: true}])
      end
    end

    describe 'qr code' do
      it 'is nil when blank' do
        expect(presented[:qr_code]).to be_nil
      end

      it 'passes the payload through' do
        invoice.qr_code = 'https://aeat.example/verify?id=1'
        expect(presented[:qr_code]).to eq('https://aeat.example/verify?id=1')
      end
    end
  end

end
