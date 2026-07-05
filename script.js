const tabs = document.querySelectorAll(".tab");
const listingGrid = document.querySelector("#listing-grid");
const insightGrid = document.querySelector("#insight-grid");

const fallbackInsights = [
  { category: "Vietnam Economy", title: "Vietnam business headline feed is being refreshed", summary: "We filter for Vietnam-only economy, investment, infrastructure, consumer, and market-entry signals.", sourceName: "Hola Advisory", url: "#contact" },
  { category: "Operator Note", title: "Virtual office first, full office later", summary: "A lower-risk path for companies that want presence before committing to larger fixed costs.", sourceName: "Hola Advisory", url: "#workspace" },
  { category: "Expansion Watch", title: "Buying a small business vs starting from zero", summary: "When acquisition, franchise, or partnership may be smarter than building from scratch.", sourceName: "Hola Advisory", url: "#opportunities" }
];

const fallbackListings = [
  { type: "sale", category: "Business For Sale", title: "Vietnam public acquisition listings", summary: "Use public listings as discovery leads only. Verify seller claims, financials, ownership, and availability directly.", location: "Vietnam", price: "Varies", sourceName: "BusinessesForSale", url: "https://www.businessesforsale.com/search/businesses-for-sale-in-vietnam" },
  { type: "franchise", category: "Franchise", title: "Franchise opportunity pipeline", summary: "Track brands and operators seeking Vietnam partners, pilot locations, or master franchise routes.", location: "Vietnam", price: "Case by case", sourceName: "Hola Advisory", url: "#contact" },
  { type: "property", category: "Property / Workspace", title: "Starter office and retail search", summary: "Workspace, virtual office, private office, and retail location routes for new Vietnam entrants.", location: "Ho Chi Minh City", price: "On request", sourceName: "Hola Advisory", url: "#workspace" }
];

function escapeHtml(value) {
  return String(value || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function renderInsights(items) {
  insightGrid.innerHTML = items.slice(0, 6).map((item) => `
    <article>
      <span>${escapeHtml(item.category || "Insight")}</span>
      <h3>${escapeHtml(item.title)}</h3>
      <p>${escapeHtml(item.summary)}</p>
      <a href="${escapeHtml(item.url || "#")}" target="_blank" rel="noopener">${escapeHtml(item.sourceName || "Read source")}</a>
    </article>`).join("");
}

function renderListings(items) {
  listingGrid.innerHTML = items.slice(0, 9).map((item) => `
    <article class="listing-card" data-type="${escapeHtml(item.type || "sale")}">
      <span>${escapeHtml(item.category || "Opportunity")}</span>
      <h3>${escapeHtml(item.title)}</h3>
      <p>${escapeHtml(item.summary)}</p>
      <dl>
        <div><dt>Location</dt><dd>${escapeHtml(item.location || "Vietnam")}</dd></div>
        <div><dt>Price</dt><dd>${escapeHtml(item.price || "On request")}</dd></div>
      </dl>
      <a href="${escapeHtml(item.url || "#contact")}" target="_blank" rel="noopener">${escapeHtml(item.sourceName || "View source")}</a>
    </article>`).join("");
}

async function loadJson(path, fallback) {
  try {
    const response = await fetch(path, { cache: "no-store" });
    if (!response.ok) throw new Error("Feed unavailable");
    const data = await response.json();
    return Array.isArray(data.items) ? data.items : fallback;
  } catch {
    return fallback;
  }
}

function bindTabs() {
  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      const filter = tab.dataset.filter;
      tabs.forEach((item) => item.classList.remove("active"));
      tab.classList.add("active");
      document.querySelectorAll(".listing-card").forEach((listing) => {
        listing.hidden = !(filter === "all" || listing.dataset.type === filter);
      });
    });
  });
}

async function hydrateFeeds() {
  const [insights, opportunities] = await Promise.all([
    loadJson("data/insights.json", fallbackInsights),
    loadJson("data/opportunities.json", fallbackListings)
  ]);
  renderInsights(insights);
  renderListings(opportunities);
  bindTabs();
}

hydrateFeeds();
