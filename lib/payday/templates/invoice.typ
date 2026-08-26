// Payday's invoice layout.
//
// All data arrives as JSON through sys.inputs, where Typst inserts string values as literal
// text rather than markup. Never interpolate invoice data into this file's source, and never
// call eval() on a value that came from an invoice.

#let d = json(bytes(sys.inputs.invoice))

// Gaps between the major blocks, calibrated so the rendered invoice keeps the vertical
// rhythm the prawn renderer produced. Every within-block gap falls out of the table insets.
#let gap-after-header = 15pt
#let gap-after-addresses = 13.2pt
#let gap-after-details = 8pt
#let gap-before-totals = -12pt
#let gap-before-notes = 22.3pt
#let gap-notes-label-to-rule = -7.1pt
#let gap-after-notes-rule = -0.4pt
#let gap-before-qr = -0.6pt

// Prawn page-size names mapped onto Typst paper names.
#let papers = ("LETTER": "us-letter", "A4": "a4", "LEGAL": "us-legal")

#set document(title: "Invoice", date: none)
#set page(
  paper: papers.at(d.page_size, default: "a4"),
  margin: 36pt,  // prawn's default half-inch page margin
  numbering: none,
  // Page numbers appear only when the invoice runs to more than one page. This has to be a
  // footer rather than a trailing `set page`, which would only affect the final page.
  footer: context {
    if counter(page).final().first() > 1 {
      align(right, text(size: 9pt, counter(page).display("1 / 1", both: true)))
    }
  },
)
#set text(font: "Noto Sans", size: 10pt)

// Renders the styled runs produced by Payday::Markup.
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
    if r.at("underline", default: false) { body = underline(body) }
    if r.at("strike", default: false) { body = strike(body) }
    if r.at("sub", default: false) { body = sub(body) }
    if r.at("sup", default: false) { body = super(body) }
    if "link" in r { link(r.link, body) } else { body }
  }
}

// --- status stamp ------------------------------------------------------------------
// Drawn before anything else so it stays at a fixed offset from the top of the page, the way
// prawn stamped it, rather than drifting with the height of the logo.
#if d.stamp != none {
  place(top + center, dx: 5.1pt, dy: 33pt, rotate(15deg,
    text(fill: rgb("cc0000"), size: 25pt, weight: "bold")[#d.stamp]))
}

// --- logo and company identity ---------------------------------------------------
#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  if d.logo != none {
    image(
      d.logo.name,
      width: if d.logo.width != none { d.logo.width * 1pt } else { auto },
      height: if d.logo.height != none { d.logo.height * 1pt } else { auto },
      fit: "contain",
    )
  },
  align(left, pad(top: 5.7pt)[
    #text(weight: "bold", size: 12pt)[#d.company_name] \
    #d.company_details
  ]),
)


#v(gap-after-header)

// --- bill to / ship to -------------------------------------------------------------
#grid(
  columns: (1fr, 200pt),
  align: (left + top, left + top),
  [#text(weight: "bold")[#d.labels.bill_to]#v(10.4pt, weak: true)#d.bill_to],
  if d.ship_to != none {
    [#text(weight: "bold")[#d.labels.ship_to]#v(10.4pt, weak: true)#d.ship_to]
  },
)

// The ship-to cell renders 2pt taller than the bill-to cell, so invoices that carry a
// ship-to address need that much less space before the details block.
// prawn drew the ship-to box 2pt taller than its contents, so invoices carrying a ship-to
// address pushed the details block down by that much.
#v(gap-after-addresses + if d.ship_to != none { 2pt } else { 0pt })

// --- invoice details ---------------------------------------------------------------
#if d.details.len() > 0 {
  table(
    columns: 2,
    stroke: none,
    inset: (left: 1pt, right: 0pt, y: 4.25pt),
    column-gutter: 10pt,
    align: (left, right),
    ..d.details.map(row => (
      text(weight: "bold")[#row.at(0)],
      text(weight: "bold")[#row.at(1)],
    )).flatten()
  )
}

#v(gap-after-details)

// --- line items ---------------------------------------------------------------------
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  inset: (x: 10pt, y: 8.25pt),
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

#v(gap-before-totals)

// --- totals ---------------------------------------------------------------------------
#align(right, table(
  columns: 2,
  stroke: none,
  // The total is set 12pt, whose taller glyph box would otherwise pull the row up.
  inset: (x, y) => (
    left: 5pt, right: 5pt, bottom: 8.25pt,
    top: if y == d.totals.len() - 1 { 8.95pt } else { 8.25pt },
  ),
  align: (left, right),
  ..d.totals.map(row => {
    let size = if row.at(2) { 12pt } else { 10pt }
    (text(weight: "bold", size: size)[#row.at(0)], text(size: size)[#row.at(1)])
  }).flatten()
))

// --- notes ------------------------------------------------------------------------------
#if d.notes != none {
  v(gap-before-notes)
  text(weight: "bold")[#d.labels.notes]
  v(gap-notes-label-to-rule)
  line(length: 100%, stroke: 0.5pt + rgb("cccccc"))
  v(gap-after-notes-rule)
  render-runs(d.notes)
}

// --- QR code ------------------------------------------------------------------------------
#if d.qr_code != none {
  v(gap-before-qr)
  image("qr.png", width: 100pt)
}
