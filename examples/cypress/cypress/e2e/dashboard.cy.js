/// <reference types="cypress" />

const slug = Cypress.env("dashboardSlug");

describe("Tiler dashboard", () => {
  beforeEach(() => {
    cy.visit(`/tiler/dashboards/${slug}`);
    cy.get(".tiler-grid-stack").should("exist");
  });

  it("renders the grid with at least one panel", () => {
    cy.get(".grid-stack-item").should("have.length.at.least", 1);
  });

  it("renders the clock widget with a current time", () => {
    cy.get(".tiler-clock-time").should("be.visible").invoke("text").should("match", /\d{1,2}:\d{2}:\d{2}/);
  });

  it("drives a panel move via the gridstack JS API; PATCH layout fires", () => {
    cy.intercept("PATCH", `/tiler/dashboards/${slug}/layout`).as("layoutPatch");

    cy.get("[data-tiler-toggle-edit]").click();
    cy.get(".grid-stack-item[gs-id]").first().invoke("attr", "gs-id").then((panelId) => {
      cy.window().then((win) => {
        const grid = win.document.querySelector(".grid-stack").gridstack;
        const node = grid.engine.nodes.find((n) => n.el.getAttribute("gs-id") === String(panelId));
        grid.update(node.el, { x: 4, y: 8 });
      });

      cy.wait("@layoutPatch").its("response.statusCode").should("eq", 200);

      cy.get(`.grid-stack-item[gs-id='${panelId}']`)
        .should("have.attr", "gs-x", "4")
        .and("have.attr", "gs-y", "8");

      // Reload — coords persisted by the server should survive.
      cy.reload();
      cy.get(`.grid-stack-item[gs-id='${panelId}']`)
        .should("have.attr", "gs-x", "4")
        .and("have.attr", "gs-y", "8");
    });
  });
});
