# Typst PDF Renderer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Payday's Prawn/prawn-table/prawn-svg PDF renderer with Typst, removing the dead `prawn-table` dependency without adopting an AGPL-licensed library.

**Architecture:** `PdfRenderer` stops drawing imperatively and becomes a thin orchestrator. A new `InvoicePresenter` converts any `Invoiceable` into a plain Hash (all `I18n`, `Money` and date formatting happen in Ruby); a new `Markup` class converts Payday's legacy Prawn `inline_format` strings into structured styled runs; a new `lib/payday/templates/invoice.typ` owns the layout. Data reaches the template only through `sys.inputs` JSON, where Typst treats every string as literal text — this is what makes customer-controlled fields injection-proof.

**Tech Stack:** Ruby >= 3.2, `typst` gem (Apache-2.0, Rust binding, precompiled native gems), RSpec, Money, I18n.

---

## Why this migration

`prawn-table` has not had a release since **2015-07-16** (11 years) and carries 68 open issues, yet the current renderer depends on it heavily (`make_table`, `table`, `Prawn::Table::Cell::Text`, `natural_column_widths`). The `matrix` gem already sitting in the `Gemfile` exists solely to keep prawn-table booting on Ruby >= 3.1.

HexaPDF was evaluated and rejected: it is **AGPL-3.0 or commercial** (EUR 600/host/year, EUR 300/VM/year), and it has **no SVG support at all**, which would break the production logo.

Typst is Apache-2.0, renders SVG natively, and ships precompiled gems for `arm64-darwin` and `x86_64-linux` — exactly the two platforms in `webtranslateit.com`'s `Gemfile.lock`.

## Evidence from the spike

All of the following were executed and verified before this plan was written. Do not re-litigate them.

| Question | Result |
| --- | --- |
| Precompiled gem installs on Ruby 4.0.6, no Rust toolchain | Yes — `typst 0.15.1.5 (arm64-darwin)` |
| SVG logo renders | Yes — `spec/assets/tiger.svg` rendered as vector |
| NotoSans TTFs load from memory | Yes — via `fonts:` map, accents (`Málaga`, `éàü`) correct |
| Rotated `PAID` stamp | Yes — `rotate(15deg, ...)` |
| Table: alternating fill, per-side border colours, right-aligned numerics | Yes — via `fill: (x, y) => ...` and `stroke: (x, y) => (...)` |
| Table splits across pages with repeating header | Yes — 40 line items produced `/Count 3` |
| Byte-for-byte reproducible output | **Yes** — two runs `cmp`-identical with `#set document(date: none)` |
| Customer data with `#`, `*`, `_`, `[`, `$`, `@` cannot inject | **Yes** — `#strong[INJECTED]` rendered as literal text |
| Styled runs (bold, size, colour, mailto link) reproduce `inline_format` | Yes |

The reproducibility result matters most: it means `spec/support/asset_matchers.rb` and the `match_binary_asset` golden-file strategy **survive this migration**. They would not have survived HexaPDF.

## Security rule (non-negotiable)

**Never build the `.typ` source by interpolating invoice data into it, and never call Typst's `eval()` on customer-controlled strings.**

All data crosses into the template as JSON through `sys_inputs`. Typst inserts JSON string values as literal text, never as markup. `Markup` converts operator-controlled locale markup into *structured runs* rather than Typst source, so there is no path from a customer's billing address to executable Typst.

## File structure

| File | Responsibility |
| --- | --- |
| `lib/payday/templates/invoice.typ` (create) | The entire page layout |
| `lib/payday/invoice_presenter.rb` (create) | `Invoiceable` -> Hash; owns all `I18n`, `Money`, date formatting |
| `lib/payday/markup.rb` (create) | Prawn `inline_format` string -> array of styled runs |
| `lib/payday/pdf_renderer.rb` (rewrite) | Orchestrates presenter + assets + Typst compile |
| `lib/payday.rb` (modify) | Swap `prawn` requires for `typst` |
| `payday.gemspec` (modify) | Drop 3 prawn deps, add `typst` |
| `spec/invoice_presenter_spec.rb` (create) | Presenter unit tests |
| `spec/markup_spec.rb` (create) | Markup unit tests |
| `spec/assets/*.pdf` (regenerate) | Golden files |

Public API does not change: `Invoiceable#render_pdf`, `#render_pdf_to_file`, `PdfRenderer.render`, `PdfRenderer.render_to_file` and every `Payday::Config` accessor keep their current signatures.

---

## Task 1: Add the Typst dependency

**Files:**
- Modify: `payday.gemspec:16-23`
- Modify: `Gemfile`

- [ ] **Step 1: Add the gem to the gemspec**

In `payday.gemspec`, add alongside the existing dependencies (leave the prawn ones in place for now — they are removed in Task 8, so the suite keeps passing throughout):

```ruby
  s.add_dependency 'typst', '~> 0.15'
```

- [ ] **Step 2: Install and confirm the precompiled gem resolves**

Run: `cd /Users/edouard/code/payday && bundle install`
Expected: a line reading `Installing typst 0.15.1.5 (arm64-darwin)`. If it instead says `Installing typst 0.15.1.5` with a compile step, the native gem did not resolve — stop and investigate before continuing.

- [ ] **Step 3: Confirm it loads and compiles**

Run:
```bash
cd /Users/edouard/code/payday && bundle exec ruby -e 'require "typst"; puts Typst(body: "= Hi").compile(:pdf).bytes.flatten.pack("C*").bytesize'
```
Expected: a number greater than 1000.

- [ ] **Step 4: Commit**

```bash
git add payday.gemspec Gemfile.lock
git commit -m "build: add the typst gem alongside prawn"
```

---

## Task 2: Convert Prawn inline markup into styled runs

Payday historically passed `notes` and line item descriptions to Prawn with `inline_format: true`, so consumers have strings containing `<b>`, `<font size='12'>`, `<color rgb='777777'>`, `<link href='...'>` and `<br/>`. Typst has no such parser. Convert them in Ruby into structured runs the template can style.

**Files:**
- Create: `lib/payday/markup.rb`
- Test: `spec/markup_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/markup_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe Markup do
    describe '.to_runs' do
      it 'returns a single plain run for unmarked text' do
        expect(described_class.to_runs('Hello')).to eq([{text: 'Hello'}])
      end

      it 'returns nil for nil' do
        expect(described_class.to_runs(nil)).to be_nil
      end

      it 'marks bold segments' do
        expect(described_class.to_runs('a <b>b</b> c')).to eq(
          [{text: 'a '}, {text: 'b', bold: true}, {text: ' c'}]
        )
      end

      it 'extracts font size' do
        expect(described_class.to_runs("<font size='12'>big</font>")).to eq(
          [{text: 'big', size: 12}]
        )
      end

      it 'extracts colour' do
        expect(described_class.to_runs("<color rgb='777777'>grey</color>")).to eq(
          [{text: 'grey', color: '777777'}]
        )
      end

      it 'extracts links' do
        expect(described_class.to_runs("<link href='mailto:a@b.c'>mail</link>")).to eq(
          [{text: 'mail', link: 'mailto:a@b.c'}]
        )
      end

      it 'handles nested tags' do
        expect(described_class.to_runs("<font size='12'><b>Thanks!</b></font>")).to eq(
          [{text: 'Thanks!', bold: true, size: 12}]
        )
      end

      it 'converts br tags to newlines' do
        expect(described_class.to_runs('a<br/>b')).to eq([{text: "a\nb"}])
      end

      it 'leaves Typst metacharacters untouched' do
        expect(described_class.to_runs('#strong[x] *y* $z$')).to eq(
          [{text: '#strong[x] *y* $z$'}]
        )
      end
    end
  end

end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/markup_spec.rb`
Expected: FAIL — `uninitialized constant Payday::Markup`

- [ ] **Step 3: Write the implementation**

Create `lib/payday/markup.rb`:

```ruby
# frozen_string_literal: true

module Payday

  # Converts the Prawn `inline_format` markup Payday used to accept in notes and line item
  # descriptions into structured runs that the Typst template can style.
  #
  # We deliberately produce data, not Typst source: the template renders each run's `text`
  # as a literal string, so a customer-supplied description can never become Typst code.
  class Markup

    TAG = %r{<(?<name>b|i|font|color|link)(?<attrs>[^>]*)>(?<body>.*?)</\k<name>>}m

    def self.to_runs(text)
      return nil if text.nil?

      runs(text.to_s.gsub(%r{<br\s*/?>}, "\n"), {})
    end

    def self.runs(text, style)
      result = []
      last = 0

      text.to_enum(:scan, TAG).each do
        match = Regexp.last_match
        result << style.merge(text: match.pre_match[last..]) if match.begin(0) > last
        result.concat(runs(match[:body], style.merge(style_for(match[:name], match[:attrs]))))
        last = match.end(0)
      end

      result << style.merge(text: text[last..]) unless last == text.length
      result
    end
    private_class_method :runs

    def self.style_for(name, attrs)
      case name
      when 'b' then {bold: true}
      when 'i' then {italic: true}
      when 'font' then {size: attrs[/size=['"](\d+)['"]/, 1].to_i}
      when 'color' then {color: attrs[/rgb=['"]#?(\h{6})['"]/, 1]}
      when 'link' then {link: attrs[/href=['"](.*?)['"]/, 1]}
      end
    end
    private_class_method :style_for

  end

end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/markup_spec.rb`
Expected: 9 examples, 0 failures. If the nesting or pre-match slicing is off, fix `runs` — the tests pin the exact contract.

- [ ] **Step 5: Commit**

```bash
git add lib/payday/markup.rb spec/markup_spec.rb
git commit -m "feat: convert prawn inline markup into styled runs"
```

---

## Task 3: InvoicePresenter — header, stamp and details

All `I18n`, `Money` and date formatting moves out of the renderer and into a presenter that turns any `Invoiceable` into a plain Hash. Nothing below this line knows what a PDF is.

**Files:**
- Create: `lib/payday/invoice_presenter.rb`
- Test: `spec/invoice_presenter_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/invoice_presenter_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe InvoicePresenter do
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

    it 'labels an unpaid invoice with the invoice number' do
      expect(presented[:details]).to include(['Invoice #:', '12'])
    end

    it 'labels a paid invoice with the receipt number' do
      invoice.paid_at = Date.new(2026, 1, 1)
      expect(presented[:details]).to include(['Receipt #:', '12'])
    end

    it 'formats the due date with the configured format' do
      invoice.due_at = Date.new(2026, 3, 2)
      expect(presented[:details]).to include(['Due Date:', 'March  2, 2026'])
    end

    it 'appends custom invoice details' do
      invoice.invoice_details = [['E-mail:', 'finance@example.com']]
      expect(presented[:details]).to include(['E-mail:', 'finance@example.com'])
    end
  end

end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/invoice_presenter_spec.rb`
Expected: FAIL — `uninitialized constant Payday::InvoicePresenter`

- [ ] **Step 3: Write the implementation**

Create `lib/payday/invoice_presenter.rb`:

```ruby
# frozen_string_literal: true

module Payday

  # Turns an Invoiceable into the plain Hash the Typst template consumes.
  #
  # Every currency, date and translation decision happens here so that the template stays
  # a pure layout concern and receives nothing but literal strings.
  class InvoicePresenter

    def initialize(invoice)
      @invoice = invoice
    end

    def to_h
      {
        page_size: setting(:page_size),
        company_name: setting(:company_name).strip,
        company_details: setting(:company_details),
        stamp: stamp,
        bill_to: @invoice.bill_to,
        ship_to: (@invoice.ship_to if @invoice.respond_to?(:ship_to)),
        labels: labels,
        details: details
      }
    end

    def stamp
      return t('status.refunded', 'REFUNDED') if @invoice.refunded?
      return t('status.paid', 'PAID') if @invoice.paid?

      t('status.overdue', 'OVERDUE') if @invoice.overdue?
    end

    def details
      rows = []
      rows << [number_label, @invoice.invoice_number.to_s] if @invoice.invoice_number
      rows << [t('invoice.due_date', 'Due Date:'), date(@invoice.due_at)] if @invoice.due_at
      rows << [t('invoice.paid_date', 'Paid Date:'), date(@invoice.paid_at)] if @invoice.paid_at
      @invoice.each_detail { |key, value| rows << [key.to_s, value.to_s] }
      rows
    end

    def labels
      {
        bill_to: t('invoice.bill_to', 'Bill To'),
        ship_to: t('invoice.ship_to', 'Ship To'),
        notes: t('invoice.notes', 'Notes'),
        description: t('line_item.description', 'Description'),
        unit_price: t('line_item.unit_price', 'Unit Price'),
        quantity: t('line_item.quantity', 'Quantity'),
        amount: t('line_item.amount', 'Amount')
      }
    end

    private

    def number_label
      return t('invoice.receipt_no', 'Receipt #:') if @invoice.paid?

      t('invoice.invoice_no', 'Invoice #:')
    end

    def date(value)
      return value.to_s unless value.is_a?(Date) || value.is_a?(Time)

      value.strftime(Payday::Config.default.date_format)
    end

    def t(key, default)
      I18n.t("payday.#{key}", default: default)
    end

    def setting(property)
      return @invoice.send(property) if @invoice.respond_to?(property) && @invoice.send(property)

      Payday::Config.default.send(property)
    end

  end

end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/invoice_presenter_spec.rb`
Expected: 11 examples, 0 failures.

Note: `'March  2, 2026'` contains two spaces — `%e` in the configured `date_format` space-pads single digits. Keep it; it matches current output.

- [ ] **Step 5: Commit**

```bash
git add lib/payday/invoice_presenter.rb spec/invoice_presenter_spec.rb
git commit -m "feat: add an invoice presenter for the typst template"
```

---

## Task 4: InvoicePresenter — line items, totals, notes and QR

**Files:**
- Modify: `lib/payday/invoice_presenter.rb`
- Modify: `spec/invoice_presenter_spec.rb`

- [ ] **Step 1: Write the failing test**

Append inside the `describe InvoicePresenter do` block in `spec/invoice_presenter_spec.rb`:

```ruby
    describe 'line items' do
      before { invoice.add_line_item(price: 10, quantity: 2, description: 'Widget') }

      it 'formats price, quantity and amount in the invoice currency' do
        expect(presented[:line_items].first).to eq(
          {description: [{text: 'Widget'}], price: '€10.00', quantity: '2.0', amount: '€20.00'}
        )
      end

      it 'blanks price and quantity for a predefined amount' do
        invoice.line_items.clear
        invoice.add_line_item(predefined_amount: 5, description: 'Overage')
        expect(presented[:line_items].first).to eq(
          {description: [{text: 'Overage'}], price: '', quantity: '', amount: '€5.00'}
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
        expect(presented[:totals]).to include(['Shipping:', '€5.00', false])
      end

      it 'renders retention as a negative amount' do
        invoice.retention_rate = 10
        expect(presented[:totals]).to include(['Retention:', '-€10.00', false])
      end

      it 'emphasises the total row' do
        expect(presented[:totals].last).to eq(['Total:', '€100.00', true])
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/invoice_presenter_spec.rb`
Expected: FAIL — `presented[:line_items]` is `nil`.

- [ ] **Step 3: Write the implementation**

In `lib/payday/invoice_presenter.rb`, add these four keys to the Hash returned by `to_h`:

```ruby
        line_items: line_items,
        totals: totals,
        notes: Markup.to_runs(@invoice.notes),
        qr_code: (@invoice.qr_code.to_s if @invoice.respond_to?(:qr_code) && @invoice.qr_code.to_s.strip.present?)
```

Then add these public methods above `private`:

```ruby
    def line_items
      @invoice.line_items.map { |line| line_item(line) }
    end

    def totals
      rows = [[t('invoice.subtotal', 'Subtotal:'), money(@invoice.subtotal), false],
              [tax_label, money(@invoice.tax), false]]
      rows << [shipping_label, money(@invoice.shipping), false] if @invoice.shipping_rate.positive?
      rows << [retention_label, money(-@invoice.retention), false] if @invoice.retention_rate.positive?
      rows << [t('invoice.total', 'Total:'), money(@invoice.total), true]
    end
```

And these private helpers:

```ruby
    def line_item(line)
      return predefined_line_item(line) if line.predefined_amount

      {description: Markup.to_runs(line.description),
       price: line.display_price || money(line.price),
       quantity: line.display_quantity || BigDecimal(line.quantity.to_s).to_s('F'),
       amount: money(line.amount)}
    end

    def predefined_line_item(line)
      {description: Markup.to_runs(line.description), price: '', quantity: '',
       amount: money(line.predefined_amount)}
    end

    def tax_label
      @invoice.tax_description || t('invoice.tax', 'Tax:')
    end

    def shipping_label
      @invoice.shipping_description || t('invoice.shipping', 'Shipping:')
    end

    def retention_label
      @invoice.retention_description || t('invoice.retention', 'Retention:')
    end

    def money(number)
      PdfRenderer.number_to_currency(number, @invoice)
    end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/invoice_presenter_spec.rb`
Expected: 21 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/payday/invoice_presenter.rb spec/invoice_presenter_spec.rb
git commit -m "feat: present line items, totals, notes and qr data"
```

---

## Task 5: Write the Typst template

**Files:**
- Create: `lib/payday/templates/invoice.typ`

- [ ] **Step 1: Write the template**

Create `lib/payday/templates/invoice.typ`:

```typst
#let d = json(bytes(sys.inputs.invoice))

// Prawn page-size names mapped onto Typst paper names.
#let papers = ("LETTER": "us-letter", "A4": "a4", "LEGAL": "us-legal")

#set document(title: "Invoice", date: none)
#set page(
  paper: papers.at(d.page_size, default: "a4"),
  margin: 2cm,
  numbering: none,
)
#set text(font: "Noto Sans", size: 10pt)

// Renders styled runs produced by Payday::Markup. Every `text` value is inserted as a
// literal string, so customer-supplied content can never become Typst markup.
#let render-runs(runs) = {
  if runs == none { return }
  for r in runs {
    let body = text(
      size: if "size" in r { r.size * 1pt } else { 1em },
      fill: if "color" in r { rgb(r.color) } else { black },
      weight: if r.at("bold", default: false) { "bold" } else { "regular" },
      style: if r.at("italic", default: false) { "italic" } else { "normal" },
      r.text,
    )
    if "link" in r { link(r.link, body) } else { body }
  }
}

// --- logo and company identity -------------------------------------------------
#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  if d.logo != none {
    image(d.logo.name, width: d.logo.width * 1pt, height: d.logo.height * 1pt, fit: "contain")
  },
  [
    #text(weight: "bold", size: 12pt)[#d.company_name] \
    #d.company_details
  ],
)

// --- status stamp ---------------------------------------------------------------
#if d.stamp != none {
  place(center, dy: -30pt, rotate(15deg,
    text(fill: rgb("cc0000"), size: 25pt, weight: "bold")[#d.stamp]))
}

#v(20pt)

// --- bill to / ship to ----------------------------------------------------------
#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  [#text(weight: "bold")[#d.labels.bill_to] \ #d.bill_to],
  if d.ship_to != none [#text(weight: "bold")[#d.labels.ship_to] \ #d.ship_to],
)

#v(20pt)

// --- invoice details ------------------------------------------------------------
#if d.details.len() > 0 {
  table(
    columns: 2,
    stroke: none,
    inset: (x: 0pt, y: 1pt),
    column-gutter: 10pt,
    align: (left, right),
    ..d.details.map(row => (
      text(weight: "bold")[#row.at(0)],
      text(weight: "bold")[#row.at(1)],
    )).flatten()
  )
}

#v(20pt)

// --- line items -----------------------------------------------------------------
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  inset: (x: 10pt, y: 5pt),
  stroke: (x, y) => (
    left: none,
    right: none,
    top: 0.5pt + rgb("F6F9FC"),
    bottom: 0.5pt + rgb("BCC6D0"),
  ),
  fill: (x, y) => if y == 0 { white } else if calc.odd(y) { rgb("F6F9FC") } else { white },
  table.header(
    text(weight: "bold")[#d.labels.description],
    text(weight: "bold")[#d.labels.unit_price],
    text(weight: "bold")[#d.labels.quantity],
    text(weight: "bold")[#d.labels.amount],
  ),
  ..d.line_items.map(li => (
    render-runs(li.description), [#li.price], [#li.quantity], [#li.amount],
  )).flatten()
)

#v(10pt)

// --- totals ---------------------------------------------------------------------
#align(right, table(
  columns: 2,
  stroke: none,
  inset: (x: 4pt, y: 2pt),
  align: (left, right),
  ..d.totals.map(row => {
    let size = if row.at(2) { 12pt } else { 10pt }
    (text(weight: "bold", size: size)[#row.at(0)], text(size: size)[#row.at(1)])
  }).flatten()
))

// --- notes ----------------------------------------------------------------------
#if d.notes != none {
  v(30pt)
  text(weight: "bold")[#d.labels.notes]
  v(3pt)
  line(length: 100%, stroke: 0.5pt + rgb("cccccc"))
  v(10pt)
  render-runs(d.notes)
}

// --- QR code --------------------------------------------------------------------
#if d.qr_code != none {
  v(10pt)
  image("qr.png", width: 100pt)
}

// --- page numbers, only when the invoice runs to more than one page ---------------
#context if counter(page).final().first() > 1 {
  set page(numbering: "1 / 1")
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/payday/templates/invoice.typ
git commit -m "feat: add the typst invoice template"
```

---

## Task 6: Rewrite PdfRenderer

The renderer keeps its public methods and loses everything else. It now assembles the in-memory asset maps (fonts, logo, QR) and hands them to Typst with the presented Hash.

**Files:**
- Rewrite: `lib/payday/pdf_renderer.rb`
- Modify: `lib/payday.rb:12-15`

- [ ] **Step 1: Swap the requires**

In `lib/payday.rb`, replace these three lines:

```ruby
require 'prawn'
require 'prawn/table'
require 'prawn-svg'
```

with:

```ruby
require 'typst'
```

- [ ] **Step 2: Rewrite the renderer**

Replace the entire contents of `lib/payday/pdf_renderer.rb` with:

```ruby
# frozen_string_literal: true

module Payday

  # Renders an invoice to PDF by feeding a presented Hash to the Typst template.
  #
  # Invoice data crosses into the template only as `sys_inputs` JSON, where Typst treats
  # every string as literal text. Never interpolate invoice data into the template source.
  class PdfRenderer

    TEMPLATE = File.expand_path('templates/invoice.typ', __dir__)
    FONT_DIR = File.expand_path('../../fonts', __dir__)
    FONTS = %w[NotoSans-Regular.ttf NotoSans-Bold.ttf].freeze

    def self.render_to_file(invoice, path)
      File.binwrite(path, render(invoice))
    end

    def self.render(invoice)
      new(invoice).render
    end

    def initialize(invoice)
      @invoice = invoice
      @dependencies = {}
    end

    def render
      data = InvoicePresenter.new(@invoice).to_h.merge(logo: logo)
      data[:qr_code] = qr_code(data[:qr_code])

      Typst(body: File.read(TEMPLATE), dependencies: @dependencies, fonts: fonts,
            sys_inputs: {'invoice' => data.to_json})
        .compile(:pdf).bytes.flatten.pack('C*')
    end

    private

    def fonts
      FONTS.to_h { |name| [name, File.binread(File.join(FONT_DIR, name))] }
    end

    # Config#invoice_logo is either a path or a {filename:, size: "WxH"} Hash.
    def logo
      setting = Payday::Config.default.invoice_logo
      setting = @invoice.invoice_logo if @invoice.respond_to?(:invoice_logo) && @invoice.invoice_logo
      return nil if setting.nil?

      path, width, height = logo_parts(setting)
      name = "logo#{File.extname(path)}"
      @dependencies[name] = File.binread(path.to_s)
      {name: name, width: width, height: height}
    end

    def logo_parts(setting)
      return [setting, 200, 50] unless setting.is_a?(Hash)

      width, height = setting[:size].to_s.split('x').map(&:to_f)
      [setting[:filename], width, height]
    end

    def qr_code(data)
      return nil if data.nil?

      require 'rqrcode'
      @dependencies['qr.png'] = RQRCode::QRCode.new(data).as_png(size: 200).to_s
      data
    end

    # Kept for backwards compatibility: this was public API and is covered by
    # spec/pdf_renderer_spec.rb.
    def self.number_to_currency(number, invoice)
      Money.locale_backend = :currency
      Money.rounding_mode = BigDecimal::ROUND_HALF_UP
      currency = Money::Currency.wrap(
        (invoice.currency if invoice.respond_to?(:currency) && invoice.currency) ||
        Payday::Config.default.currency
      )
      number *= currency.subunit_to_unit
      number = number.round unless Money.default_infinite_precision
      Money.new(number, currency).format
    end

  end

end
```

- [ ] **Step 3: Run the existing renderer spec**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/pdf_renderer_spec.rb`
Expected: 1 example, 0 failures — `number_to_currency` still returns `'$20.00'`.

- [ ] **Step 4: Confirm an invoice renders end to end**

Run:
```bash
cd /Users/edouard/code/payday && bundle exec ruby -Ilib -e '
require "payday"
Payday::Config.default.reset
i = Payday::Invoice.new(invoice_number: 1, bill_to: "Acme\nSpain", notes: "<b>Thanks</b>")
i.add_line_item(price: 10, quantity: 2, description: "Widget")
i.render_pdf_to_file("tmp/smoke.pdf")
puts File.size("tmp/smoke.pdf")'
```
Expected: a byte count over 20000 and no exception. Open `tmp/smoke.pdf` and confirm it looks like an invoice.

- [ ] **Step 5: Commit**

```bash
git add lib/payday/pdf_renderer.rb lib/payday.rb
git commit -m "feat: render invoices with typst instead of prawn"
```

---

## Task 7: Prove determinism and regenerate the golden files

`spec/support/asset_matchers.rb` compares rendered output byte-for-byte against files in `spec/assets`. The spike confirmed Typst output is reproducible when `#set document(date: none)` is set (it is, in Task 5), so this strategy survives — but every golden file must be regenerated, and the regeneration must be reviewed by eye, not rubber-stamped.

**Files:**
- Modify: `spec/invoice_spec.rb`
- Regenerate: `spec/assets/testing.pdf`, `testing_es.pdf`, `testing_predefined_amount.pdf`, `svg.pdf`, `example_invoice_with_qr.pdf`

- [ ] **Step 1: Add a determinism test**

Append to `spec/invoice_spec.rb` inside the `describe 'rendering' do` block:

```ruby
      it 'renders byte-identical output across runs' do
        invoice = Payday::Invoice.new(invoice_number: 7, bill_to: "Acme\nSpain")
        invoice.add_line_item(price: 10, quantity: 1, description: 'Widget')

        expect(invoice.render_pdf).to eq(invoice.render_pdf)
      end
```

- [ ] **Step 2: Run it**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/invoice_spec.rb -e 'byte-identical'`
Expected: PASS. If it fails, `#set document(date: none)` is missing from the template — fix that before continuing, because every golden file below depends on it.

- [ ] **Step 3: Watch the golden-file specs fail**

Run: `cd /Users/edouard/code/payday && bundle exec rspec spec/invoice_spec.rb`
Expected: 4 failures, each naming a file under `tmp/rendered_output/`. This is correct — the layout engine changed.

- [ ] **Step 4: Review each new render by eye before accepting it**

For each of the four files, open the old and new side by side:

```bash
cd /Users/edouard/code/payday
open spec/assets/testing.pdf tmp/rendered_output/testing.pdf
```

Check, on every one: the logo is the right size and not stretched; the stamp sits over the header the way it used to; bill-to and ship-to are on the same line; numeric columns are right-aligned; the totals block is right-aligned with an emphasised total; accented characters render; the notes rule and QR code appear.

Do not proceed until each render is judged correct. This step is the entire regression net for this migration.

- [ ] **Step 5: Accept the reviewed renders as the new goldens**

```bash
cd /Users/edouard/code/payday && cp tmp/rendered_output/*.pdf spec/assets/
bundle exec rspec spec/invoice_spec.rb
```
Expected: 0 failures.

- [ ] **Step 6: Commit**

```bash
git add spec/assets spec/invoice_spec.rb
git commit -m "test: regenerate golden invoices for the typst renderer"
```

---

## Task 8: Drop the Prawn dependencies

**Files:**
- Modify: `payday.gemspec:16-23`
- Modify: `Gemfile`

- [ ] **Step 1: Remove the gemspec entries**

Delete these three lines from `payday.gemspec`:

```ruby
  s.add_dependency 'prawn', '~> 2.4', '< 3'
  s.add_dependency 'prawn-svg', '~> 0.32', '< 1'
  s.add_dependency 'prawn-table', '~> 0.2', '< 1'
```

- [ ] **Step 2: Remove the prawn-table workaround**

Delete `gem 'matrix'` from `Gemfile`. It exists only because prawn-table needs it on Ruby >= 3.1.

- [ ] **Step 3: Verify prawn is gone and the suite still passes**

```bash
cd /Users/edouard/code/payday && bundle install
grep -rn "prawn\|Prawn" lib/ spec/ --include=*.rb
timeout -s KILL 600 bundle exec rspec 2>&1 | tail -20
```
Expected: the grep returns nothing, and the suite is green. `bundle list | grep prawn` should also come back empty.

- [ ] **Step 4: Bump the version**

In `payday.gemspec`, set `s.version = '2.0.0'`. This is a breaking change: consumers passing Prawn-only options or relying on Prawn being loaded will need to adapt.

- [ ] **Step 5: Commit**

```bash
git add payday.gemspec Gemfile Gemfile.lock
git commit -m "build!: drop prawn, prawn-table and prawn-svg"
```

---

## Task 9: Update the consuming app (webtranslateit.com)

This migration is a two-repo change. `webtranslateit.com` stores **Prawn `inline_format` markup inside its locale files**, which Task 2's converter handles — but the strings should be verified against real renders, and the SVG logo path must still resolve.

The affected keys are `period_html`, `note_receipt` and `thank_you_html` in `config/locales/app/{en,es,fr}.yml` — 12 tag occurrences total (`<link href>`, `<font size>`, `<color rgb>`, `<b>`).

**Files:**
- Modify: `/Users/edouard/code/webtranslateit.com/Gemfile.lock`
- Verify: `/Users/edouard/code/webtranslateit.com/config/locales/app/{en,es,fr}.yml`
- Verify: `/Users/edouard/code/webtranslateit.com/app/interactors/payments/generate_invoice.rb:90`

- [ ] **Step 1: Point the app at the new gem version and confirm platforms**

```bash
cd /Users/edouard/code/webtranslateit.com && bundle update webtranslateit-payday
grep -A3 "^PLATFORMS" Gemfile.lock
```
Expected: `PLATFORMS` still lists `arm64-darwin` and `x86_64-linux`, and `bundle list | grep typst` shows the native gem. Both platforms have precompiled typst builds, so the `Dockerfile` needs no Rust toolchain and no change.

- [ ] **Step 2: Render one invoice per locale against real data**

```bash
cd /Users/edouard/code/webtranslateit.com && bin/rails runner '
pn = PaymentNotification.where.not(paid_at: nil).last
%w[en es fr].each do |locale|
  I18n.with_locale(locale) do
    result = Payments::GenerateInvoice.call(payment_notification: pn)
    File.binwrite("tmp/invoice_#{locale}.pdf", result.invoice.render_pdf)
  end
end
puts "done"' 2>&1 | tail -5
```
Expected: `done`, and three PDFs in `tmp/`.

- [ ] **Step 3: Review all three renders**

```bash
open /Users/edouard/code/webtranslateit.com/tmp/invoice_en.pdf \
     /Users/edouard/code/webtranslateit.com/tmp/invoice_es.pdf \
     /Users/edouard/code/webtranslateit.com/tmp/invoice_fr.pdf
```

Confirm on each: the `wti_mascot.svg` logo renders as vector at 200x50; the grey period line under the subscription description is grey; the `finance@webtranslateit.com` note is a working mailto link; "Thank you for your business!" is bold and larger; the Verifactu QR code is present and scannable; the VAT number and Spanish address are intact.

If any tag survives as literal text (for example `<font size='12'>` appearing in the PDF), the corresponding pattern in `Payday::Markup::TAG` does not match that string — add a regression test to `spec/markup_spec.rb` with the exact locale string and fix the converter.

- [ ] **Step 4: Scan a rendered Verifactu QR code with a phone**

The QR encodes tax data submitted to the Spanish AEAT. Confirm it decodes to the same URL as an invoice rendered by the old gem version. Do not skip this — a silently broken QR is a compliance problem, not a cosmetic one.

- [ ] **Step 5: Commit**

```bash
cd /Users/edouard/code/webtranslateit.com
git add Gemfile.lock
git commit -m "build: upgrade webtranslateit-payday to the typst renderer"
```

---

## Risks and open questions

| Risk | Mitigation |
| --- | --- |
| A layout regression ships on a real invoice | Task 7 step 4 and Task 9 step 3 are manual review gates. Do not automate them away. |
| Verifactu QR breaks | Task 9 step 4 scans it on a device. |
| A locale string uses a Prawn tag the converter misses | Task 9 step 3 catches it visually; add a test with the literal string and extend `Markup`. |
| Typst native gem missing for a future deploy platform | Both current platforms ship precompiled. If a platform is ever added, `typst` falls back to a source build needing Rust 1.89+; check before changing `builder.arch`. |
| Font rendering differs subtly from Prawn | Same NotoSans TTFs are used, but Typst's shaper differs. Expect small metric changes; that is why all goldens are regenerated. |
| `#set document(date: none)` accidentally removed | Task 7 step 2 pins it with a test. |

**Open question for the maintainer:** Payday is published as MIT and `typst` is Apache-2.0, so there is no licensing conflict. Confirm you are happy shipping a gem whose renderer is a native extension — it changes install characteristics for downstream users on unusual platforms, even though the two platforms you deploy on are covered.

## Rollout

1. Merge the payday branch and release `2.0.0` to RubyGems.
2. Deploy `webtranslateit.com` behind a normal Kamal deploy — there is no runtime toggle, so verify Task 9 thoroughly in a review app or locally first.
3. Keep the previous gem version pinnable for one billing cycle so a rollback is one `Gemfile.lock` change.

## Packaging note (verify during Task 5)

`payday.gemspec` builds `s.files` from `git ls-files`, so **`lib/payday/templates/invoice.typ` only ships if it is committed** — Task 5 step 2 does that. The NotoSans TTFs under `fonts/` are already tracked and keep working unchanged.

Zeitwerk loads `lib/payday` and ignores non-`.rb` files, so the `templates/` directory needs no `loader.ignore` entry. Confirm with:

```bash
cd /Users/edouard/code/payday && bundle exec ruby -Ilib -e 'require "payday"; puts Payday::Markup, Payday::InvoicePresenter'
```
Expected: both constants print without a Zeitwerk error.

`PdfRenderer#max_cell_width` was dead code in the Prawn implementation (never called) and is intentionally not carried over.
