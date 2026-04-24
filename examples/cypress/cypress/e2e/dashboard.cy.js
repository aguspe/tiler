/// <reference types="cypress" />
//
// Tiler dashboard — Cypress example.
//
// Three small, copy-pastable patterns for driving a Tiler dashboard from a
// Cypress suite in your own app. They are not exhaustive tests of Tiler
// itself — see this repo's `test/system/*` for that.
//
// Setup is in the README: install Tiler in your Rails app, seed the demo
// dashboard, run the server, then point CYPRESS_BASE_URL at it.

const slug = Cypress.env("dashboardSlug");

describe("Tiler dashboard", () => {
  beforeEach(() => {
    cy.visit(`/tiler/dashboards/${slug}`);
    // Every Tiler dashboard mounts a single .tiler-grid-stack container.
    cy.get(".tiler-grid-stack").should("exist");
  });

  it("dashboard renders at least one panel", () => {
    // Each persisted panel is a .grid-stack-item carrying gs-id="<panel.id>".
    cy.get(".grid-stack-item[gs-id]").should("have.length.at.least", 1);
  });

  it("clock widget shows the current time", () => {
    // Widget partials emit class hooks like .tiler-clock-time / .tiler-metric-value.
    // Use those instead of structural selectors — they're stable across releases.
    cy.get(".tiler-clock-time").invoke("text").should("match", /\d{1,2}:\d{2}:\d{2}/);
  });

  it("clicking a panel header opens the in-page edit drawer", () => {
    // Tiler edits panels in a slide-over drawer (no full-page nav). Click
    // anywhere on the panel header to open it; the drawer adds .is-open.
    cy.url().then((startUrl) => {
      cy.get("[data-tiler-panel-header]").first().click();
      cy.get("[data-tiler-drawer].is-open").should("exist");
      cy.url().should("eq", startUrl);
    });
  });
});
