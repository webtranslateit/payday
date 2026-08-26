# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe InvoicePresenter do
    before { Payday::Config.default.reset }

    let(:invoice) { Invoice.new(invoice_number: 12, bill_to: "Acme\nSpain", currency: 'EUR') }
    let(:presented) { described_class.new(invoice).to_h }

    it 'carries the configured company identity' do
      expect(presented[:company_name]).to eq('Awesome Corp')
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
  end

end
