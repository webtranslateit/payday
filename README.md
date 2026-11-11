# Tallyman

Tallyman is a Ruby library for rendering invoices to PDF.

Here's an [example invoice](https://github.com/Rebase-Capital/tallyman/raw/main/spec/assets/testing_predefined_amount.pdf).

## What is a tallyman?

On the docks, the tallyman is the clerk who stands at the ship's side and counts the cargo as it comes over the rail. Every bale, crate and barrel is checked off against the manifest, and the tally that results is the record both the ship and the shipper are held to: what was delivered, in what quantity, and so what is owed.

This gem does the same job on paper. You hand it what was sold and to whom, and it draws up the bill.

## Installing

```
gem install tallyman
```

Or, using Bundler:

``` ruby
gem 'tallyman'
```

Tallyman needs Ruby 3.2 or later.

## Usage

Tallyman comes with `Invoice` and `LineItem` classes you can use as they are:

``` ruby
invoice = Tallyman::Invoice.new(invoice_number: 12)
# Two lines with a price and a quantity. The amount is price * quantity.
invoice.add_line_item(price: 20, quantity: 5, description: 'Pants')
invoice.add_line_item(price: 10, quantity: 3, description: 'Shirts')
# A line with no price or quantity, only a predefined amount (a flat fee).
invoice.add_line_item(predefined_amount: 10, description: 'Shipping')
invoice.render_pdf_to_file('/path/to_file.pdf')
```

`render_pdf` returns the PDF as a string instead of writing it to disk.

API documentation is available at [rubydoc.info](https://www.rubydoc.info/gems/tallyman).

## Customizing your invoice

`Tallyman::Config` holds the settings shared by every invoice, such as the logo and the company details:

``` ruby
Tallyman::Config.default.invoice_logo = "/path/to/company/logo.png"
Tallyman::Config.default.company_name = "Awesome Corp"
Tallyman::Config.default.company_details = "10 This Way\nManhattan, NY 10001\n800-111-2222\nawesome@awesomecorp.com"
```

The logo can be a PNG, a JPEG or an SVG, and is drawn at its natural size. Pass a hash to constrain it:

``` ruby
Tallyman::Config.default.invoice_logo = {filename: "logo.svg", size: "200x50"}
```

`page_size` accepts `"LETTER"`, `"A4"` and `"LEGAL"`. `currency` and `date_format` are set the same way.

## QR codes

An invoice can carry a QR code, which a growing number of countries expect for tax compliance:

``` ruby
invoice = Tallyman::Invoice.new(
  invoice_number: 12345,
  qr_code: 'https://verify.example.com/invoice/12345',
  notes: 'Scan the QR code below to verify this invoice online.'
)
```

The QR code is rendered below the notes, as vector SVG so it stays sharp in print. The code itself comes straight from [rqrcode](https://github.com/whomwah/rqrcode), so the payload and its error correction level are exactly what that gem produces.

## Using Tallyman with ActiveRecord (or any other objects)

Tallyman works with two objects, an invoice and a line item. To use it with your own classes, include `Tallyman::Invoiceable` in the invoice and `Tallyman::LineItemable` in the line item.

In a Rails app, a generator creates the models and the migration for you. Run `rails generate tallyman:setup --help` to see its options.

## Rendering PDFs to the web

In a Rails controller, send the rendered string straight to the browser:

``` ruby
respond_to do |format|
  format.html
  format.pdf do
    send_data invoice.render_pdf, filename: 'Invoice #12.pdf', type: 'application/pdf', disposition: 'inline'
  end
end
```

## Appending your own pages

Pass a `Tallyman::Appendix` to add pages of your own to the end of an invoice — a per-item breakdown, a delivery note, terms and conditions:

``` ruby
appendix = Tallyman::Appendix.new(
  source: File.read('appendix.typ'),
  inputs: {'shipments' => shipments.to_json},
  dependencies: {'chart.svg' => File.binread('chart.svg')}
)

invoice.render_pdf(appendix: appendix)
```

`source` is [Typst](https://typst.app) markup appended to Tallyman's own template, so it is compiled as part of the invoice rather than as a second PDF you would then have to merge in. Two things follow from that: your pages inherit the invoice's page setup and margins, and the page counter runs across the whole document, so the numbering footer counts your pages too. A one-page invoice with one appended page comes out numbered "1 / 2" and "2 / 2".

`inputs` reach the template as [sys_inputs](https://typst.app/docs/reference/foundations/sys/), read with `json(bytes(sys.inputs.shipments))`. `dependencies` are files the source can reach by name, with `image("chart.svg")` and the like. Reusing a name the invoice has already taken — the `invoice` input, or the logo and QR code files — raises an `ArgumentError` rather than quietly replacing it.

**Pass your data through `inputs`, never by interpolating it into `source`.** Typst treats a string arriving through `sys.inputs` as literal text, which is what stops a customer-supplied field from affecting the layout. `source` is code: interpolating invoice data into it hands anyone who can set a field on an invoice a way to write Typst.

An appendix that reads its data and prints a heading:

``` typst
#let a = json(bytes(sys.inputs.shipments))

#pagebreak()
#text(size: 16pt, weight: "bold")[#a.title]
```

## I18n

Tallyman uses the i18n gem for its labels, and ships with English, French, German, Spanish, Dutch and Simplified Chinese. To change a label, add a YAML file to the `config/locales` directory of your Rails app. These are the labels you can override:

``` yaml
en:
  tallyman:
    status:
      paid: PAID
      overdue: OVERDUE
      refunded: REFUNDED
    invoice:
      bill_to: "Bill To"
      ship_to: "Ship To"
      invoice_no: "Invoice number:"
      receipt_no: "Receipt number:"
      due_date: "Due Date:"
      paid_date: "Paid Date:"
      subtotal: "Subtotal:"
      shipping: "Shipping:"
      tax: "Tax:"
      retention: "Retention:"
      total: "Total:"
      notes: "Notes:"
    line_item:
      description: Description
      unit_price: "Unit Price"
      quantity: Quantity
      amount: Amount
```

If you translate the invoice into another language, a pull request adding your locale file is welcome.

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/Rebase-Capital/tallyman). For anything larger than a small fix, open an issue first so that two people don't end up doing the same work.

Run the specs and the linter with `bundle exec rake`.

## History

Tallyman started life as Payday, a gem written by Alan Johnson. When the original stopped working on Ruby 2.7 and its source was no longer on GitHub, we recovered the code from [rubygems.org](https://rubygems.org) and maintained it as `webtranslateit-payday`, adding features and fixes along the way; they are listed in the [changelog](https://github.com/Rebase-Capital/tallyman/blob/main/CHANGELOG.md). It was renamed Tallyman in 1.0.0. We use it at [WebTranslateIt.com](https://webtranslateit.com) and [Trackberry](https://trackberry.com) to generate invoices and receipts.

Thanks to everyone who has contributed:

* Alan Johnson, the original author
* Sam Pizzey ([pizzeys](https://github.com/pizzeys))
* Andrew Nordman ([cadwallion](https://github.com/cadwallion))
* Pierre Olivier Martel ([pomartel](https://github.com/pomartel))
* Matt Hoofman ([mhoofman](https://github.com/mhoofman))
* Édouard Brière ([edouard](https://github.com/edouard))
* Jim Jones ([aantix](https://github.com/aantix))
* Hussein Morsy ([husseinmorsy](https://github.com/husseinmorsy))

## Acknowledgements

Tallyman renders with [Typst](https://typst.app) and its [Ruby binding](https://github.com/actsasflinn/typst-rb).

For its first decade this gem was built on [Prawn](https://prawnpdf.org), and it would not exist without that project and the team behind it.

## License

Copyright (C) 2011 by Alan Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
