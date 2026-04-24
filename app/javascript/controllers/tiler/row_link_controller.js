import { Controller } from "@hotwired/stimulus"

// Makes a table row click open a URL — except when the click target is
// inside an element marked [data-tiler-row-link-skip] (used to wrap the
// per-row action cell so the Edit/Delete buttons don't double-fire).
//
//   <tr data-controller="tiler--row-link"
//       data-tiler--row-link-url-value="/foo/123/edit"
//       data-action="click->tiler--row-link#go"
//       tabindex="0">
//     ...
//     <td data-tiler-row-link-skip>
//       <a href="/foo/123/edit">Edit</a>
//       <button>Delete</button>
//     </td>
//   </tr>
export default class extends Controller {
  static values = { url: String }

  go(event) {
    if (!this.urlValue) return
    if (event.target.closest("[data-tiler-row-link-skip]")) return
    if (event.target.closest("a, button")) return
    Turbo?.visit ? Turbo.visit(this.urlValue) : (window.location.href = this.urlValue)
  }
}
